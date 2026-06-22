# Why jj beats Git workflows for agentic development

A grounded argument — each claim is tied to a mechanism, not a benchmark. (Be
skeptical of "Nx faster" / "87% auto-resolve" / "quantum-resistant" claims you see
on some jj skills; this skill makes none of them.)

## The core mismatch jj fixes

Git was built for humans who plan a commit, stage it, and commit deliberately.
Agents work the opposite way: they make speculative, iterative, often-wrong edits
and need to reshape them afterwards. Git punishes that with `reset`/`stash`/
`checkout`/`rebase -i` footguns; jj is built around it. The split this skill enforces
— **jj for local change-shaping, Git for the remote contract** — gives the agent a
forgiving workspace and humans an ordinary Git PR.

## Concrete advantages (with the mechanism)

1. **Universal, reversible undo.** Every repo-modifying command lands in the
   operation log; `jj undo` / `jj op restore <id>` returns the *entire* repo to a
   prior state — bookmarks, working copy, and all. There is no git-reflog detective
   work and no irrecoverable `git reset --hard`. For an agent that will make
   mistakes, "any action is reversible" is the single biggest safety win.

2. **Conflicts are data, not a halt.** A conflicting `jj rebase` *completes* and
   records the conflict inside the commit (`jj status` flags it; `jj resolve --list`
   enumerates it), instead of dropping git into an aborted-rebase / detached-HEAD
   limbo the agent must detect and escape. The agent can keep working and resolve
   deliberately — or `jj undo` the whole thing cleanly. (Verified hands-on.)

3. **No staging area = one fewer hidden state to corrupt.** There is no index, so an
   agent cannot "forget to `git add`", half-stage a file, or be misled by a dirty
   index. The working copy simply *is* a commit, snapshotted when a jj command runs.

4. **Declarative, non-interactive history surgery.** Turning messy agent output into
   a clean PR is a few non-interactive commands — `jj split <path>`, `jj squash
   --from/--into`, `jj describe -m` — instead of an interactive `git add -p` /
   `git rebase -i` session that an agent cannot drive. This is precisely where jj
   shines for "clean up what the agent produced". (Verified hands-on.)

5. **Stable change IDs.** A change keeps its ID across rewrites/rebases, so an agent
   can reference a commit reliably even as the underlying hash changes — no
   "the hash moved after rebase" class of error.

6. **Isolation that fits parallel agents.** `jj workspace` gives each concurrent
   agent its own working copy over one shared store/op-log — cleaner than juggling
   `git worktree` (and free of the colocated-git hazards a second git worktree adds).

7. **Zero migration cost.** A colocated repo keeps a normal `.git/`; teammates, CI,
   `gh`/`glab`, and code review see ordinary branches and commits. Adopting jj is a
   local choice, not a team-wide migration.

Independent signal that agents can use jj well: the TabbyML *jj-benchmark* (63 jj
tasks) reports strong completion rates for current frontier models — so the
bottleneck is workflow discipline, which is exactly what this skill supplies.

## When NOT to use jj (be honest)

jj is not a silver bullet. Prefer plain Git (or git-worktree stacked PRs) when:

- **The team/CI can't support it.** If reviewers and pipelines are Git-only and
  nobody will maintain jj, the cognitive cost may outweigh the benefit. (Git stays
  the contract precisely so this stays a *local* choice.)
- **The change is trivial.** A one-line fix needs no history shaping; jj's edge is
  in *reshaping*, so there's little to gain.
- **You need the staging area as a feature.** Some agent flows deliberately use the
  index as a review buffer; jj removes it.
- **You can't enforce the safety rules.** Without `--no-pager`, non-interactive
  flags, and the snapshot hooks, jj's interactivity will *hurt* an agent. If you
  can't set those, the risk outweighs the reward.

Known sharp edges this skill mitigates but which remain real: **commit absorption**
(everything collapsing into one commit), the **single-writer working copy**
(parallel agents need workspaces), and the **snapshot-on-command-only** behavior
(needs hooks). See [parallel-agents.md](parallel-agents.md) and
[agent-safety.md](agent-safety.md).

## Bottom line

Use jj where its advantages apply — speculative, iterative, multi-step agent work
that needs reshaping and a strong undo — and keep Git as the interface to everyone
else. That combination, with the safety rules enforced, is what makes an agent both
faster and safer than driving Git directly.

## Further reading

- Jujutsu docs: <https://docs.jj-vcs.dev/latest/>
- "Avoid Losing Work with jj for AI coding agents" — panozzaj (snapshot nuance + hooks)
- "Use Jujutsu, Not Git" — slavakurilyak (op-log-as-recovery thesis)
- "Why jj is perfect for AI-generated code" — cesar.velandia (reviewer-cleanup angle)
- `2389-research/agentjj` — the counter-case: documents the failure modes this skill mitigates
