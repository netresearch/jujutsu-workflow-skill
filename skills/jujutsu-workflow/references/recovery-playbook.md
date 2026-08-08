# Recovery playbook — the operation log is your safety net

Every repo-modifying jj command is recorded in the **operation log**. This makes
almost any mistake reversible — the agent advantage git's reflog only approximates.

## First response to "something looks wrong"

```bash
jj --no-pager op log --limit 10     # what happened, newest first
jj --no-pager status                # current working-copy + conflict state
jj --no-pager log --limit 20        # the change graph
```

## Undo / restore

```bash
jj undo                  # reverse the LAST operation
jj redo                  # re-apply what you just undid
jj op restore <op-id>    # reset the WHOLE repo to the state after <op-id>
jj op revert <op-id>     # create a new op that reverses a specific past op
```

- `jj undo` is the common case (undo a bad squash/rebase/abandon/describe).
- `jj op restore <op-id>` is the "time machine" — copy an op ID from `jj op log`
  and the repo returns to exactly that state (bookmarks, working copy, everything).
- **Undoing a push is special:** jj warns that undoing a push "often leads to
  conflicted bookmarks" and suggests `jj redo`. Prefer fixing forward (new commit +
  re-push) over undoing a push.

Always state in your final report which recovery command you ran and why.

## Conflicts are first-class — they do not block you

Unlike git (which aborts a rebase/merge into a half-finished state), jj **completes**
the operation and records the conflict inside the commit. A conflicting `jj rebase`
prints guidance and leaves you a normal working copy you can keep operating on.

Detect:

```bash
jj --no-pager status          # shows: "(conflict)" and "There are unresolved conflicts at these paths:"
jj --no-pager resolve --list  # lists each conflicted file
```

jj's conflict markers (richer than git's):

```text
<<<<<<< conflict 1 of 1
%%%%%%% diff from: <base>
-base line
+side A line
+++++++ <rev>
side B line
>>>>>>> conflict 1 of 1 ends
```

Resolve **non-interactively**: edit the file to the intended content (remove all
marker lines), then verify:

```bash
jj --no-pager resolve --list   # should now be empty
jj --no-pager status           # no "(conflict)"
```

Do **not** run `jj resolve` with no arguments (it launches an interactive merge
tool and hangs). Never hand off or push a commit that still shows a conflict.

## Divergent changes (`change_id??`)

A change ID showing twice (`xyz??`) means the same change has two commits — usually
from editing a change that another workspace holds as `@`, or concurrent edits.

```bash
jj --no-pager log -r 'xyz'     # inspect both sides
jj abandon <unwanted-commit-id>  # drop the copy you don't want, by COMMIT id
```

Prevent it: never `jj edit` a change that another workspace has checked out (see
[parallel-agents.md](parallel-agents.md)).

## Stale working copy

If a command reports the working copy is stale (e.g. after external changes to a
shared workspace):

```bash
jj workspace update-stale
```

## "I ran jj from a shadowed worktree"

If `detect_jj_state.sh` reports `worktree-shadowed` (exit 3) *after* you already ran
jj commands there, those commands hit the **parent** repo, not your worktree. The
damage is in the parent, and it can include the human's uncommitted work being
committed under your message.

```bash
cd "$(jj root)"                     # the PARENT repo — where the damage is
jj --no-pager op log --limit 10     # find the ops you caused, by your message
jj undo                             # reverse the last one; repeat, or:
jj op restore <op-id-before-yours>  # roll the parent back wholesale
```

Then go back to the worktree and use **git only**. Your worktree's own files were
never touched by jj — `git status` there still shows them.

Two things this does not cover: work already discarded via `ExitWorktree` with
`discard_changes: true` (jj never recorded it, so no op exists), and a
`jj git init --git-repo=…` run in a dirty worktree, which checks out over the
working copy with no op-log entry. Both are unrecoverable — which is why
[agent-safety.md](agent-safety.md) §7 forbids reaching that point.

## "I think I lost work"

You almost certainly didn't — if a jj command ran after you edited the files, the
content is in the op log. Walk back through `jj op log` and `jj op restore <id>` to
the operation just after your edit. The real loss case is editing files and never
running a jj command before a crash (see the snapshot note in
[agent-safety.md](agent-safety.md) §3) — which the hook recipe prevents.
