# Command map — Git habits → jj (verified against jj 0.42.0)

All commands below were run hands-on against jj 0.42.0. jj's CLI moves fast; on
another version, confirm a flag with `jj <cmd> --help`.

## Translation table

| Intent | Git habit | jj (agent-safe form) |
| --- | --- | --- |
| status | `git status` | `jj --no-pager status` |
| log | `git log` | `jj --no-pager log --limit 10` |
| diff | `git diff` | `jj --no-pager diff` (`--git` for unified) |
| stage + commit | `git add -p && git commit` | `jj describe -m "msg"` (no staging area; see below) |
| amend | `git commit --amend` | edit files, then `jj describe -m` / `jj squash` |
| new branch of work | `git checkout -b x` | `jj new -m "msg"` (+ a bookmark only at handoff) |
| branch (for remote) | `git branch x` | `jj bookmark create x -r @-` |
| switch | `git switch x` | `jj edit <rev>` (don't edit a change another workspace holds; see parallel-agents.md) |
| stash | `git stash` | not needed — just `jj new`; the work is already a commit |
| update from remote | `git pull` | `jj git fetch` then `jj rebase -d <branch>` |
| push a PR branch | `git push -u origin x` | `jj git push --bookmark x` |
| undo | `git reset` / reflog | `jj undo` / `jj op restore <op>` |
| split a commit | `git add -p` (interactive) | `jj split <path> -m "msg"` (non-interactive) |
| move changes between commits | `git rebase -i` (squash) | `jj squash --from <r> --into <r>` |

## The model in one paragraph

The working copy **is** a commit (`@`). There is **no staging area** — `git add`
has no meaning. Editing files and then running any jj command snapshots them into
`@`. You name a change with `jj describe -m`; you start the next change with
`jj new`. Reference commits by **change ID** (stable across rewrites), not commit
hash. Bookmarks are jj's name for git branches and only matter at the Git boundary.

## Core verbs (verified)

```bash
jj --no-pager status                      # working-copy + conflict summary
jj --no-pager log --limit 10              # graph; add -T '<template>' for custom
jj --no-pager diff [--stat] [--git]       # changes in @ (or -r <rev>)
jj describe -m "msg"                       # set @'s description
jj new [REV] -m "msg"                       # start a new change (REV = parent)
jj commit -m "msg"                          # finalize @ and open a fresh empty @
jj split <paths> -m "msg"                   # non-interactive: paths → first commit
jj squash [--from R] [--into R] [-m msg]    # move changes between commits
jj rebase -d <dest> [-s R | -b R | -r R]    # -d and -o/--onto both work in 0.42
jj edit <rev>                               # make <rev> the working copy (not one another workspace holds — see parallel-agents.md)
jj abandon <rev>                            # drop a change
```

## Bookmarks & Git remote (verified)

```bash
jj bookmark create <name> -r @-     # create at a revision (also: set -r, move --to/--from)
jj bookmark list                    # add --all-remotes for remote-tracking bookmarks
jj git fetch                        # fetch from a git remote
jj git push --bookmark <name>       # push a bookmark; NEW bookmarks push directly
jj git push --change @              # auto-create + push a "push-<changeid>" bookmark
```

There is **no `--allow-new`** in 0.42 (it was removed). A bookmark does **not**
auto-advance when you add commits — `jj bookmark move <name> --to @-` before re-push.

## Revsets (the agent superpower)

Target commits precisely instead of guessing hashes. Test a revset with
`jj --no-pager log -r '<revset>'` before mutating.

| Revset | Meaning |
| --- | --- |
| `@` / `@-` | working copy / its parent |
| `mine()` | changes you authored |
| `trunk()` | the trunk/main bookmark |
| `description(substring:"text")` | match on description. **Bare `description("text")` is a `glob:` pattern in 0.42** and won't match a full message (descriptions store a trailing `\n`) — use `substring:` for a fragment, or `exact:"text\n"` for an exact match |
| `conflicts()` | revisions with conflicts |
| `x::y` / `::x` | ancestry ranges; `x \| y` is union (NOT comma) |

Templates use jj's own language: join with `concat(...)`, the field is
`description` (not `desc`), and after `jj describe` the `@` pointer **moves** — verify
by the original change ID, not `@`.
