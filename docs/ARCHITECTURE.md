# Architecture — jj-agent-workflow-skill

## Overview

A documentation-and-scripts AI agent skill that teaches coding agents to use
Jujutsu (`jj`) as the local change-management layer while keeping Git as the
canonical remote, PR, CI, and audit interface. The skill claims, proves, and
enforces that jj is superior to pure Git for agentic coding.

## Components

### Skill definition ([`skills/jj-agent-workflow/SKILL.md`](../skills/jj-agent-workflow/SKILL.md))

The slim (≤500-word), trigger-gated entry point loaded by agent frameworks. It
mandates jj-first behaviour when a `.jj/` repo is present, the agent-safety rules
(no pager, non-interactive forms, snapshot-on-command), the edit/recover/handoff
loop, and a verification gate. It links to the references for depth.

### Reference docs ([`skills/jj-agent-workflow/references/`](../skills/jj-agent-workflow/references/))

Progressive-disclosure detail, loaded on demand:

- **[command-map.md](../skills/jj-agent-workflow/references/command-map.md)** — git→jj translation plus the verified command and revset map.
- **[agent-safety.md](../skills/jj-agent-workflow/references/agent-safety.md)** — pager/editor hangs, the snapshot myth, the hook recipe, signing.
- **[git-interop.md](../skills/jj-agent-workflow/references/git-interop.md)** — colocation detection, exclusive-mode rules, worktree→workspace.
- **[recovery-playbook.md](../skills/jj-agent-workflow/references/recovery-playbook.md)** — operation log, undo/restore, first-class conflicts, divergent changes.
- **[pr-handoff.md](../skills/jj-agent-workflow/references/pr-handoff.md)** — bookmark→push→PR (gh/glab), review-update strategies, the gate.
- **[parallel-agents.md](../skills/jj-agent-workflow/references/parallel-agents.md)** — workspaces and the three documented jj-for-agents failure-mode mitigations.
- **[why-jj-for-agents.md](../skills/jj-agent-workflow/references/why-jj-for-agents.md)** — the evidence-backed superiority thesis and an honest "when NOT to use jj".

### Scripts ([`skills/jj-agent-workflow/scripts/`](../skills/jj-agent-workflow/scripts/))

Tested, shellcheck-clean helpers the skill invokes via `${CLAUDE_SKILL_DIR}`:

- **[detect_jj_state.sh](../skills/jj-agent-workflow/scripts/detect_jj_state.sh)** — classifies the repo as `git-only` / `jj-only` / `colocated` / `none`.
- **[verify_handoff.sh](../skills/jj-agent-workflow/scripts/verify_handoff.sh)** — the final handoff gate (conflicts, protected branch, bookmark presence).

### Evals / proof ([`tests/`](../tests/))

- **[smoke_test.sh](../tests/smoke_test.sh)** — end-to-end proof that the documented workflow works in a real colocated repo + remote.
- **[superiority_evals.sh](../tests/superiority_evals.sh)** — paired jj-vs-git scenarios that demonstrate jj's concrete advantages.

[`.github/workflows/evals.yml`](../.github/workflows/evals.yml) installs the pinned
jj version and runs both suites in CI, so the proof is continuous.

### Specification ([`docs/PRD.md`](PRD.md))

The living product requirements. Revision 2 is authoritative (verified command
corrections and the superiority requirements); Revision 1 is preserved for history.

## Design decisions

- **jj for local change-shaping, Git for the external contract.** Agents get a
  forgiving, fully reversible workspace; humans and CI see ordinary Git.
- **Anti-hype.** Every claimed advantage is tied to a mechanism or a citation; no
  unverifiable "Nx faster" / "quantum" claims. Comparisons in the evals are fair.
- **Verified, not asserted.** All `jj` commands are checked against jj 0.42.0 and
  exercised by the eval suites; the tested version is pinned in the skill frontmatter.
- **Progressive disclosure.** A small always-on SKILL.md with deep references keeps
  the hot context small while making detail available on demand.

## Distribution

Split licensing (MIT for code, CC-BY-SA-4.0 for content); installable via the
Netresearch marketplace, npx/skills.sh, release download, Composer, or npm.
