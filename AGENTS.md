# AGENTS.md — jujutsu-workflow-skill

Agent-safe version-control workflows using Jujutsu (`jj`) with Git-backed
repositories. `jj` is the local change-management layer; Git stays the canonical
remote, PR, CI, and audit interface.

## Repo structure

```
.
├── skills/jujutsu-workflow/
│   ├── SKILL.md                     # slim, trigger-gated core (≤500 words)
│   ├── references/                  # progressive-disclosure docs (loaded on demand)
│   │   ├── command-map.md           # git→jj translation + verified command/revset map
│   │   ├── agent-safety.md          # no-pager, non-interactive, snapshot myth, hooks, signing
│   │   ├── git-interop.md           # colocated detection, exclusive-mode, read-only git
│   │   ├── recovery-playbook.md     # op log/undo/restore, conflicts, divergent, stale
│   │   ├── pr-handoff.md            # bookmark→push→PR (gh/glab), CI, cleanup, review
│   │   ├── parallel-agents.md       # workspaces; absorption & bundling mitigations
│   │   └── why-jj-for-agents.md     # evidence-backed thesis + "when NOT to use jj"
│   └── scripts/
│       ├── detect_jj_state.sh       # git-only / jj-only / colocated detection (tested)
│       └── verify_handoff.sh        # final verification gate (tested)
├── tests/smoke_test.sh              # end-to-end proof against a real jj repo + remote
├── docs/PRD.md                      # product requirements (living working document; R2 authoritative)
├── .claude-plugin/plugin.json       # plugin metadata
├── .github/workflows/               # CI: validate, release, auto-merge-deps
├── composer.json / package.json     # PHP / Node distribution
├── renovate.json                    # dependency automation
├── LICENSE-MIT / LICENSE-CC-BY-SA-4.0
└── README.md
```

## Commands

- `bash skills/jujutsu-workflow/scripts/detect_jj_state.sh [--json]` — report repo VCS state.
- `bash skills/jujutsu-workflow/scripts/verify_handoff.sh [--require-bookmark]` — handoff gate.
- `bash tests/smoke_test.sh` — end-to-end proof (requires `jj` on PATH; uses a temp dir).
- `bash <skill-repo-skill>/skills/skill-repo/scripts/validate-skill.sh .` — validate repo structure.

## Rules

1. **`jj` for local mutation, Git for the external contract.** Mutate with `jj`;
   use Git read-only for verification.
2. **Detect repo state before mutating** (`git-only` / `jj-only` / `colocated` / `none`).
3. **Agent-safety is non-negotiable:** `--no-pager`, always `-m`, never editor/TUI forms.
4. **Never push to protected/default branches; never rewrite public history** unless allowed.
5. **Recover with the operation log** (`jj op log`, `jj undo`, `jj op restore`) before destructive Git recovery.
6. **Always finish with the verification gate** showing both `jj` and Git state.

## Conventions

- Follows the Netresearch skill-repo standard (split MIT + CC-BY-SA-4.0 licensing,
  reusable-workflow CI callers, no `composer.lock`).
- All `jj` commands are verified against **jj 0.42.0** (`compatibility` in SKILL.md frontmatter).
- No `agents/openai.yaml` (Netresearch house convention; OpenAI description derives from `SKILL.md`).

## References

- [SKILL.md](skills/jujutsu-workflow/SKILL.md) — skill runtime instructions and the 7 reference docs.
- [docs/PRD.md](docs/PRD.md) — product requirements (Revision 2 is authoritative) and competitive analysis.
