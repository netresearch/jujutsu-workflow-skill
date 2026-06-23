# jj Agent Workflow

## What this skill solves

Coding agents are unreliable Git operators: they fold unrelated edits into one commit, lose work to `git reset` / `checkout` / `stash` / bad rebases, leave unclear branch state, and claim "done" without showing version-control status. This skill teaches agents to use **Jujutsu (`jj`)** as the local change-management layer while keeping **Git** as the canonical collaboration, CI, PR, and audit interface.

- Safer, reversible edits via the `jj` operation log and undo instead of destructive Git recovery.
- Cleaner patches — small, reviewable changes with unrelated edits split before handoff.
- A Git-visible PR handoff that humans and CI can inspect with ordinary Git tools.

## Why jj beats pure Git for agentic coding (proven)

For speculative, iterative, multi-step agent work, jj is **superior to pure Git** — and this skill does not just assert it, it **proves** it with a runnable eval suite (`tests/superiority_evals.sh`, also run in CI) demonstrating four concrete wins:

- **Reversible discards** — `jj op restore` recovers abandoned work; git's discarded *uncommitted* edits are unrecoverable.
- **Conflicts don't block** — a conflicting `jj rebase` completes and records the conflict (and `jj undo` reverses it); `git rebase` halts mid-operation.
- **Non-interactive history surgery** — `jj split <path> -m` carves a commit in two without an editor; git needs interactive `rebase -i`.
- **Whole-repo time travel** — `jj op restore` rewinds many operations (commits + bookmarks) in one command; git has no single-command equivalent.

This skill **claims** the advantage here, **proves** it in [the evals](tests/superiority_evals.sh), and **enforces** it in [`SKILL.md`](skills/jj-agent-workflow/SKILL.md) (jj-first whenever a `.jj/` repo is present). The full, evidence-backed thesis — including an honest **"when NOT to use jj"** — is in [why-jj-for-agents.md](skills/jj-agent-workflow/references/why-jj-for-agents.md).

## Use when

- A coding agent works in a repository where `jj` is installed or allowed.
- You use `jj` / Jujutsu, patch stacks, or speculative iterative edits.
- You need to recover agent edits with `jj op log` / `jj undo` / `jj op restore`.
- You split agent-generated changes, hand off a PR from `jj`, or update a PR after review comments.
- You want to replace fragile `git reset` / `checkout` / `stash` / `rebase` recovery with reversible `jj` operations.

## Expected outputs

- A local change described or committed with `jj`, with unrelated edits split.
- A Git-visible branch/bookmark pushed for PR creation, never targeting a protected branch.
- A final verification block reporting both `jj` and Git state plus any tests or lints that were run.

## Context requirements

- A Git-backed repository (colocated `jj`/Git preferred), with `jj` installed locally.
- Project governance is respected: branch protection, CODEOWNERS, commit conventions, signed commits, CI gates.
- External access: none beyond the Git remote (GitHub/GitLab) the project already uses.

## Example prompts

```
"Use jj to make this change and prepare a clean PR branch without touching main."
"I made a mess with jj — undo my last operation and show me how to recover."
"Split these mixed edits into separate jj commits before we open the PR."
```

## Related skills

- [`git-workflow-skill`](https://github.com/netresearch/git-workflow-skill) — the canonical Git/PR/merge workflow this skill defers to for the remote contract.
- [`github-project-skill`](https://github.com/netresearch/github-project-skill) — branch protection, rulesets, and PR merge gates.

## Installation

### Marketplace (recommended)

Add the [Netresearch marketplace](https://github.com/netresearch/claude-code-marketplace) once, then browse and install skills:

```bash
/plugin marketplace add netresearch/claude-code-marketplace
```

### npx ([skills.sh](https://skills.sh))

Install with any [Agent Skills](https://agentskills.io)-compatible agent:

```bash
npx skills add https://github.com/netresearch/jj-agent-workflow-skill --skill jj-agent-workflow
```

### Download release

Download the [latest release](https://github.com/netresearch/jj-agent-workflow-skill/releases/latest) and extract to your agent's skills directory.

### Git clone

```bash
git clone https://github.com/netresearch/jj-agent-workflow-skill.git
```

### Composer (PHP projects)

```bash
composer require netresearch/jj-agent-workflow-skill
```

Requires [netresearch/composer-agent-skill-plugin](https://github.com/netresearch/composer-agent-skill-plugin).

### npm (Node projects)

```bash
npm install --save-dev \
  @netresearch/agent-skill-coordinator \
  github:netresearch/jj-agent-workflow-skill
```

Requires [@netresearch/agent-skill-coordinator](https://github.com/netresearch/node-agent-skill-coordinator), which discovers the skill in `node_modules` and registers it in `AGENTS.md` via a `postinstall` hook.

## Contributing

Contributions welcome. Open PRs for feature improvements, bug fixes, and documentation updates. The product specification lives in [`docs/PRD.md`](docs/PRD.md).

## License

Split licensing:

- **Code** (scripts, workflows, configs): [MIT](LICENSE-MIT)
- **Content** (skill definitions, documentation, references): [CC-BY-SA-4.0](LICENSE-CC-BY-SA-4.0)

---

Developed and maintained by [Netresearch DTT GmbH](https://www.netresearch.de/).

**Made with ❤️ for Open Source by [Netresearch](https://www.netresearch.de/)**
