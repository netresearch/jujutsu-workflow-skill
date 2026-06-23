> **Status:** Working document (living PRD). **Revision 2** below is the
> authoritative spec; **Revision 1** (the original spec) follows for history. R2
> was produced after (a) verifying every command hands-on against `jj 0.42.0`, and
> (b) a competitive analysis of ~20 existing jj agent skills.
>
> **Rename note:** this skill was originally drafted and created as
> `jj-agent-workflow` and renamed to **`jujutsu-workflow`** on 2026-06-23 (SEO:
> "jujutsu" is the rankable proper noun and "agent" is redundant for a skill).
> References below use the current name.

---

# Revision 2 — verified & competitively grounded (2026-06-23)

This revision supersedes Revision 1 where they differ. R1's intent is unchanged
(jj = local change layer, Git = canonical remote/PR/CI/audit interface); R2 fixes
command errors, restructures the package, and adds the requirements that make this
skill demonstrably **superior** to both git-workflow skills and existing jj skills.

## R2.1 Verified command corrections (jj 0.42.0)

All commands were run hands-on in real colocated repos. Corrections to R1:

- **`jj rebase` destination:** R1 FR-007 used `jj rebase -o main`. Verified: in
  v0.42 the destination is `--onto`/`-o` (documented) **and** `-d`/`--destination`
  still works. Both are valid; the skill uses `jj rebase -d <branch>` (long-standing,
  still supported) for readability.
- **`jj git push` new bookmarks:** R1 FR-006/SR-002 implied `--allow-new`. Verified:
  **`--allow-new` does not exist in v0.42.** `jj git push --bookmark <new>` pushes a
  new bookmark directly; `jj git push --change @` auto-creates `push-<changeid>`.
- **Colocation detection:** prefer `jj git colocation status` (official) over heuristics;
  `jj git root` exists and returns the `.git` dir.
- **Conflicts are first-class (proven):** a conflicting `jj rebase` *completes* and
  records the conflict in the commit (`jj st` → `(conflict)`, `jj resolve --list`),
  instead of aborting into git's detached-HEAD/aborted-rebase limbo. `jj undo` reverses it.

## R2.2 Agentic-safety requirements (NEW — the consensus floor)

The #1 failure mode of jj-in-an-agent is **hanging on interactivity**. The skill MUST:

- **FR-011 Non-interactive by default:** always `--no-pager` on output commands and
  set `ui.paginate = never`; always `-m` for messages; **never** invoke editor/TUI
  forms (`jj describe|commit|squash` without `-m`, bare `jj split`, `jj squash -i`,
  `jj resolve`, `jj diffedit`). Provide non-interactive substitutes (split by path,
  edit conflict markers directly).
- **FR-012 Correct the snapshot myth:** jj snapshots the working copy only when a jj
  command runs — **not** on every file write. Ship a hook recipe (SessionStart /
  PreCompact / pre-tool `jj status`) so the safety net is real, not assumed.

## R2.3 Superiority requirements (NEW — what existing skills miss)

- **FR-013 Mitigate the three documented jj-for-agents failure modes** (from the
  field report `2389-research/agentjj`, which adopted then *removed* jj):
  1. **Commit absorption** — multi-step work collapsing into one fat commit. Mitigation:
     mandate `jj new` between logical units; `jj split <path>` to recover.
  2. **Parallel bundling** — a single working copy grabbing two subagents' edits.
     Mitigation: one `jj workspace` per concurrent agent.
  3. **Colocated git/jj desync** — never run mutating raw `git` in a colocated repo.
- **FR-014 Anti-hype + honest scope:** no unverifiable performance claims
  ("23× faster", "87% auto-resolve", "quantum-resistant"). Every benefit is paired
  with a mechanism or citation. Include a **"When NOT to use jj"** section.
- **FR-015 Proven, not asserted:** ship tested `scripts/` and a smoke eval; pin the
  tested jj version (0.42.0) and note graceful degradation across the fast-moving CLI.
- **FR-016 Worktree → workspace redirect:** in a jj repo, redirect `git worktree`
  (and worktree-based agent isolation) to `jj workspace`.

## R2.4 Revised package structure (supersedes §12)

Progressive disclosure (slim SKILL.md + on-demand references), matching the best
existing skills (cryfs, joshuadavidthomas) and exceeding them on agent-safety:

```text
skills/jujutsu-workflow/
├── SKILL.md                         # slim, trigger-gated core (≤500 words)
├── references/
│   ├── command-map.md               # git→jj translation + verified command/revset map
│   ├── agent-safety.md              # no-pager, non-interactive, what-hangs, snapshot myth, hooks, signing
│   ├── recovery-playbook.md         # op log/undo/restore, conflicts, divergent, stale working copy
│   ├── pr-handoff.md                # bookmark→push→PR (gh/glab), CI, cleanup, review-comment strategies
│   ├── git-interop.md               # colocated detection, exclusive-mode, read-only git, traps
│   ├── parallel-agents.md           # workspaces; absorption & parallel-bundling mitigations
│   └── why-jj-for-agents.md         # evidence-backed thesis + "when NOT to use jj"
└── scripts/
    ├── detect_jj_state.sh           # git-only / jj-only / colocated detection (tested)
    └── verify_handoff.sh            # final verification gate (tested)
```

`agents/openai.yaml` is intentionally omitted (no Netresearch skill repo ships one;
the OpenAI description derives from SKILL.md).

## R2.5 Competitive positioning (evidence)

Verified June 2026 across ~20 jj agent skills. Negative examples: `ruvnet/claude-flow`
& `ruvnet/ruflo` (`agentic-jujutsu`) teach a proprietary JS wrapper with zero real jj
commands and hype metrics; `proffesor-for-testing/agentic-qe` ships a content-free stub
(its own team scored the proposal 23% in a "brutal-honesty" review). Strong references:
`danverbraganza/jujutsu-skill` (agent-safety framing), `cryfs/cryfs` (progressive
disclosure), `knoopx/pi` (machine-enforced guardrails, non-interactive hunk tool),
`joshuadavidthomas/agent-skills` (structure), `pkrusche/jj-parallel-agents-skill` (the
only one shipping evals), `carbon-language/carbon-lang` (production detect-and-gate).
This skill adopts the consensus floor and adds R2.2/R2.3 — which, taken together, no
single existing skill provides.

---

# Revision 1 (original, preserved verbatim)

# PRD: `jujutsu-workflow` Skill

## 1. Product summary

**Skill name:** `jujutsu-workflow`

**Product type:** ChatGPT Skill for coding-agent version-control workflows.

**Core idea:**
Teach coding agents to use **Jujutsu (`jj`) as the local change-management layer** while preserving **Git as the canonical collaboration, CI, PR, and audit interface**.

`jj` is a good fit because it has Git-backed repositories, GitHub/GitLab workflow support, a working-copy-as-commit model, operation log/undo, patch-stack workflows, and first-class conflict handling. The skill should exploit those strengths while preventing agents from corrupting Git-visible review state or confusing human maintainers. Jujutsu’s official docs describe Git-backed collaboration, colocated Git/Jujutsu workspaces, `jj git push`, working-copy commits, and operation-log recovery as core workflow concepts. ([JJ VCS Docs][1])

---

## 2. Problem statement

Coding agents are poor Git operators under pressure.

Common failure modes:

* Mixing unrelated edits into one commit.
* Losing work via `git reset`, `checkout`, `stash`, or bad rebase recovery.
* Creating unclear branch states.
* Mishandling review-comment workflows.
* Treating dirty worktrees as exceptional instead of normal.
* Failing to preserve a clean PR handoff for humans and CI.
* Producing final answers that claim “done” without showing version-control state.

Git’s model is workable for humans but not ideal for speculative, iterative agents. `jj` gives agents a better internal model, but only if the workflow is constrained. Unconstrained `jj` usage could create its own failure modes, especially around bookmarks, Git interop, conflict commits, and force-push behavior.

---

## 3. Product goals

### Primary goals

1. **Make coding-agent edits safer**

   * Use `jj` operation history and undo before destructive Git workflows.
   * Prefer reversible `jj` operations over Git reset/rebase/stash sequences.

2. **Improve patch hygiene**

   * Encourage small, reviewable changes.
   * Split unrelated edits.
   * Support patch stacks where appropriate.

3. **Preserve Git compatibility**

   * Treat Git remotes, PRs, CI, branch protection, and release process as authoritative.
   * Ensure final state is understandable to Git-only humans.

4. **Standardize agent handoff**

   * Require explicit final checks:

     * `jj status`
     * `jj log`
     * `jj diff`
     * `git status`
     * relevant test/lint output when available

5. **Prevent dangerous automation**

   * No public history rewriting unless explicitly requested.
   * No direct pushes to protected/default branches.
   * No force-push except controlled PR-branch update and preferably with existing team policy.

---

## 4. Non-goals

This skill must **not** attempt to:

* Replace GitHub, GitLab, Bitbucket, CI, or PR workflows.
* Teach general `jj` from scratch.
* Become a full Jujutsu manual.
* Override project-specific Git rules, branch protection, CODEOWNERS, release processes, or signed-commit requirements.
* Encourage casual force-pushing.
* Hide Git state from humans.
* Make agents depend on `jj` where the repository, CI, or team cannot support it.

Blunt constraint: **`jj` is the agent’s local scratch-and-history engine. Git remains the contract with the outside world.**

---

## 5. Target users

### Primary users

* Coding agents operating in repositories where `jj` is installed or allowed.
* Developers using ChatGPT/Codex/Claude-style agents for multi-file changes.
* Engineering teams experimenting with patch-stack workflows.

### Secondary users

* Tech leads reviewing agent-generated PRs.
* Platform teams defining agent-safe repository workflows.
* Maintainers who want reversible agent edits without abandoning Git.

---

## 6. Personas

### Persona A: Coding agent

Needs to:

* Make edits safely.
* Recover from failed attempts.
* Split changes into reviewable units.
* Produce a clean PR-ready state.
* Avoid irreversible Git operations.

### Persona B: Human reviewer

Needs to:

* Understand what the agent changed.
* Review commits without archaeology.
* Trust that Git-visible state is sane.
* Recover or inspect state using normal Git tools if necessary.

### Persona C: Repository maintainer

Needs to:

* Preserve branch protection and CI rules.
* Prevent agents from rewriting protected history.
* Keep workflows compatible with existing GitHub/GitLab automation.

---

## 7. Core product thesis

`jujutsu-workflow` should optimize for this architecture:

```text
jj  = local speculative editing, patch shaping, undo, stack management
Git = remote transport, CI, PR, review, release, audit
```

That separation is the product.

If the skill tries to make agents “use `jj` everywhere,” it will fail. If it uses `jj` only where it materially improves agent behavior, it becomes valuable.

---

## 8. User stories

### Repository setup

| ID     | User story                                                                                                        | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------- | -------- |
| US-001 | As an agent, I need to detect whether I am in a Git repo, a `jj` repo, or a colocated repo before changing files. | P0       |
| US-002 | As an agent, I need to initialize or use `jj` only when safe and allowed by the user/project.                     | P0       |
| US-003 | As a maintainer, I need the agent to avoid modifying protected branches directly.                                 | P0       |

### Edit workflow

| ID     | User story                                                                              | Priority |
| ------ | --------------------------------------------------------------------------------------- | -------- |
| US-004 | As an agent, I need to inspect baseline state before edits.                             | P0       |
| US-005 | As an agent, I need to make speculative edits without losing previous attempts.         | P0       |
| US-006 | As an agent, I need to split unrelated edits into separate changes before handoff.      | P1       |
| US-007 | As an agent, I need to produce commit descriptions compatible with project conventions. | P1       |

### Recovery

| ID     | User story                                                                                              | Priority |
| ------ | ------------------------------------------------------------------------------------------------------- | -------- |
| US-008 | As an agent, I need to recover from failed operations using `jj op log`, `jj undo`, or `jj op restore`. | P0       |
| US-009 | As a human, I need a clear explanation of what recovery action was taken.                               | P0       |

### PR handoff

| ID     | User story                                                                     | Priority |
| ------ | ------------------------------------------------------------------------------ | -------- |
| US-010 | As an agent, I need to push a Git-visible branch/bookmark for PR creation.     | P0       |
| US-011 | As a reviewer, I need Git commands to show a coherent final state.             | P0       |
| US-012 | As a maintainer, I need force-push behavior to follow explicit project policy. | P0       |

### Review comments

| ID     | User story                                                                                               | Priority |
| ------ | -------------------------------------------------------------------------------------------------------- | -------- |
| US-013 | As an agent, I need to decide whether review comments should become follow-up commits or clean rewrites. | P1       |
| US-014 | As a reviewer, I need the chosen review-update strategy to be visible and intentional.                   | P1       |

---

## 9. Functional requirements

### FR-001: Repository state detection

The skill must instruct agents to run a minimal state-detection sequence before modifying version-control state.

Required checks:

```bash
pwd
git rev-parse --show-toplevel 2>/dev/null || true
jj root 2>/dev/null || true
jj git root 2>/dev/null || true
git status --short --branch 2>/dev/null || true
jj status 2>/dev/null || true
```

Expected behavior:

* If neither Git nor `jj` is present, do not invent a VCS workflow.
* If Git exists but `jj` does not, use Git workflow unless user explicitly asks to initialize `jj`.
* If colocated `jj`/Git exists, prefer `jj` for mutations and read-only Git commands for verification.
* If non-colocated `jj` exists, be careful with Git CLI assumptions and use `jj git root` where needed.

Rationale: Jujutsu supports colocated Git/Jujutsu workspaces where `.jj` and `.git` share the working copy; the official docs say mixing commands is allowed but easiest when Git is mostly read-only and `jj` performs mutations. ([JJ VCS Docs][1])

---

### FR-002: Agent-safe edit loop

The skill must define this default loop:

```bash
jj status
jj log --limit 10
# edit files
jj diff
jj status
```

For meaningful changes:

```bash
jj describe -m "<conventional or project-compatible message>"
```

For committing and opening a new working change:

```bash
jj commit -m "<message>"
```

or, when the workflow requires preserving current working commit semantics:

```bash
jj describe -m "<message>"
jj new
```

The skill must explicitly warn that `jj` automatically snapshots working-copy changes during most commands. Jujutsu docs state that the working copy is automatically committed when changed and that added files are implicitly tracked by default unless ignored or configured otherwise. ([JJ VCS Docs][2])

---

### FR-003: No Git staging-area dependency

The skill must prohibit agent workflows that rely on Git’s staging area while using `jj`.

Bad default:

```bash
git add .
git commit -m "..."
```

Preferred default:

```bash
jj diff
jj describe -m "..."
jj split
jj squash
jj commit -m "..."
```

Jujutsu’s Git compatibility docs state that Git’s staging area is ignored by `jj`, and the README says Jujutsu has no explicit index/staging area. ([JJ VCS Docs][1])

---

### FR-004: Patch splitting

The skill must instruct agents to split unrelated edits before final handoff.

Required behavior:

* Detect mixed changes using `jj diff --stat` or `jj diff`.
* If unrelated concerns exist, use `jj split` where interactive tools are available.
* If `jj split` is unavailable or unsuitable in a non-interactive environment, document the mixed-change risk and recommend manual follow-up.
* Do not claim the result is cleanly split unless verified.

Acceptance example:

```text
The change was split into:
1. test coverage for invalid input
2. implementation fix
3. documentation update
```

---

### FR-005: Operation-log recovery

The skill must define recovery-first behavior.

When a command produces unexpected repository state:

```bash
jj op log
jj status
jj log --limit 20
```

Allowed recovery commands:

```bash
jj undo
jj op restore <operation>
jj op revert <operation>
```

The skill must require the agent to explain recovery actions in the final response if used. Jujutsu docs state that the operation log records repository-modifying operations and supports `jj undo`, `jj op revert`, and `jj op restore`. ([JJ VCS Docs][3])

---

### FR-006: GitHub/GitLab handoff

The skill must support two handoff modes.

#### Mode A: Generated bookmark/change push

Use when the team accepts generated names:

```bash
jj git push --change @-
```

#### Mode B: Named bookmark/branch

Use when PR naming conventions matter:

```bash
jj bookmark create <branch-name> -r @-
jj bookmark track <branch-name>
jj git push
```

Jujutsu’s GitHub/GitLab guide documents both generated bookmark and named bookmark workflows, including pushing with `jj git push --change @-` and bookmark-based pushing. ([JJ VCS Docs][4])

---

### FR-007: Updating from remote

The skill must not use `git pull` as the default in a `jj` workflow.

Preferred update sequence:

```bash
jj git fetch
jj rebase -o main
```

or project-specific default branch:

```bash
jj git fetch
jj rebase -o <default-branch>
```

The Jujutsu GitHub/GitLab guide says there is not currently a direct equivalent of `git pull`; it recommends fetch plus rebase as a two-step update flow. ([JJ VCS Docs][4])

---

### FR-008: Review comment handling

The skill must support two explicit review-update strategies.

#### Strategy A: Additive commits

Use when the project wants review comments addressed as follow-up commits.

```bash
jj new <bookmark>
# edit
jj diff
jj commit -m "address review comments"
jj bookmark move <bookmark> --to @-
jj git push
```

#### Strategy B: Clean history rewrite

Use only when the project prefers clean commits and force-push is allowed.

```bash
jj new <bookmark>-
# edit
jj diff
jj squash
jj git push --bookmark <bookmark>
```

The Jujutsu docs describe both review-comment strategies: adding new commits and rewriting commits, noting that some projects prefer one over the other. ([JJ VCS Docs][4])

---

### FR-009: Final verification gate

Before final response, the skill must require the agent to collect:

```bash
jj status
jj log --limit 10
jj diff --stat
git status --short --branch
git log --oneline -n 5
```

If tests/lints were run, include exact commands and output summaries. If they were not run, state that directly.

The skill must prohibit claims like:

```text
tested
verified
working
ready to merge
```

unless command output was actually observed.

---

### FR-010: Composition with existing Git rules

The skill must defer to existing repository governance:

* Branch protection.
* PR templates.
* CODEOWNERS.
* Conventional Commits.
* Signed commits.
* DCO.
* CI gates.
* Release process.
* “No direct push to main” rules.
* Project-specific merge strategy.

`jujutsu-workflow` must not replace Git governance. It should compose with a Git workflow skill or repository rules when present.

---

## 10. Safety requirements

### SR-001: No protected-branch mutation

The skill must forbid:

```bash
jj git push --bookmark main
git push origin main
```

unless explicitly requested and permitted by project policy.

### SR-002: No unapproved public history rewrite

The skill must treat these as high-risk:

```bash
jj git push --bookmark <public-branch>
git push --force
git push --force-with-lease
```

Allowed only when:

* The branch is a PR/topic branch.
* The project permits history rewriting.
* The user requested or accepted that strategy.
* Final output clearly says a rewritten branch was pushed or prepared.

### SR-003: No hidden mixed VCS mutations

In colocated workspaces:

* Use `jj` for mutations.
* Use Git mostly for read-only verification.
* Avoid mutating Git commands such as `git rebase`, `git reset`, `git checkout`, `git switch`, `git merge`, unless deliberately leaving `jj` workflow.

Jujutsu docs warn that interleaving mutating `jj` and Git commands can cause confusion, and that Git’s staging area, rebase states, and some Git-specific states are not understood by Jujutsu. ([JJ VCS Docs][1])

### SR-004: Conflict transparency

If conflicts exist:

* Do not hide them.
* Do not claim completion.
* Show affected files.
* Prefer `jj status`, `jj diff`, and `jj resolve` or manual conflict resolution.
* Verify Git-visible state afterward.

Jujutsu represents conflicts in the working copy with conflict markers and can preserve conflict state; unresolved conflicts need explicit handling before normal PR handoff. ([JJ VCS Docs][2])

---

## 11. Required skill behavior

### Trigger conditions

The skill should trigger when the user asks about:

* `jj`
* Jujutsu
* coding-agent version control
* patch stacks
* agent-safe Git workflows
* using `jj` with GitHub/GitLab
* recovering agent edits
* splitting agent-generated changes
* PR handoff from `jj`
* replacing Git commands with `jj` for agent workflows

### Non-trigger conditions

Do not trigger for:

* Generic Git use with no `jj` mention.
* Release management.
* GitHub Actions troubleshooting.
* Branch protection setup.
* Non-agent developer training, unless `jj` is explicitly involved.

---

## 12. Proposed skill package structure

```text
jujutsu-workflow/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── agent-safe-jj-workflows.md
│   ├── git-interop.md
│   ├── recovery-playbook.md
│   ├── pr-handoff.md
│   └── command-map.md
└── scripts/
    ├── detect_jj_state.sh
    └── verify_handoff.sh
```

### `SKILL.md`

Purpose:

* Main invocation instructions.
* Safety invariants.
* Workflow selection.
* Pointers to references.

### `references/agent-safe-jj-workflows.md`

Should cover:

* Default edit loop.
* Patch stack creation.
* Splitting changes.
* Review comments.
* Conventional commit handling.

### `references/git-interop.md`

Should cover:

* Colocated vs non-colocated repos.
* Read-only Git verification.
* GitHub/GitLab PR workflow.
* Bookmarks vs branches.
* Known traps.

### `references/recovery-playbook.md`

Should cover:

* `jj op log`
* `jj undo`
* `jj op restore`
* `jj op revert`
* stale working copy recovery
* conflict recovery

### `references/pr-handoff.md`

Should cover:

* Generated bookmark push.
* Named bookmark push.
* Final verification gate.
* PR summary format.
* Review-comment update strategies.

### `references/command-map.md`

Should cover:

| Intent         | Git habit                   | `jj`-preferred command                          |
| -------------- | --------------------------- | ----------------------------------------------- |
| status         | `git status`                | `jj status` plus Git verification               |
| diff           | `git diff`                  | `jj diff`                                       |
| commit         | `git add && git commit`     | `jj describe`, `jj commit`, `jj new`            |
| branch         | `git branch`                | `jj bookmark` where remote visibility is needed |
| pull           | `git pull`                  | `jj git fetch` + `jj rebase`                    |
| undo           | `git reset`, reflog         | `jj undo`, `jj op restore`                      |
| push PR branch | `git push -u origin branch` | `jj git push --change` or bookmark push         |

### `scripts/detect_jj_state.sh`

Purpose:

* Print repo root.
* Detect Git root.
* Detect `jj` root.
* Detect colocated Git root.
* Print current `jj status`.
* Print current Git branch/status.
* Exit nonzero only for real errors, not missing tools.

### `scripts/verify_handoff.sh`

Purpose:

* Run the final verification gate.
* Produce machine-readable and human-readable output.
* Fail if:

  * unresolved conflicts exist,
  * Git status is incoherent,
  * protected branch appears to be target,
  * no branch/bookmark is available for PR handoff.

---

## 13. Draft `SKILL.md` frontmatter

```yaml
---
name: jujutsu-workflow
description: agent-safe version-control workflows using jujutsu (`jj`) with git-compatible repositories. use when working with coding agents, jujutsu, jj commands, patch stacks, speculative edits, operation-log recovery, git/github/gitlab handoff, review-comment updates, or replacing fragile git mutation workflows with safer jj workflows while preserving git as the canonical remote/pr/ci interface.
---
```

---

## 14. Draft `SKILL.md` core instructions

````markdown
# Jujutsu Workflow

Use `jj` as the local agent change-management layer and Git as the external collaboration layer.

## Core rules

1. Detect repo state before making VCS mutations.
2. Prefer `jj` for local mutations.
3. Use Git mostly for read-only verification.
4. Never push directly to protected/default branches.
5. Never rewrite public history unless the user/project explicitly allows it.
6. Use operation-log recovery before destructive Git recovery.
7. Split unrelated changes before handoff when possible.
8. Always finish with both `jj` and Git-visible verification.

## Default workflow

Run:

```bash
jj status
jj log --limit 10
````

Edit files, then run:

```bash
jj diff
jj status
```

Describe or commit changes using project commit conventions.

## Final verification

Before claiming completion, run:

```bash
jj status
jj log --limit 10
jj diff --stat
git status --short --branch
git log --oneline -n 5
```

Report exact commands run. If checks were skipped or unavailable, say so.

````

---

## 15. UX/output requirements

### Final response format for coding tasks

The skill should make agents report:

```markdown
## Result

<what changed>

## Version-control state

- jj status: <summary>
- Git status: <summary>
- Branch/bookmark: <name or none>
- Push/PR state: <not pushed / pushed / ready>

## Validation

Commands run:
- `<command>` → <result>

Not run:
- `<command>` → <reason>

## Notes

<any conflict, recovery, split, or force-push detail>
````

---

## 16. Acceptance criteria

### MVP acceptance

The skill is acceptable when it can reliably guide an agent through:

1. Detecting Git/`jj` repository state.
2. Making a local change using `jj`.
3. Describing or committing the change.
4. Splitting or at least identifying mixed changes.
5. Recovering from a bad operation using `jj op log` / `jj undo`.
6. Preparing a GitHub/GitLab PR handoff.
7. Producing a final verification block with both `jj` and Git status.

### Quality bar

The skill must prevent these classes of mistakes:

* Direct push to `main`.
* Silent force-push.
* Reliance on Git staging area in a `jj` workflow.
* Claiming tests passed without output.
* Hiding unresolved conflicts.
* Leaving human reviewers with a `jj`-only state they cannot inspect through Git.

---

## 17. Metrics

### Success metrics

| Metric                                                               | Target |
| -------------------------------------------------------------------- | -----: |
| Agent tasks ending with explicit VCS verification                    |   >95% |
| Mixed unrelated changes caught before handoff                        |   >80% |
| Recovery attempts using `jj op log` before Git reset/rebase fallback |   >90% |
| Final responses with exact validation commands                       |   >95% |
| Direct protected-branch push attempts                                |      0 |

### Failure indicators

* Human has to ask “what branch is this on?”
* PR contains unrelated edits.
* Agent says “done” but Git status is dirty/incoherent.
* Agent used Git staging commands that `jj` ignored.
* Agent force-pushed without explicit policy.
* Agent cannot explain how to undo its last repository operation.

---

## 18. Risks and mitigations

| Risk                                         | Severity | Mitigation                                                               |
| -------------------------------------------- | -------: | ------------------------------------------------------------------------ |
| Team does not know `jj`                      |     High | Keep Git as final interface; require Git verification                    |
| Agent creates confusing bookmark state       |   Medium | Prefer named bookmark only during handoff                                |
| `jj` command behavior changes                |   Medium | Keep command references short; point to official docs; avoid overfitting |
| Non-colocated repos confuse GitHub CLI/tools |   Medium | Detect repo mode; use `jj git root` where needed                         |
| Force-push misuse                            |     High | Require explicit project permission and final disclosure                 |
| Conflicted commits appear weird to Git tools |     High | Do not hand off unresolved conflict state                                |
| Existing Git hooks are bypassed              |     High | Require project hook/test/lint detection or explicit note                |

---

## 19. MVP scope

### Include in MVP

* Repo detection.
* Colocated Git/`jj` workflow.
* Local edit loop.
* Operation-log recovery.
* PR handoff.
* Review-comment update strategies.
* Final verification gate.
* Basic command map.

### Defer to v2

* Gerrit-specific workflows.
* Multi-workspace orchestration.
* Advanced revset recipes.
* CI-aware branch naming.
* Automatic PR creation.
* Signed commit enforcement.
* Git LFS/submodule edge-case handling.
* IDE-specific behavior.
* Enterprise policy integration.

---

## 20. Strong product recommendation

Build this as a **small, strict skill**, not a large `jj` encyclopedia.

The MVP should be opinionated:

```text
Use jj for local mutation.
Use Git for external truth.
Verify both.
Never hide risky state.
```

That is enough to create real value for coding agents. A bloated skill will make agents worse by giving them too many clever options.

[1]: https://docs.jj-vcs.dev/latest/git-compatibility/ "Git compatibility - Jujutsu docs"
[2]: https://docs.jj-vcs.dev/latest/working-copy/ "Working copy - Jujutsu docs"
[3]: https://docs.jj-vcs.dev/latest/operation-log/ "Operation log - Jujutsu docs"
[4]: https://docs.jj-vcs.dev/latest/github/ "Working with GitHub - Jujutsu docs"
