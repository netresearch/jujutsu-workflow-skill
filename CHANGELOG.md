<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for 0.1.0 through 0.3.0 were reconstructed from git history when this file
was introduced in 0.3.1; the GitHub Releases for those tags remain the original record.

## [Unreleased]

### Added

- Command map: non-interactive `jj new --no-edit -A/-B`, `jj describe --stdin`, `jj revert` (replaces `jj backout`), `jj diff --from/--to`, `jj resolve --tool :ours`, `jj bisect run`, `jj evolog -p`, and `jj help -k` for syntax lookup
- Revsets for `change_id()`, the mutable stack, and `working_copies()`, plus the shell-quoting and `glob:` character-class gotchas
- Recovery: record the op ID before a risky rewrite, and recover one change with `evolog` + `restore --into` instead of a repo-wide `op restore`
- Safety: immutable commits, `git.private-commits`, and `snapshot.max-new-file-size`
- PR handoff: `jj git push --deleted` and the stacked-PR retarget-before-delete order
- `verify_jj_version.sh` claims for each new command
- SKILL.md and agent-safety: `jj describe --stdin` fed by a quoted heredoc for multi-line messages, trailers and backticks
- `verify_jj_version.sh` claims for jj 0.46 workspace colocation: a new workspace in a colocated repo gets a `.git` file under the main repo's `.git/worktrees/`, its Git `HEAD` sits at `@-`, `jj workspace forget` removes the Git worktree, and `jj git colocation enable` converts a `--no-colocate` workspace. On older jj the probe asserts a workspace gets no `.git`
- Smoke test: `detect_jj_state.sh` reports a jj 0.46+ workspace as `colocated`, not `worktree-shadowed` (skipped on older jj)

### Changed

- git-interop: a jj 0.46+ workspace counts as colocated; the workspace section covers its Git worktree, cleanup with `jj workspace forget`, and `jj git colocation enable`
- git-interop and parallel-agents: a colocated jj 0.46+ workspace needs Git 2.42 or newer, the minimum jj 0.46 supports; with older Git, `jj workspace add --no-colocate` is an unsupported workaround
- git-interop and parallel-agents: snapshot a workspace with `jj status` before `jj workspace forget`, which does not snapshot it; `git.colocate = false` turns workspace colocation off, and `jj git colocation enable` fails for a repo backed by an external Git repository
- Compatibility re-verified on jj 0.46.0 with no drift

## [1.0.1] - 2026-10-18

### Fixed

- `verify_handoff.sh --bookmark` and `--protected` as the last argument no longer hang: a missing value exits 2 with "needs a value"
- `verify_handoff.sh --protected --strict …` no longer takes `--strict` as the protected list: a recognised option in the value position exits 2 like a missing value
- `--help` of `detect_jj_state.sh` and `verify_handoff.sh` prints the whole header comment; `detect_jj_state.sh` no longer drops the `none` mode, and `verify_handoff.sh` no longer prints a line of code
- `verify_handoff.sh` header: the protected-branch and `--require-bookmark` checks look at the push targets, not only the bookmark at `@`

### Added

- SPDX licence and copyright notices in the shipped skill files
- README: a "Governance and policies" section linking the organisation's policies and naming the checks that run on pull requests
- `docs/SECURITY-ASSURANCE.md`: a security assurance case covering trust boundaries, threats, countermeasures and limits

### Changed

- CI runs the eval suites and `tests/verify_jj_version.sh` on jj 0.42.0 and on the newest jj release, on every pull request and weekly

## [1.0.0] - 2026-09-23

### Changed

- First stable release. From 1.0.0 on, an incompatible change to what this plugin exposes — skill names, trigger descriptions, the arguments and output of its scripts — ships only in a new major version.

## [0.3.4] - 2026-09-11

### Added

- README: the `/plugin install` step missing from the marketplace section, and a "Without a marketplace" section covering the skills-directory route

### Changed

- `@netresearch/agent-skill-coordinator` peer dependency accepts `^0.2.0` alongside `^0.1`

## [0.3.3] - 2026-09-03

### Added

### Changed

- Agent-safety now relies on the `--no-pager` flag alone. The skill no longer
  tells agents to run `jj config set --user ui.paginate never`: `--user` writes
  the human's own config file, outlives the agent session, and takes paging away
  from their interactive `jj` as well. Reported by @plttn in #25.
  `jj --config ui.paginate=never <cmd>` is documented as the non-persistent
  equivalent where a per-command flag is not enough.

### Fixed

## [0.3.2] - 2026-08-12

### Changed

- Credit the reporter of the 0.3.0 worktree issue (#18) in the 0.3.1 notes

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

[Unreleased]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.4...v1.0.0
[0.3.4]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/netresearch/jujutsu-workflow-skill/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/netresearch/jujutsu-workflow-skill/releases/tag/v0.1.0
