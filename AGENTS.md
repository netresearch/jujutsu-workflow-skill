# AGENTS.md — jj-agent-workflow-skill

Agent-safe version-control workflows using Jujutsu (`jj`) with Git-backed
repositories. `jj` is the local change-management layer; Git stays the canonical
remote, PR, CI, and audit interface.

## Repo structure

```
.
├── skills/jj-agent-workflow/
│   └── SKILL.md                    # Skill definition (agent runtime instructions)
├── docs/
│   └── PRD.md                      # Product requirements (living working document)
├── .claude-plugin/plugin.json      # Plugin metadata
├── .github/workflows/              # CI: validate, release, auto-merge-deps
├── composer.json                   # PHP distribution
├── package.json                    # Node distribution
├── renovate.json                   # Dependency automation
├── LICENSE-MIT                     # Code license
├── LICENSE-CC-BY-SA-4.0            # Content license
└── README.md
```

## Commands

No Makefile or build scripts — this is a documentation-only skill repo.

- `bash <skill-repo-skill>/skills/skill-repo/scripts/validate-skill.sh .` — validate repo structure (run from repo root).

## Rules

1. **`jj` for local mutation, Git for the external contract.** Mutate with `jj`;
   use Git mostly for read-only verification.
2. **Detect repo state before mutating** (Git-only, `jj`-only, or colocated).
3. **Never push to protected/default branches; never rewrite public history**
   unless the user/project explicitly allows it.
4. **Recover with the operation log** (`jj op log`, `jj undo`, `jj op restore`)
   before reaching for destructive Git recovery.
5. **Always finish with a verification gate** showing both `jj` and Git state.

## Roadmap (per docs/PRD.md)

The current `SKILL.md` is the strict MVP core (detect → edit loop → handoff →
verification gate). The PRD's reference set (`references/agent-safe-jj-workflows.md`,
`git-interop.md`, `recovery-playbook.md`, `pr-handoff.md`, `command-map.md`) and
helper scripts (`detect_jj_state.sh`, `verify_handoff.sh`) are the next build
phase; their exact `jj` commands are verified against the official Jujutsu docs
before they are added.

## Conventions

- This repo follows the Netresearch skill-repo standard (split MIT + CC-BY-SA-4.0
  licensing, reusable-workflow CI callers, no `composer.lock`).
- No `agents/openai.yaml` is shipped (matching the Netresearch skill-repo house
  convention; the OpenAI agent description is derived from `SKILL.md`).

## References

- [SKILL.md](skills/jj-agent-workflow/SKILL.md) — skill runtime instructions.
- [docs/PRD.md](docs/PRD.md) — full product requirements and design rationale.
