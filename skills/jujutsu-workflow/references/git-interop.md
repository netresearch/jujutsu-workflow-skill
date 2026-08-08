# Git interop — detection, colocation, and staying compatible

`jj` is Git-backed. The agent's job is to use jj's strengths locally while leaving
a clean, ordinary-Git state for humans and CI.

## Detect the repository mode first

Run `${CLAUDE_SKILL_DIR}/scripts/detect_jj_state.sh` (or `--json`). It reports one
of five modes:

| Mode | Signal | What to do |
| --- | --- | --- |
| `colocated` | `.jj/` and a real `.git/` at the root | mutate with jj; read-only git is fine |
| `jj-only` | `.jj/` present; git backend lives in `.jj/repo/store/git` | use jj; raw git CLI will not see repo state |
| `git-only` | a Git repo, no `.jj/` | use Git; introduce jj only if asked |
| `worktree-shadowed` | a git worktree with no `.jj/` of its own, under a jj repo | **do not run jj at all** — see below |
| `none` | neither | do not invent a VCS workflow |

`worktree-shadowed` exits **3**, not 0. Treat that exit code as a stop sign.

Authoritative colocation check: `jj git colocation status`. In jj 0.42 and 0.43,
`jj git init` is **colocated by default** (`--no-colocate` opts out), so most jj
repos an agent meets are colocated.

## Harness-provided git worktrees (`worktree-shadowed`)

An agent does not always choose its own isolation. Claude Code's `EnterWorktree`
tool, `--worktree`, `isolation: "worktree"` on a subagent, and background sessions
all create a **plain git worktree inside the repo** at `.claude/worktrees/<name>`.
That worktree has no `.jj/` of its own, so jj walks up the directory tree, finds
the parent repo's `.jj/`, and answers for the **parent workspace**.

Detect by structure, not by path — other harnesses use other directories:

```bash
[ "$(git rev-parse --absolute-git-dir)" != "$(cd "$(git rev-parse --git-common-dir)" && pwd -P)" ]  # in a linked worktree
[ "$(jj root)" != "$(git rev-parse --show-toplevel)" ]                                              # jj points elsewhere
```

Both true → shadowed. What that costs you, all observed on jj 0.43:

- **Reads lie.** `jj status` in a worktree with modified and untracked files
  prints `The working copy has no changes.`
- **Writes hit the wrong repo.** `jj describe -m "…"` run from the worktree
  committed the *parent checkout's* unrelated in-progress edit under the agent's
  message; `jj new` then advanced the parent's working copy. The worktree's own
  edits were never touched.
- **`jj status` reports the parent's files**, sometimes with `../../` paths — a
  reliable tell that you are not where jj thinks you are.

**The rule: run no jj command here, read or write.** Reads mislead and writes
land in the parent. Use ordinary git (`git status`, `git diff`, `git add`,
`git commit`) — in this directory git is not the fallback, it is the correct tool.

It cannot be repaired in place. Both conversions refuse:

```text
jj git init --colocate   → Cannot create a colocated jj repo inside a Git worktree.
jj workspace add <path>  → Destination path exists and is not an empty directory
```

`jj git init --git-repo=…` does "succeed" here — and **destroys uncommitted work**;
see the warning in the fallback section below. Do not reach for it.

### The `discard_changes: true` trap

`ExitWorktree` refuses to remove a worktree that has uncommitted files or unmerged
commits unless you pass `discard_changes: true`. That check runs at the git level,
on real file state, and it is **correct**. jj's "no changes" has nothing to do with
it.

The failure sequence: jj reports clean → the agent believes jj over the tool →
sets `discard_changes: true` to get past the "spurious" refusal → the work is gone.
There is no operation log to undo it, because jj never recorded the work.

If `ExitWorktree` refuses and jj says clean, **jj is wrong**. Run
`git status --short` in the worktree. If it lists anything, stop and hand the
decision to the user.

### Preventing it

The fix is usually outside the agent's control — surface the constraint and ask
rather than improvising. What is actually available, verified against Claude Code:

- **Non-colocated (`jj-only`) repos** can redirect worktree creation entirely. A
  `WorktreeCreate` hook replaces the built-in git behavior: it receives
  `{"session_id","transcript_path","cwd","hook_event_name","name"}` on stdin and
  must print the created path on stdout.

  ```json
  {
    "hooks": {
      "WorktreeCreate": [{ "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/create-workspace.sh" }] }]
    }
  }
  ```

  The script reads `name`, runs `jj workspace add --name "$name" "$dest"` with
  `$dest` **outside** the repo, and echoes `$dest`. The session then lands in a
  real jj workspace and nothing is created inside the repo. Note the nested
  `"hooks": [...]` shape — the flat form is silently ignored.

- **Colocated repos cannot use this.** The hook does not fire when a real `.git/`
  exists at the root; Claude Code takes the git path and creates
  `.claude/worktrees/<name>` regardless. For those repos the only answer is to not
  auto-isolate — ask the user to disable worktree isolation for the repo, or to
  work in a `jj workspace` created up front.

## Adopting jj in an existing Git repo

Only when asked. In the repo root:

```bash
jj git init            # colocated by default (adds .jj/ beside .git/)
jj config set --user ui.paginate never
```

Nothing about the Git side changes; `git log`/`git status` keep working.

### Inside a git worktree (colocation refuses)

A colocated `jj git init` **fails inside a git worktree** (where `.git` is a
file, not a directory) with `Cannot create a colocated jj repo inside a Git
worktree`. This is common in bare-repo + worktree layouts. Two options:

- **Preferred** — run colocated init in the *main* (non-worktree) checkout, or
  use `jj workspace add` for additional working copies.
- **Fallback** — initialize **non-colocated** against the backing repo:

  ```bash
  git status --short          # MUST be empty first — see the warning below
  jj git init --git-repo=/path/to/repo.git   # e.g. ../.bare in a worktree layout
  ```

  > **This command destroys uncommitted work.** Observed on jj 0.43 in a dirty
  > worktree: it reports `Added 0 files, modified 1 files, removed 1 files`,
  > silently reverting the modified file and deleting the untracked one. It checks
  > the parent commit out over your working copy with no prompt and no
  > confirmation, and jj has no operation-log entry to undo it from. Commit or
  > stash with git until `git status --short` is empty before running it — and
  > never run it to "fix" a `worktree-shadowed` directory that holds work.

  Trade-off: non-colocated means raw `git` no longer sees jj's working-copy
  commits without `jj git export` — you lose the "read with git" convenience.

After either path, jj has **no user identity by default**; set one (commits are
otherwise un-pushable), and keep `.jj/` out of git:

```bash
jj config set --repo user.name  "Some One"          # --repo: scope to this repo
jj config set --repo user.email "someone@example.com"
echo '.jj/' >> "$(git rev-parse --git-path info/exclude)"   # local exclude
```

## The two rules for colocated repos

1. **Mutate with jj, read with git.** Safe git in a colocated repo: `git status`,
   `git log`, `git diff`, `git show`, `git blame`, `git rev-parse`. Avoid mutating
   git: `git add/commit/reset/checkout/switch/merge/rebase/stash` — they desync jj
   (see [agent-safety.md](agent-safety.md) §5). If you must reconcile after an
   accidental git mutation: `jj git import` (pull git changes into jj) /
   `jj git export` (push jj changes to git refs).
2. **Bookmarks are the bridge.** A jj bookmark becomes a git branch on push. Humans
   and CI see ordinary branches; they never need to know jj was involved.

## Worktrees → workspaces

Do **not** use `git worktree` in a jj repo. jj's equivalent is workspaces, which
share one operation log and avoid the colocation hazards of a second git worktree:

```bash
jj workspace add ../feature-ws        # new working copy, same repo
jj workspace list
jj workspace forget <name>            # remove BEFORE deleting the directory
```

See [parallel-agents.md](parallel-agents.md). If a higher-level skill suggests a
git worktree for isolation, use a jj workspace instead — and if the harness
already put you in one before you could choose, you are in the
`worktree-shadowed` case above, which no jj command can fix.

## Bookmark hygiene at the boundary

- A bookmark does not auto-advance as you add commits — `jj bookmark move <name>
  --to @-` before re-pushing.
- After a PR merges, delete the local bookmark (`jj bookmark delete <name>`) and
  `jj git fetch` to drop the remote-tracking ref.
- Push new bookmarks directly with `jj git push --bookmark <name>` (no
  `--allow-new`). Every commit in the pushed range must be
  **described** — `jj git push` rejects any with no message; see
  [pr-handoff.md](pr-handoff.md).

## Leave a Git-legible result

Before handoff, confirm the Git view is coherent for a Git-only reviewer:

```bash
git --no-pager log --oneline -n 5
git status --short --branch
```

If the Git view looks wrong while jj looks right, you are likely mid-desync — see
the recovery playbook.
