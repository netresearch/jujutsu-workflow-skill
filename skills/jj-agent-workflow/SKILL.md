---
name: jj-agent-workflow
description: "Use when a coding agent works in a repository where Jujutsu (jj) is available — jj commands, patch stacks, speculative edits, splitting changes, operation-log recovery (jj undo / jj op restore), git/GitHub/GitLab PR handoff, or review-comment updates. Uses jj as the local change-management layer while keeping Git as the canonical remote, PR, CI, and audit interface, and replaces fragile git reset/checkout/stash/rebase recovery with safer, reversible jj operations."
license: "(MIT AND CC-BY-SA-4.0). See LICENSE-MIT and LICENSE-CC-BY-SA-4.0"
metadata:
  author: Netresearch DTT GmbH
  version: "0.1.0"
  repository: https://github.com/netresearch/jj-agent-workflow-skill
---

# jj Agent Workflow

Use `jj` as the local change-management layer and Git as the external collaboration layer. `jj` is the agent's scratch-and-history engine; Git stays the contract with the outside world — remote, PR, CI, review, release, and audit.

## Core rules

1. Detect repository state before any version-control mutation.
2. Prefer `jj` for local mutations; use Git mostly for read-only verification.
3. Never push directly to protected or default branches.
4. Never rewrite public history unless the user or project explicitly allows it.
5. Use operation-log recovery (`jj op log`, `jj undo`, `jj op restore`) before destructive Git recovery.
6. Do not rely on Git's staging area — `jj` ignores it.
7. Split unrelated changes into separate commits before handoff when possible.
8. Never claim success without showing version-control state and command output.

## Detect state first

```bash
git rev-parse --show-toplevel 2>/dev/null || true
jj root 2>/dev/null || true
git status --short --branch 2>/dev/null || true
jj status 2>/dev/null || true
```

If neither Git nor `jj` is present, do not invent a workflow. If Git exists but `jj` does not, use Git unless explicitly asked to initialize `jj`. In a colocated repo, mutate with `jj` and verify with read-only Git.

## Edit loop

```bash
jj status
jj log --limit 10
# edit files — jj auto-snapshots the working copy
jj diff
jj describe -m "<project-conventional message>"
```

## Handoff

Update from the remote with `jj git fetch` instead of `git pull`, then rebase your change onto the project's default branch. Create a Git-visible bookmark and push it for the PR; never push to a protected or default branch. Defer to project governance: branch protection, CODEOWNERS, commit conventions, signed commits, CI gates, and merge strategy. Disclose any force-push or history rewrite explicitly.

## Final verification gate

Before claiming completion, run and report:

```bash
jj status
jj log --limit 10
jj diff --stat
git status --short --branch
git log --oneline -n 5
```

Report the exact commands and their results. If a check was skipped or unavailable, say so. Never say "done", "tested", or "ready to merge" without observed output, and surface any unresolved conflict.
