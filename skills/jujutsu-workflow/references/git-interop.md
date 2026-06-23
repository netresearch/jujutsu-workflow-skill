# Git interop — detection, colocation, and staying compatible

`jj` is Git-backed. The agent's job is to use jj's strengths locally while leaving
a clean, ordinary-Git state for humans and CI.

## Detect the repository mode first

Run `${CLAUDE_SKILL_DIR}/scripts/detect_jj_state.sh` (or `--json`). It reports one
of four modes:

| Mode | Signal | What to do |
| --- | --- | --- |
| `colocated` | `.jj/` and a real `.git/` at the root | mutate with jj; read-only git is fine |
| `jj-only` | `.jj/` present; git backend lives in `.jj/repo/store/git` | use jj; raw git CLI will not see repo state |
| `git-only` | a Git repo, no `.jj/` | use Git; introduce jj only if asked |
| `none` | neither | do not invent a VCS workflow |

Authoritative colocation check: `jj git colocation status`. In jj 0.42,
`jj git init` is **colocated by default** (`--no-colocate` opts out), so most jj
repos an agent meets are colocated.

## Adopting jj in an existing Git repo

Only when asked. In the repo root:

```bash
jj git init            # colocated by default in 0.42 (adds .jj/ beside .git/)
jj config set --user ui.paginate never
```

Nothing about the Git side changes; `git log`/`git status` keep working.

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
git worktree for isolation, use a jj workspace instead.

## Bookmark hygiene at the boundary

- A bookmark does not auto-advance as you add commits — `jj bookmark move <name>
  --to @-` before re-pushing.
- After a PR merges, delete the local bookmark (`jj bookmark delete <name>`) and
  `jj git fetch` to drop the remote-tracking ref.
- Push new bookmarks directly with `jj git push --bookmark <name>` (no `--allow-new`
  in 0.42).

## Leave a Git-legible result

Before handoff, confirm the Git view is coherent for a Git-only reviewer:

```bash
git --no-pager log --oneline -n 5
git status --short --branch
```

If the Git view looks wrong while jj looks right, you are likely mid-desync — see
the recovery playbook.
