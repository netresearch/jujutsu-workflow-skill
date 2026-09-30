<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case — jujutsu-workflow-skill

This document states what a user can expect from this repository in terms of security, and argues why that expectation holds. Every claim names the file that implements it. Reporting a vulnerability: see the [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md). Components: [ARCHITECTURE.md](ARCHITECTURE.md).

## What the repository ships

| Part | Files | Runs where |
| --- | --- | --- |
| Skill instructions for an AI agent | `skills/jujutsu-workflow/SKILL.md`, `skills/jujutsu-workflow/references/*.md` | Read by the agent as instructions; not executed. The agent may run the `jj`, `git`, `gh` and `glab` commands they describe in the user's repository. |
| Detection script | `skills/jujutsu-workflow/scripts/detect_jj_state.sh` | On the user's machine, in the current directory. |
| Handoff gate | `skills/jujutsu-workflow/scripts/verify_handoff.sh` | On the user's machine, in the current jj repository. |
| Eval definitions | `evals/evals.json` | Data read by the eval validator; not executed. |
| Test suites | `tests/smoke_test.sh`, `tests/superiority_evals.sh`, `tests/verify_jj_version.sh` | In this repository's CI (the first two) and on contributors' machines. |

The repository ships no server component, no container image and no compiled code. It stores nothing and handles no user accounts or credentials of its own.

## Security requirements

1. The two scripts do not change the user's history, bookmarks or remotes: they run no command that describes, creates, rebases, abandons or pushes a change. The only change they cause is jj's own working-copy snapshot (see the last section).
2. `verify_handoff.sh` fails (exit 1) when a handoff would push a protected branch or carries unresolved conflicts, so an agent cannot report "ready" over those states.
3. `detect_jj_state.sh` reports a git worktree that sits under a jj repository as `worktree-shadowed` and exits 3, so an agent does not act on jj output that describes a different checkout.
4. The scripts do not hang an agent: every `jj` command that prints runs with `--no-pager` or with its output captured, and no command opens an editor.
5. The test suites never touch the contributor's own repositories or jj configuration.
6. Nothing committed to this repository contains a secret, and a release can be verified against the build that produced it.

## Actors and trust boundaries

- **Skill user and agent.** The agent reads `SKILL.md` and the references and runs commands in the user's repository with the user's privileges. What it runs is decided by the agent and the user, not by this repository. `SKILL.md` declares no `allowed-tools`.
- **The user's repository and jj configuration.** Both scripts read repository state through `git` and `jj`: `git rev-parse`, `git status`, `jj root`, `jj status`, `jj log`, `jj bookmark list`, `jj resolve --list`, `jj diff --stat`, `jj config get ui.paginate`. File names, bookmark names and paths from the repository are input from outside this repository; the scripts print them and, with `--json`, embed them in JSON strings.
- **Command-line arguments.** `--bookmark` and `--protected` of `verify_handoff.sh` are names chosen by the caller. They are only compared with each other and with the bookmark names jj reports, and are never executed.
- **Git remote.** The skill instructs the agent to push with `jj git push --bookmark <branch>` and to open the pull request with `gh` or `glab`; the scripts themselves send nothing over the network.
- **Contributors.** Changes reach `main` through pull requests, checked by the workflows in `.github/workflows/`.
- **CI.** Workflows run on GitHub-hosted runners with `permissions: {}` at the top level and grant each job only the scopes its called reusable workflow needs (`.github/workflows/*.yml`). The three `pull_request_target` workflows (`auto-merge-deps.yml`, `labeler.yml`, `pr-quality.yml`) only call reusable workflows that do not check out pull request code: they merge dependency update pull requests, label pull requests, and approve pull requests from repository collaborators. `auto-merge-deps.yml` passes two named secrets instead of `secrets: inherit`. `evals.yml` downloads the jj release named by the pinned tag from `github.com/jj-vcs/jj` over HTTPS and checks the archive against the sha256 digest pinned next to the tag before extracting it and running the test suites.

## Threats and countermeasures

| Threat | Countermeasure | Evidence |
| --- | --- | --- |
| An agent pushes a protected or default branch directly | The gate collects the push targets (`--bookmark`, or the bookmarks on `@-` and `@`) and fails when one of them is in the protected list (default `main master trunk develop`, set with `--protected`) | `verify_handoff.sh`; `tests/smoke_test.sh` ("FAILs when pushing a protected branch") |
| An agent hands off a change with unresolved conflicts | `jj resolve --list` output makes the gate fail | `verify_handoff.sh`; `tests/smoke_test.sh` ("FAILs on unresolved conflict") |
| jj in a harness-created git worktree answers for the parent checkout, and an agent commits or discards work it cannot see | Detection compares `jj root` with `git rev-parse --show-toplevel` inside a linked worktree, reports `worktree-shadowed`, exits 3, and takes the working-copy state and default branch from git instead of `jj status` and `jj bookmark list` | `detect_jj_state.sh`; `tests/smoke_test.sh` (section G); `references/agent-safety.md` section 7 |
| An agent hangs on a pager or an editor and its session is lost | The scripts pass `--no-pager` to `jj status`, `jj log`, `jj diff` and `jj resolve --list`, and capture the output of the other `jj` calls; the skill forbids the editor forms and names their non-interactive replacements | the two scripts; `SKILL.md` section 2; `references/agent-safety.md` sections 1 and 2 |
| A missing option value makes the gate loop forever | `--bookmark` and `--protected` without a value are a usage error (exit 2) | `verify_handoff.sh`; `tests/smoke_test.sh` ("without a value is a usage error") |
| Destructive Git recovery (`reset`, `checkout`, `stash`) loses an agent's work | The skill directs recovery through the jj operation log (`jj undo`, `jj op restore`) and forbids mutating raw `git` in a colocated repository | `SKILL.md` sections 1 and 4; `references/recovery-playbook.md`; `tests/smoke_test.sh` (section D); `tests/superiority_evals.sh` |
| A path or bookmark name with a quote, backslash, newline, carriage return or tab breaks the `--json` output of the detection script | Every string value passes through `json_escape`, which escapes backslash, double quote, newline, carriage return and tab | `detect_jj_state.sh` |
| An argument or a name from the repository is executed as a command (CWE-78) | No argument and no command output reaches `eval`, `sh -c` or a command position; they are only compared and printed | the two scripts |
| A test run changes the contributor's repositories or jj configuration | Each suite works in a `mktemp -d` directory removed by an `EXIT` trap and sets `JJ_CONFIG` to a file inside it | `tests/smoke_test.sh`, `tests/superiority_evals.sh`, `tests/verify_jj_version.sh` |
| A documented jj command stops working on a new jj release | CI runs both suites against the pinned jj version; `verify_jj_version.sh` re-checks every documented command, flag and revset before `compatibility` in `SKILL.md` is changed | `.github/workflows/evals.yml`, `tests/verify_jj_version.sh` |
| A released archive is tampered with | The release workflow publishes a Cosign-signed `SHA256SUMS.txt` and build-provenance attestations for the archives | `.github/workflows/release.yml` (calls the skill-repo-skill release reusable) |
| A secret is committed | Betterleaks scans every push to `main` and every pull request to `main` | `.github/workflows/security.yml` |
| A vulnerable or malicious dependency is added | Dependency review checks the dependencies a pull request adds or changes against known vulnerabilities; Composer Audit checks the Composer dependency (`netresearch/composer-agent-skill-plugin`) against known advisories; Renovate proposes updates | `.github/workflows/security.yml`, `composer.json`, `renovate.json` |
| Insecure code or workflow patterns | Opengrep scans the code for insecure patterns; zizmor analyses the workflows; ShellCheck runs on every `*.sh` file in Skill Validation | `.github/workflows/security.yml`, `.github/workflows/lint.yml` |

Which of these checks must pass before a pull request can merge is set in the branch protection of `main`, not in this repository.

## Secure design principles applied

- **Least privilege:** the scripts only read repository state and print it; workflows start from `permissions: {}` and grant per job.
- **Fail-safe defaults:** the gate treats every protected-list bookmark as a failure unless the caller changes the list, and exits 1 on any failed check; detection exits 3 in the shadowed state instead of reporting a normal mode.
- **Economy of mechanism:** the scripts need bash, `git`, `jj` and the usual text tools (`grep`, `sed`, `awk`, `head`, `sort`, `tr`); each is under 200 lines.
- **Open design:** everything the skill tells an agent to do is plain text in `SKILL.md` and `references/`, reviewable before use.

## What a user cannot expect

- The skill gives guidance; it does not enforce it. The agent runs `jj`, `git`, `gh` and `glab` with the user's privileges. Review what an agent proposes to run, in particular pushes and history rewrites.
- The scripts do not change commits, but they are not free of side effects: `jj status`, `jj log` and similar commands snapshot the working copy, which records the current files as a new entry in jj's operation log (`references/agent-safety.md` section 3).
- `verify_handoff.sh` exits 0 with the message "nothing to verify" when `jj` is not installed or the directory is not a jj repository. That exit status is not evidence that a change is ready.
- The gate knows only the protected branch names it is given (default `main master trunk develop`). It does not read the remote's branch protection; a repository with another protected branch name needs `--protected`.
- `detect_jj_state.sh` reports what `git` and `jj` report. It recognises the shadowed state only for a linked git worktree; it does not verify the integrity of `.jj/` or `.git/`.
- The example commands in `references/` are guidance to adapt to the project's own rules for branches, signing and pushing.
- Security fixes follow the supported-versions rules of the organisation's security policy; older releases may not receive them.
