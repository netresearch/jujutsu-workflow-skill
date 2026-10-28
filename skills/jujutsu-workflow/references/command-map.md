<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Command map — Git habits → jj (verified against jj 0.42.0, 0.43.0, and 0.46.0)

All commands below were run hands-on against jj 0.42.0 and re-run against 0.43.0
and 0.46.0 with no drift. jj's CLI moves fast; on another version, confirm a flag with
`jj <cmd> --help`.

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
| switch | `git switch x` | `jj edit <rev>` (don't edit a change held by another workspace; see parallel-agents.md) |
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
jj new --no-edit -A R -m "msg"              # insert a change after R (-B: before) without moving @; rebases R's descendants, so check `working_copies()` first
jj describe -r R --stdin <<'EOF' … EOF     # multi-line description, no editor; a message file inside the repo would be snapshotted into the change
jj commit -m "msg"                          # finalize @ and open a fresh empty @
jj split <paths> -m "msg"                   # non-interactive: paths → first commit
jj squash [--from R] [--into R] [-m msg]    # move changes between commits
jj rebase -d <dest> [-s R | -b R | -r R]    # -d and -o/--onto both work
jj edit <rev>                               # make <rev> the working copy (not one held by another workspace — see parallel-agents.md)
jj abandon <rev>                            # drop a change; descendants rebase onto its parent
jj revert -r R -B @                         # inverse of R as a new change (`jj backout` is gone)
jj --no-pager diff --from X --to Y [--stat]  # compare any two revisions
jj resolve --tool :ours <path>              # take one side of a conflict (:theirs for the other); no merge tool
jj bisect run --range GOOD..BAD -- <cmd>    # find the first bad commit; <cmd> exits 0 = good; moves @ — afterwards run the `jj op restore <id>` it prints
jj --no-pager evolog -r R -p                # every prior version of one change, with diffs
```

Look up syntax with `jj --no-pager help -k revsets` (also `filesets`, `templates`,
`bookmarks`) instead of guessing; it prints the reference for the installed
version without a pager.

## Bookmarks & Git remote (verified)

```bash
jj bookmark create <name> -r @-     # create at a revision (also: set -r, move --to/--from)
jj bookmark list                    # add --all-remotes for remote-tracking bookmarks
jj git fetch                        # fetch from a git remote
jj git push --bookmark <name>       # push a bookmark; NEW bookmarks push directly
jj git push --change @              # auto-create + push a "push-<changeid>" bookmark
```

There is **no `--allow-new`** (removed in 0.42, still absent in 0.43). A bookmark
does **not** auto-advance when you add commits — `jj bookmark move <name> --to @-`
before re-push.

**Push rejects any undescribed commit in the pushed range** — ancestors included,
not just the bookmark target: `Won't push commit <id> since it has no description`.
`jj bookmark create -r @-` also warns `Target revision is empty.` when `@-` is a
bare `jj new`. Check the range with
`jj --no-pager log -r 'trunk()..@'` before pushing; see [pr-handoff.md](pr-handoff.md).

## Revsets (the agent superpower)

Target commits precisely instead of guessing hashes. Test a revset with
`jj --no-pager log -r '<revset>'` before mutating.

| Revset | Meaning |
| --- | --- |
| `@` / `@-` | working copy / its parent |
| `mine()` | changes you authored |
| `trunk()` | the trunk/main bookmark |
| `description(substring:"text")` | match on description. **Bare `description("text")` is a `glob:` pattern** and won't match a full message (descriptions store a trailing `\n`) — use `substring:` for a fragment, or `exact:"text\n"` for an exact match |
| `conflicts()` | revisions with conflicts |
| `x::y` / `::x` | ancestry ranges; `x \| y` is union (NOT comma) |
| `change_id(<prefix>)` | resolve a change-ID prefix that a bookmark or tag of the same name hides |
| `roots(mutable() & ::@)::@` | your mutable stack, from its root through `@` (`jj log` lists it top to bottom); add `& bookmarks()` for its bookmarks |
| `working_copies()` / `<name>@` | every workspace's `@` / workspace `<name>`'s `@` |

Quote revsets in single quotes so the shell leaves `()`, `|`, and `~` alone.
`glob:` patterns treat `[...]` as a character class: `description(glob:"[todo]*")`
does not match a literal `[todo]` prefix. Escape the bracket for the prefix,
`description(glob:"[[]todo]*")`; `substring:"[todo]"` matches it anywhere.

Templates use jj's own language: join with `concat(...)`, the field is
`description` (not `desc`), and after `jj describe` the `@` pointer **moves** — verify
by the original change ID, not `@`.
