# Agent safety — what hangs an agent, and how to avoid it

The single biggest failure mode of `jj` inside an agent is **blocking on
interactivity** (a pager or an editor waiting for input the agent never sends).
Everything here is mechanical and non-negotiable.

## 1. The pager will hang you

Output commands page through `less` by default. Always either pass `--no-pager`
or disable the pager once per environment:

```bash
jj config set --user ui.paginate never     # do this first, in any agent session
# or, per command:
jj --no-pager log
```

`detect_jj_state.sh` reports `ui.paginate`; if it is unset, set it to `never`.

## 2. Never invoke an editor/TUI form

These open `$EDITOR` or a TUI and hang an agent. Each has a non-interactive form:

| Hangs (do NOT run) | Non-interactive form |
| --- | --- |
| `jj describe` (no `-m`) | `jj describe -m "msg"` |
| `jj commit` (no `-m`) | `jj commit -m "msg"` |
| `jj squash -i` / `jj squash` opening editor | `jj squash --from R --into R [-m "msg"]` |
| `jj split` (interactive diff editor) | `jj split <paths> -m "msg"` |
| `jj diffedit` | edit files directly, then `jj diff` |
| `jj resolve` (merge tool) | edit the conflict markers in the file, then verify |

Good vs bad:

```bash
# Bad — opens $EDITOR, hangs
jj describe
# Good
jj describe -m "fix: handle empty input"
```

If a non-interactive form does not exist for what you need, stop and report it
rather than running the interactive one.

## 3. The snapshot is NOT continuous

A common myth is that jj "auto-saves everything". In reality jj snapshots the
working copy into `@` **only when a jj command runs** — not on every file write.
Between jj commands, edits live only on disk. Practical consequences:

- After editing files, run a jj command (`jj status`) to capture them before you
  rely on the operation log as a safety net.
- For real safety, wire hooks that snapshot on session boundaries (next section).

## 4. Hook recipe (make the safety net real)

Run `jj status` at the points where work would otherwise be lost. For Claude Code,
add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "jj --no-pager status >/dev/null 2>&1 || true" }] }],
    "PreCompact":   [{ "hooks": [{ "type": "command", "command": "jj --no-pager status >/dev/null 2>&1 || true" }] }]
  }
}
```

This guarantees a snapshot (and an operation-log entry) at session start and before
context compaction, so `jj undo` / `jj op restore` can always reach that point.

## 5. Colocated git/jj desync

In a colocated repo (`.jj/` and `.git/` at the same root) the two share one working
copy. If an agent runs a **mutating** raw `git` command (`git add/commit/reset/
checkout/rebase/merge/stash`), git and jj can desync into a state that looks
"impossible" to the agent. Rule: in a colocated repo, mutate only with `jj`; use git
read-only (`git status`, `git log`, `git diff`, `git show`, `git blame`). See
[git-interop.md](git-interop.md).

## 6. Identity & signing (CI / non-interactive)

jj does not read git's `user.name`/`user.email` automatically. Set them explicitly
(important in CI containers):

```bash
jj config set --user user.name  "Your Name"
jj config set --user user.email "you@example.com"
```

**Set the identity before you start working.** The config applies to *future*
commits only — the working-copy commit that already exists keeps the old author.
jj 0.43 says so when you set it:

```text
Warning: This setting will only impact future commits.
The author of the working copy will stay "V <v@example.com>".
To change the working copy author, use "jj metaedit --update-author"
```

An agent that configures identity after making changes will otherwise push a
commit authored by the wrong (or an empty) identity, which fails DCO. If you hit
it, run `jj metaedit --update-author` on the affected change rather than
re-describing it.

For signed commits, configure signing in jj config (`signing.behavior = "own"`,
`signing.backend = "ssh"` or `"gpg"`); jj signs commits it creates. Confirm the
project's signing requirement before pushing.

## 7. A harness worktree shadows the jj repo

You may be placed in a plain git worktree before you get a say — Claude Code's
`EnterWorktree`, `--worktree`, `isolation: "worktree"`, and background sessions all
create one at `.claude/worktrees/<name>` **inside** the repo. It has no `.jj/`, so
jj walks up and answers for the parent repo instead.

Detect it before trusting any jj output:

```bash
detect_jj_state.sh      # mode: worktree-shadowed, exit 3
```

**Rule: in this state run no jj command at all — reads included.** `jj status`
reports the parent workspace (it printed "The working copy has no changes." over a
modified and an untracked file), and `jj describe` committed the *parent
checkout's* unrelated work under the agent's message. Use plain git here; it is
the correct tool, not a fallback.

**Never resolve an `ExitWorktree` refusal with `discard_changes: true` on jj's
word.** That check reads real git file state and is correct; jj's "clean" is not
evidence. Run `git status --short`; if it lists anything, stop and ask. Nothing
recovers this — jj never recorded the work, so there is no op to undo. Full
detail, including how to prevent the situation, in
[git-interop.md](git-interop.md).

## 8. Verify after every mutation

`jj` operations are quiet on success. After `squash`/`split`/`rebase`/`abandon`,
run `jj --no-pager status` and `jj --no-pager log --limit 5` to confirm the result
is what you intended — never assume.
