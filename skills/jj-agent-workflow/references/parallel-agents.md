# Parallel agents & avoiding jj's documented failure modes

A team that adopted jj for agents and then **removed it** (the field report behind
`2389-research/agentjj`) documented three concrete failure modes. A best-in-class
skill names and mitigates each — they are the difference between jj helping and jj
hurting an agent workflow.

## Failure mode 1 — commit absorption

**Symptom:** a multi-step task collapses into one giant commit. Because the working
copy is itself a commit and edits keep flowing into `@`, an agent that never starts
a new change ends up with everything absorbed into a single fat commit.

**Mitigation:**

- Start a **new change per logical unit**: after finishing one coherent piece, run
  `jj new -m "<next unit>"` before the next. The describe-then-`jj new` rhythm keeps
  history reviewable.
- Recover after the fact by splitting the fat commit **non-interactively**:

  ```bash
  jj split <paths-for-first-piece> -m "feat: first piece"
  # repeat on the remainder until each commit is one logical change
  ```

- This is exactly where jj **beats** git for cleanup: splitting by path is a single
  declarative command, no interactive `git add -p` / `git rebase -i` session.

## Failure mode 2 — parallel bundling (the single-writer trap)

**Symptom:** two subagents editing the same working copy have their changes bundled
into one commit, or clobber each other. A jj repo has **one** working copy (`@`); it
is a single writer.

**Mitigation — one workspace per concurrent agent:**

```bash
jj workspace add ../agent-a        # agent A works here
jj workspace add ../agent-b        # agent B works here, isolated working copy
jj workspace list
```

Each workspace has its own `@` but shares the operation log and store, so results
integrate cleanly and every workspace's history is visible. Never point two agents
at the same working directory.

Cleanup (order matters):

```bash
jj workspace forget <name>     # tell jj first
rm -rf ../agent-a              # then remove the directory
```

Forgetting after deleting leaves a stale workspace entry; deleting a workspace dir
without forgetting can produce a stale/dangling working copy.

## Failure mode 3 — colocated git/jj desync

**Symptom:** an agent falls back to raw `git` mutations in a colocated repo and the
two views diverge into an "impossible" state.

**Mitigation:** in a colocated repo, mutate only with jj; keep git read-only. If a
desync already happened, reconcile with `jj git import` / `jj git export`. Full
rules in [git-interop.md](git-interop.md) and [agent-safety.md](agent-safety.md).

## Don't `jj edit` another workspace's `@`

Editing a change that another workspace currently has checked out as its working
copy produces a **divergent change** (`change_id??`, two commits for one change).
Each workspace should work on its own changes; recover divergence per
[recovery-playbook.md](recovery-playbook.md).

## When parallelism isn't worth it

If subagents would touch the same files, workspaces don't remove the logical
conflict — they just record it cleanly. For tightly-coupled work, sequence the
agents instead. Parallel workspaces shine when the work is genuinely independent
(separate modules, separate files).
