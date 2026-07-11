# jj vs Git: when it helps, when it doesn't

A decision guide, not a sales pitch. Each "use jj when" bullet points to the
reference doc that owns the mechanism and the verified commands — this page only
says when to reach for it.

## Use jj when

- **Work is speculative and will need reshaping.** Non-interactive `jj split` /
  `jj squash --from/--into` replace `git add -p` / `rebase -i`, which an agent
  cannot drive. See [command-map.md](command-map.md).
- **You need real undo.** Every jj command lands in the operation log; `jj undo` /
  `jj op restore <id>` resets the whole repo — bookmarks and working copy, not just
  the index. See [recovery-playbook.md](recovery-playbook.md).
- **A rebase might conflict.** A conflicting `jj rebase` completes and records the
  conflict instead of leaving a half-finished git rebase/merge to detect and escape.
  See [recovery-playbook.md](recovery-playbook.md).
- **Multiple agents touch the repo concurrently.** One `jj workspace` per agent
  avoids the single-writer working-copy trap. See
  [parallel-agents.md](parallel-agents.md).
- **You still want ordinary Git PRs/CI/review at the boundary.** A colocated repo
  keeps a normal `.git/`; adopting jj is a local choice, not a team migration. See
  [pr-handoff.md](pr-handoff.md).

## When NOT to use jj

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

## Known sharp edges (mitigated, not eliminated)

Commit absorption (everything collapsing into one commit), the single-writer
working copy (parallel agents need workspaces), colocated git/jj desync, and the
snapshot-on-command-only behavior (needs hooks) are real. See
[agent-safety.md](agent-safety.md) and [parallel-agents.md](parallel-agents.md) for
the mechanism and mitigation for each.
