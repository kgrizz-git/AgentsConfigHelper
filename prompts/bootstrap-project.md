# Bootstrap A New Project From This Template

You are an AI coding agent working inside a newly cloned project seed repository. Your job is to turn this minimal template into a well-structured starting point for the specific project the user wants to build.

Do not assume the project type. Start by interviewing the user, then propose a plan before creating a large scaffold.

Work the phase-by-phase [`bootstrap-checklist.md`](bootstrap-checklist.md) alongside this prompt —
it is the tick-list version of these steps, including the conditional sensitive-data branch (PS).

**Before anything else:** copy [`templates/bootstrap-state.md`](../templates/bootstrap-state.md) to
`.context/bootstrap-state.md` and update it as each phase completes. Bootstrap routinely spans
several sessions and at least one context reset; that file is the only thing that remembers where
you stopped. Phases with a real decision branch have a short topic card in
[`bootstrap/`](bootstrap/) — questions, answer→action table, artifacts, done-criteria.

## 1. Start With Discovery

Ask concise questions before choosing a stack or writing many files:

- What will this repo be for?
- Who will use it?
- What are the expected platforms, runtimes, languages, deployment targets, and integrations?
- Is this a library, app, website, CLI, service, research project, automation workflow, data project, design prototype, or something else?
- What matters most: speed, correctness, user experience, security, scientific rigor, maintainability, cost, portability, or learning?
- What data can enter this repository (including fixtures, screenshots, logs, and workflow artifacts)? Is real PII, PHI, regulated, or customer data prohibited, or is there an approved handling design?
- Are there existing repos, docs, style guides, prompts, agent skills, product specs, designs, or examples you should inspect?
- Should you use subagents or parallel workers for research, planning, review, or implementation?

Summarize the answers back to the user. List assumptions and open questions.

## 1.5. Capture The Project Profile

Run `prompts/project-init-profile.md` now. It asks follow-up questions (project type,
orchestration tier, domain, constraints) and writes `.context/project-profile.md`.

That file is the single fast-load summary every future agent session reads. Without it,
returning agents rediscover the project type from scratch on every session.

Use the profile's **Relevant inventory** section to decide which inventory files to read
in step 3 — do not load all 18 files by default.

**Medical or regulated data trigger:** if the user indicates PII, PHI, clinical/FHIR/HL7/DICOM,
or similarly regulated data, read
[`prompts/sensitive-data-leak-prevention.md`](sensitive-data-leak-prevention.md) before creating
fixtures or configuring external tools. Have a human own any approval inventory or gate
configuration, wire the chosen local hooks and required CI jobs, and protect those controls with
CODEOWNERS before the first relevant commit. Do not let an agent add approval entries. Beyond keeping data out of
the repo, design the code so it does not leak PII/PHI/secrets/usernames/IPs/hostnames/paths into
logs, temp files, test/CI output, caches, telemetry, or third-party/AI calls (in production *or*
development): sanitize at the boundary, gitignore and document any sensitive-capable sinks, and
ship a one-command way to clear local logs/caches/temp artifacts — see
[`prompts/sensitive-data-leak-prevention.md`](sensitive-data-leak-prevention.md) for the
how, and wire the tiered checks in
[`policies/sensitive-data-runtime-leaks.md`](../policies/sensitive-data-runtime-leaks.md)
(gitignore artifact dirs, `make clean-sensitive`, log-scanning tests, HoundDog data-flow scan).
Also wire the structural gates in
[`policies/sensitive-data-scan-gates.md`](../policies/sensitive-data-scan-gates.md): protect the
required `.gitignore` rules (`check_gitignore_protected.py`), forbid tracking data/export dirs
(`check_forbidden_paths.py`), and — when heavy scanners like Presidio (text/image), local OCR,
dicom-phi-scan, phi-scan, HoundDog local, or a local SonarQube CE scan apply — add a scan
contract/ledger (`check_scan_contract.py`) that blocks commits until each chosen scanner has been
re-run against the current tree. If the project ingests,
processes, or exports scanned documents, PDFs, images, or DICOM files, inventory options for
local OCR or local multimodal vision models to detect burned-in text/PII before data ingestion.
A full-history PII/PHI audit is not meaningful on a freshly bootstrapped repo—instead, record it
as a recurring control: set up a local-first repo-wide audit (for example
[Octopii](https://github.com/redhuntlabs/Octopii)) to run periodically via
[`prompts/maintenance-loop.md`](maintenance-loop.md), and note the schedule in the project profile.

## 2. Protect The Template Remote

Before the first project commit or push:

1. Inspect `git remote -v`.
2. Explain which remote points to this template, if any.
3. Tell the user this cloned project should push to a new remote, not back to the template repo.
4. Help the user create or identify a new remote repository for the actual project.
5. Update the remote, for example:

```sh
git remote set-url origin <new-project-remote-url>
```

Or, if preserving the template remote is useful:

```sh
git remote rename origin template
git remote add origin <new-project-remote-url>
```

1. Verify again with `git remote -v`.
2. Only push after the user confirms the new remote is correct.

## 3. Read The Template Inventories

Read [inventory/README.md](../inventory/README.md), then open **only** the topic files
listed in the project profile's "Relevant inventory" section. Choose tools and skills
deliberately. Do not load everything.

For each relevant area, produce a short adoption list:

- **Install/configure now** — tools, hooks, skills, services, or libraries needed for
  the first useful scaffold.
- **Evaluate later** — promising options that depend on future scale, data, users,
  deployment targets, or workflow maturity.
- **Skip for now** — options that are interesting but not justified by this project.

Record the choices and rationale in the scaffold plan or `.context/project-profile.md`
so future agents know why tools were or were not adopted.

Ask the user if there are other repos or sources to inspect for useful skills, prompts,
conventions, build systems, or design patterns — record them in
[inventory/source-repos-to-review.md](../inventory/source-repos-to-review.md).

**Code map:** if the project has more than ~50 source files, or the project type is
`research`, `rag-knowledge`, or `agentic`, set up a code map early — before writing
significant new code. Options: `aider --show-repo-map` (zero setup), sift-kg (deeper
graph), tree-sitter index. See [inventory/knowledge-graph-code-mapping.md](../inventory/knowledge-graph-code-mapping.md).
Record the chosen tool in the project profile under "Knowledge index."

## 4. Apply Agent-First Engineering Principles

Read `inventory/harness-engineering.md` for the full reference list. The actionable
principles for this project:

- Keep repository knowledge legible to agents — good AGENTS.md, indexed docs, code map.
- Small entrypoint → deep docs. Do not make AGENTS.md a monolith.
- Make local run/test/validate cycles fast and agent-accessible. Agents use feedback loops.
- Encode project taste as checks (lint, tests, policy scripts), not only prose.
- Use short-lived plans and versioned ADRs for decisions future agents must see.
- Use subagents for bounded parallel work, then merge into one coherent plan.
- Prefer reversible actions; design checkpoints before irreversible ones.

**Orchestration:** the project profile captures the orchestration tier. Match the choice
to actual complexity — see the decision table in `inventory/harness-engineering.md`.
Do not default to Symphony for an IDE-based workflow; hub-and-spoke costs far less.
Symphony is right for production multi-agent APIs that need structured routing and
observability at scale.

## 5. Make A Scaffold Plan Before Writing The Scaffold

Produce a plan that includes:

- Project purpose and target users.
- Recommended stack and alternatives considered.
- Tool/skill adoption list: install now, evaluate later, skip for now.
- Proposed file tree.
- Development environment setup.
- Local run commands.
- Testing strategy.
- Formatting, linting, type checking, and security checks.
- Documentation structure.
- CI and dependency update strategy.
- GitHub hygiene: default-branch ruleset/branch protection, required PR reviews and checks,
  ownership of security alerts, hooks, and a data/path-exposure gate appropriate to the
  project classification. Read [`policies/github-repository-hygiene.md`](../policies/github-repository-hygiene.md).
- Release and versioning approach using SemVer when appropriate.
- Maintenance loop for improving prompts, skills, tools, inventories, docs, and architecture over time.

Ask for approval before making broad changes.

## 5.5. Agent Tooling And Context Efficiency

Work [`bootstrap/card-agent-tooling.md`](bootstrap/card-agent-tooling.md) after the
orchestration tier is set, because tools attach to roles.

**The default is to install nothing.** Native search, the language server, the test suite, and
source documentation are the baseline any candidate must beat, and a fresh scaffold has no
recurring information gap to close. Recommend zero to two tools from
[`inventory/agent-tooling-efficiency.md`](../inventory/agent-tooling-efficiency.md), never a suite:
overlapping indexes and MCP schemas can cost more context than the tools save.

Regardless of what is installed:

- Paste the contract from [`policies/agent-tooling-contract.md`](../policies/agent-tooling-contract.md)
  into the project's `AGENTS.md`.
- Add `.agent-state/` to `.gitignore`; document how to rebuild any index.
- Adopt [`templates/handoff.md`](../templates/handoff.md) — a durable handoff is the one practice
  that pays off on every project, and it does not require installing anything.
- Record adopted **and rejected** tools with reasons in the profile. A recorded rejection is what
  stops the next agent from re-litigating it.

Decide on evidence, not on stars or vendor token-savings claims — headline reduction figures
usually compare targeted retrieval against a whole-repository baseline and do not transfer.

## 6. Environment Guidance

**For every project, recommend `direnv`** — it auto-loads `.envrc` on directory entry,
keeping secrets, env vars, and PATH changes project-scoped instead of global. One-time
setup (`brew install direnv` + shell hook), then `direnv allow` per project. Commit a
`.envrc.example`; gitignore `.envrc` if it holds secrets.

If the project uses Python, also recommend:

- `pyenv` for Python version management.
- A local virtual environment (use `layout python3` or `layout uv` in `.envrc` to
  auto-activate on directory entry — no manual `source` needed).
- A recorded Python version such as `.python-version`.
- A dependency manager appropriate to the project.
- Formatting, linting, type checking, tests, and security audit tools.

For every ecosystem, prefer boring, well-supported tools unless the project requirements justify something newer or more specialized.

## 7. Implementation Rules

- Keep the first scaffold minimal but complete enough to run, test, and extend.
- Add only files that support the chosen project.
- Avoid copying every inventory item into the project.
- Document why major choices were made.
- Use SemVer for the project once releases matter.
- Add future improvement hooks: TODOs, docs indexes, ADRs, or prompt templates only where they will actually help.
- Validate the scaffold with real commands before declaring it done.

## 8. Final Handoff

First run `bash scripts/check-bootstrap.sh` and resolve or explain every finding. It verifies
phases by repo evidence rather than by what the session believes it did.

Then **write** `.context/handoff.md` from [`templates/handoff.md`](../templates/handoff.md).
Do not leave the handoff only in chat, where it evaporates the moment the session ends.

Report:

- What was created.
- How to run and test it.
- What remote is configured.
- What checks passed.
- What decisions are still open.
- The next 3 practical steps.

Tell the user:

- Future agent sessions should start with `prompts/new-agent-session.md`.
- Periodic repo health checks use `prompts/maintenance-loop.md` (weekly or monthly).
- The project profile lives at `.context/project-profile.md`; update it when the stack
  or orchestration tier changes significantly.
