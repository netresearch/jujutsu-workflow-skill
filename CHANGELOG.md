# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for 0.1.0 through 0.3.0 were reconstructed from git history when this file
was introduced in 0.3.1; the GitHub Releases for those tags remain the original record.

## [Unreleased]

### Added

### Changed

### Fixed

## [0.3.1] - 2026-08-08

Follows on from the worktree fix in 0.3.0 (#18): it was verified against jj 0.43.0
while the skill still declared 0.42.0, and this release closes that mismatch.

### Added

- `tests/verify_jj_version.sh` — a compatibility probe that re-checks every
  documented command, flag and revset against the installed jj, so a new jj
  release is one command to verify instead of a manual pass. Exits 1 on drift.
- `pr-handoff.md`: `jj git push` rejects the push when **any** commit in the
  pushed range has no description, ancestors included — not just the bookmark
  target. Documented with the range check that catches it before pushing.
- `agent-safety.md` §6: setting `user.name` / `user.email` applies to future
  commits only; the existing working-copy commit keeps the old author until
  `jj metaedit --update-author`. An agent that configures identity after making
  changes otherwise pushes commits that fail DCO.
- This `CHANGELOG.md`.

### Changed

- `compatibility` now reads "Verified against jj 0.42.0 and 0.43.0". The full
  command surface — 53 commands, flags and revsets, including the five
  editor/TUI forms `agent-safety.md` forbids — was re-verified hands-on against
  jj 0.43.0 with no drift.
- `verify_handoff.sh` and `tests/superiority_evals.sh` reformatted with `shfmt`
  (formatting only; both suites re-run to confirm behaviour is unchanged). Every
  shell file in the repo now passes `shellcheck` and `shfmt`.

## [0.3.0] - 2026-08-08

Reported by @plttn in #18 — including the `discard_changes: true` trap, which is
what makes the state destructive rather than merely confusing.

### Added

- `worktree-shadowed` detection: a harness-created git worktree (Claude Code's
  `EnterWorktree`, `--worktree`, `isolation: "worktree"`, background sessions)
  has no `.jj/` of its own, so jj walks up and answers for the **parent** repo.
  Reads report a clean tree over real edits, and writes commit the parent
  checkout's uncommitted work. `detect_jj_state.sh` now reports the mode and
  exits 3; `git-interop.md`, `agent-safety.md` and `recovery-playbook.md` cover
  the state, the `discard_changes: true` trap, and what is not recoverable.
- Portable Agent Plugins 1.0.0 manifest (`plugin.json`).

### Changed

- Adopted the shared Netresearch skill-repo template; `validate.yml` dropped in
  favour of the template's `lint.yml`.
- CI: secret and workflow scanning in `security.yml`; jj evals run via the
  shared script-check reusable.

### Fixed

- `detect_jj_state.sh --json` emitted string fields unescaped, so a repo path
  containing a double quote produced unparseable output.
- Corrected a data-destroying recipe in `git-interop.md`: `jj git init
  --git-repo=…` checks the parent commit out over a dirty working copy, silently
  reverting modified files and deleting untracked ones.

## [0.2.0] - 2026-07-13

### Added

- `evals/evals.json` with structural evals for the skill, plus an
  `eval-validate` CI caller so they are checked on every change.
- `pr-handoff.md`: DCO sign-off and SSH signing guidance for jj.

### Changed

- `why-jj-for-agents.md` trimmed from an advocacy essay to a decision list.

## [0.1.0] - 2026-06-24

### Added

- Initial `jujutsu-workflow` skill: agent-safe jj workflows with Git kept as the
  canonical remote, PR, CI and audit interface.
- Reference set — `command-map.md`, `agent-safety.md`, `git-interop.md`,
  `recovery-playbook.md`, `pr-handoff.md`, `parallel-agents.md`,
  `why-jj-for-agents.md`.
- `detect_jj_state.sh` and `verify_handoff.sh`, both covered by
  `tests/smoke_test.sh` against a real jj repo and Git remote.
- `tests/superiority_evals.sh` — reproducible scenarios where jj beats plain git.
- Netresearch governance ruleset: security and PR-quality workflows,
  `ARCHITECTURE.md`, split MIT + CC-BY-SA-4.0 licensing.

[Unreleased]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/netresearch/jujutsu-workflow-skill/releases/tag/v0.1.0
