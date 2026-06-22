# PR handoff — turn a jj change into a reviewable Git PR

Git is the contract with the outside world. The agent's deliverable is a clean,
Git-visible branch and a PR a human can review with ordinary Git tools.

## Update from the remote (no `git pull`)

```bash
jj git fetch
jj rebase -d <default-branch>      # e.g. main; detect_jj_state.sh reports it
```

`jj git fetch` + `jj rebase` is the two-step equivalent of `git pull` (jj has no
single pull command). Rebasing onto the fresh trunk keeps the PR mergeable.

## Two handoff modes

### Mode A — auto-generated bookmark (fastest)

```bash
jj git push --change @          # creates and pushes "push-<changeid>"
```

Use when the team accepts generated branch names. The change must be described
(have a message) first.

### Mode B — named bookmark (when naming conventions matter)

```bash
jj bookmark create feat/short-topic -r @-
jj git push --bookmark feat/short-topic     # new bookmarks push directly (no --allow-new)
```

Use Mode B for Conventional-Commit / ticket-prefixed branch names. Match the
project's branch-naming rule.

## Open the PR

```bash
gh pr create --base <default-branch> --head <bookmark> --fill   # GitHub
# GitLab:
glab mr create --source-branch <bookmark> --target-branch <default-branch> --fill
```

Then follow the project's existing PR rules (templates, CODEOWNERS, signed commits,
required checks). This skill does not override them — see the repo's git-workflow /
github-project conventions.

## Updating a PR after review

Pick the strategy the project prefers and state which you used.

### Additive commits (preserve review history)

```bash
jj new <bookmark> -m "review: address comments"
# edit files
jj --no-pager diff
jj bookmark move <bookmark> --to @-
jj git push --bookmark <bookmark>
```

### Amend in place (clean history; needs force-push permission)

```bash
jj edit <bookmark>          # safe for a single agent; never edit a change another workspace holds (see parallel-agents.md)
# edit files
jj --no-pager diff
jj bookmark move <bookmark> --to @-
jj git push --bookmark <bookmark>     # rewrites the branch — only where allowed
```

Rewriting a published branch is a force-push: only on a PR/topic branch, only when
the project allows it, and **disclose it** in your final report.

## Safety rules

- **Never** push to a protected/default branch: no `jj git push --bookmark main`,
  no `git push origin main`. `verify_handoff.sh` fails if a protected bookmark sits
  at `@`.
- A bookmark does not auto-advance — `jj bookmark move <name> --to @-` before
  re-pushing, or the PR won't update.
- After merge: `jj bookmark delete <name>` and `jj git fetch` to clean up.

## Final verification gate

Run before claiming the PR is ready:

```bash
${CLAUDE_SKILL_DIR}/scripts/verify_handoff.sh --require-bookmark
```

It prints `jj status` / `jj log` / `jj diff --stat` / `git status` and **fails** on
unresolved conflicts, a protected branch at `@`, or a missing handoff bookmark.
Report the exact commands and their output. Do not claim "done", "tested", or
"ready to merge" without it — and if CI ran, cite the actual result.
