# Bootstrap Checklist (Guided Steps)

Last reviewed: 2026-08-11

A phase-by-phase companion to [`bootstrap-project.md`](bootstrap-project.md). That prompt is the
narrative; this is the walk-through you tick off. Work top to bottom, but **interview before
scaffolding** — do not create many files until the user has answered Phase 0. Each step links to
the deep doc that owns the detail; do not duplicate it here.

Phases have stable IDs (`P0`…`P8`, `PS`). Use the IDs everywhere — state file, handoffs,
commit messages — so "Phase 4" never becomes ambiguous.

## How to run this without losing your place

1. **P0 first:** copy [`templates/bootstrap-state.md`](../templates/bootstrap-state.md) to
   `.context/bootstrap-state.md`.
2. **Update it as each phase completes**, not at the end. This is what survives a context
   reset, an interrupted session, or a handoff to a different agent.
3. **Never skip silently.** Write `skipped — <reason>` in the state file and tell the user.
4. **Verify with evidence, not memory:** `bash scripts/check-bootstrap.sh`. It inspects the
   repo. If it disagrees with the state file, the repo is right.
5. **Phases with a real branch have a topic card** in [`bootstrap/`](bootstrap/) — questions,
   answer→action table, artifacts, done-criteria. Work the card; the linked policy remains the
   source of truth for details.

## P0 — Discovery (ask, then summarize)

- [ ] Copy the state file (above) before anything else.
- [ ] Ask what the repo is for, who uses it, platforms/runtimes/languages, and success criteria.
      Full question list: [`bootstrap-project.md`](bootstrap-project.md) §1.
- [ ] Ask the **data question explicitly** — work
      [`bootstrap/card-data-classification.md`](bootstrap/card-data-classification.md): what data
      can enter this repo (code, fixtures, screenshots, logs, exports)? Will it hold real PII, PHI,
      clinical/FHIR/HL7/DICOM, financial, or other regulated/customer data — or is that prohibited
      with synthetic-only fixtures?
- [ ] Ask whether subagents/parallel workers should be used for research, planning, or review.
- [ ] Summarize answers back; list assumptions and open questions.
- [ ] **If the data answer is yes/maybe/regulated → run PS** before writing code or wiring tools.

## P1 — Profile

- [ ] Run [`project-init-profile.md`](project-init-profile.md); write `.context/project-profile.md`.
- [ ] Set the **data classification** and hygiene tier (`standard` / `sensitive` / `regulated`) —
      when unknown, use the more protective tier.
- [ ] Use the profile's "Relevant inventory" to decide which inventory files to load (not all of them).

## P2 — Protect the template remote

- [ ] `git remote -v`; repoint `origin` away from this template before any push
      ([`bootstrap-project.md`](bootstrap-project.md) §2). Only push after the user confirms the remote.

## P3 — Repo hygiene & GitHub settings

- [ ] Choose the tier and controls in [`policies/github-repository-hygiene.md`](../policies/github-repository-hygiene.md):
      default-branch ruleset, required reviews/checks, secret scanning + push protection, Dependabot,
      CodeQL, `CODEOWNERS`, `SECURITY.md`, least-privilege Apps/secrets/workflow permissions.
- [ ] Use the required-check names decided in P4 so rulesets match CI exactly. A ruleset requiring
      a check no workflow produces blocks every PR — record the names in the state file.

## P4 — Hooks & CI

Card: [`bootstrap/card-ci-tier.md`](bootstrap/card-ci-tier.md)

- [ ] Copy [`hooks/.pre-commit-config.yaml`](../hooks/.pre-commit-config.yaml) to the root; enable the
      baseline (gitleaks, private-key, file-size, doc-freshness, lint). `pre-commit install`.
- [ ] Pick CI workflows from [`ci/README.md`](../ci/README.md); estimate Actions cost first
      ([`policies/github-actions-usage.md`](../policies/github-actions-usage.md)).
- [ ] Decide what belongs in pre-commit vs CI vs agent-side ([`hooks/README.md`](../hooks/README.md)).
- [ ] Write the required-check names into the state file for P3.

## PS — Sensitive / private / PHI / PII data (conditional)

Card: [`bootstrap/card-data-classification.md`](bootstrap/card-data-classification.md)

Run only when P0 flags real or possible PII/PHI/regulated/customer data. Read
[`prompts/strict-phi-agent-guidance.md`](strict-phi-agent-guidance.md),
[`prompts/sensitive-data-leak-prevention.md`](sensitive-data-leak-prevention.md), and
[`inventory/medical-data-security.md`](../inventory/medical-data-security.md) first. An **agent must
not** author approvals or weaken any gate — a named human owns those.

- [ ] **Keep data out of history:** have a human create `.phi-security-approvals.json`; enable the
      strict `check-sensitive-data` and `check-commit-message-sensitive-data` hooks + required CI
      ([`inventory/medical-data-security.md`](../inventory/medical-data-security.md)).
- [ ] **Protect the ignore rules:** `cp hooks/gitignore-protected.example .gitignore-protected`;
      list the data/export/log dirs that must stay ignored; enable `check-gitignore-protected`.
- [ ] **Forbid tracking data dirs:** `cp hooks/forbidden-paths.example .forbidden-paths`; enable
      `check-forbidden-paths`; add matching `.gitignore` rules and a push ruleset backstop.
- [ ] **Heavy scanners? Add a scan contract:** if Presidio (text/image), OCR, dicom-phi-scan,
      phi-scan, HoundDog (local), or a local SonarQube CE scan applies,
      `cp hooks/scan-contract.json.example .scan-contract.json`, keep the scanners you adopt, run
      each once, `record` it, and enable `check-scan-contract`. See
      [`policies/sensitive-data-scan-gates.md`](../policies/sensitive-data-scan-gates.md).
- [ ] **Runtime leak surface:** gitignore artifact dirs, ship a one-command `make clean-sensitive`,
      add log-scanning tests, review telemetry/error-tracker egress
      ([`policies/sensitive-data-runtime-leaks.md`](../policies/sensitive-data-runtime-leaks.md)).
- [ ] **Document, image/OCR ingestion?** Inventory local OCR / local vision options to catch
      burned-in text before ingestion ([`inventory/medical-data-security.md`](../inventory/medical-data-security.md)).
- [ ] **Agent tooling must stay local** — no cloud indexing of regulated code or data. Carry this
      constraint into P5.5.
- [ ] **Schedule** a periodic repo-wide/full-history PII audit (e.g. Octopii, local only) via
      [`maintenance-loop.md`](maintenance-loop.md); record the cadence in the profile.
- [ ] `CODEOWNERS`-protect every control above (approvals, hooks, workflows, configs, fixtures).

## P4.5 — Environment

Card: [`bootstrap/card-environment.md`](bootstrap/card-environment.md)

- [ ] Recommend `direnv` (+ `pyenv`/`.python-version` and a venv layout for Python)
      ([`bootstrap-project.md`](bootstrap-project.md) §6). Commit `.envrc.example`; gitignore `.envrc`.

## P5 — Skills, subagents & references

Card: [`bootstrap/card-orchestration.md`](bootstrap/card-orchestration.md)

- [ ] Pick a minimal set from [`inventory/catalog-skills-agents.md`](../inventory/catalog-skills-agents.md);
      record install-now / evaluate-later / skip-for-now and why in the profile.
- [ ] Choose an orchestration tier deliberately ([`inventory/harness-engineering.md`](../inventory/harness-engineering.md)) —
      do not default to Symphony for IDE work.
- [ ] Note other repos/sources to mine in [`inventory/source-repos-to-review.md`](../inventory/source-repos-to-review.md).

## P5.5 — Agent tooling & context efficiency

Card: [`bootstrap/card-agent-tooling.md`](bootstrap/card-agent-tooling.md)

- [ ] Work the card. **The default is "none for now"** — a fresh scaffold has no recurring
      information gap. Recommend zero to two tools from
      [`inventory/agent-tooling-efficiency.md`](../inventory/agent-tooling-efficiency.md), never a suite.
- [ ] Paste the contract from [`policies/agent-tooling-contract.md`](../policies/agent-tooling-contract.md)
      into the project's `AGENTS.md`; add `.agent-state/` to `.gitignore`.
- [ ] Record adopted **and rejected** tools (with reasons) in the profile's Agent tooling section.
- [ ] Adopt [`templates/handoff.md`](../templates/handoff.md) — this one applies to every project.

## P6 — Agent harness & knowledge

- [ ] Write a thin `AGENTS.md` (small entrypoint → deep docs) and per-tool pointer files.
- [ ] If >~50 source files or type is `research`/`rag-knowledge`/`agentic`, set up a code map
      ([`inventory/knowledge-graph-code-mapping.md`](../inventory/knowledge-graph-code-mapping.md)); record it in the profile.

## P7 — Docs & gardening

- [ ] Set up changelogs ([`policies/changelog-conventions.md`](../policies/changelog-conventions.md)),
      doc-freshness markers ([`policies/doc-freshness.md`](../policies/doc-freshness.md)), plans lifecycle
      ([`policies/plans-and-todos.md`](../policies/plans-and-todos.md)), and templates from [`templates/`](../templates/).
- [ ] Schedule the recurring [`maintenance-loop.md`](maintenance-loop.md) (weekly/monthly).

## P8 — Scaffold, validate, hand off

- [ ] Produce the scaffold plan ([`bootstrap-project.md`](bootstrap-project.md) §5) and get approval before broad changes.
- [ ] Build the minimal scaffold; validate with real run/test/lint commands.
- [ ] Run `bash scripts/check-bootstrap.sh` and resolve or explain every finding.
- [ ] Write `.context/handoff.md` from [`templates/handoff.md`](../templates/handoff.md) — do not
      leave the handoff only in chat, where it evaporates.
- [ ] Hand off ([`bootstrap-project.md`](bootstrap-project.md) §8): what was created, how to run/test,
      remote, checks passed, open decisions, next 3 steps. Point future sessions at
      [`new-agent-session.md`](new-agent-session.md).
- [ ] Fold anything durable from the state file into the profile; let cleanup remove the state file.
