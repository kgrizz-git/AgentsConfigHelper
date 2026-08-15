# Developer Changelog

Internal / developer-facing changes that do not belong in the public
[`CHANGELOG.md`](CHANGELOG.md). See [`policies/changelog-conventions.md`](policies/changelog-conventions.md).

## Unreleased

### Added

- **Bootstrap follow-through.** The checklist existed but nothing recorded progress, so a
  compacted or resumed session had no way to know where it stopped. Adds stable phase IDs
  (`P0`–`P8`, `PS`); `templates/bootstrap-state.md` → `.context/bootstrap-state.md` for
  per-phase status (`pending`/`in-progress`/`done`/`skipped — reason`) plus a `Next action`;
  and `scripts/check-bootstrap.sh`, which verifies phases by **repo evidence** rather than by
  claims (profile fields, remote repointed, root pre-commit config + installed hook, workflows,
  `.envrc.example`, `.env` not tracked, `.agent-state/` ignored, PS gates when the
  classification is `regulated`). Advisory by default; `--strict` exits non-zero.
  `new-agent-session.md` gained a step 1.5 that resumes an unfinished bootstrap or reads a
  pending handoff.
- **`prompts/bootstrap/` decision cards** — short scripts (ask → answer/action branch table →
  artifacts → done-when) for the five phases with a real branch: data classification, CI tier,
  environment, orchestration, agent tooling. Phases with one obvious path stay single lines in
  the checklist. The checklist previously linked only to reference policies, leaving the agent
  to invent the interview.
- **`inventory/agent-tooling-efficiency.md`** — token-efficient tooling menu distilled from the
  Notes_and_Ideas guide (Context7, Serena, code-review-graph, Graphify, TokenSave,
  chrome-devtools-mcp): role assignment, the overlap warning, CLI-vs-MCP table, adoption
  sequence, and an evidence standard that ranks local evaluation above vendor token claims.
  Default for a fresh scaffold is **install nothing**. Distilled here rather than only linked,
  so the guidance is actionable on its own; the private source is cited for agents with access.
- **`policies/agent-tooling-contract.md`** — the pastable `AGENTS.md` policy block, `.agent-state/`
  untracked, one code-intelligence tool per role, per-tool smoke test, native fallback. New
  bootstrap phase P5.5 and an "Agent tooling" section in the project profile record adopted
  **and rejected** tools, so rejections are not re-litigated.
- **`templates/handoff.md`** — cross-agent/cross-IDE handoff packet (goal, changed files,
  decisions, verified-vs-assumed, next action). Bootstrap §8 now *writes* `.context/handoff.md`
  instead of leaving the handoff in chat, where it evaporates.
- **`ci/scripts/check_doc_links.py`** — three staleness checks for a repo whose entire value is
  cross-linked guidance:
  1. *Internal links* — every relative markdown link resolves. Mechanical and offline, so it
     runs in `template-checks` as a gate (`--internal-only --strict`); `docs/**` and `scripts/**`
     were added to the workflow path filters so doc-only changes trigger it. This immediately
     found five long-standing broken links (`templates/adrs/`, `briefs/`, `plans/`, `designs/`
     in `docs/NAVIGATION.md`, and a wrong `../` depth in `.devin/skills/README.md`), all fixed.
  2. *Link liveness* — external links in `inventory/` still resolve; a GitHub redirect means the
     project was renamed or transferred. Network-dependent, so it stays out of CI.
  3. *Catalog review* — `Last reviewed` asserts the prose is accurate but cannot catch a tool
     whose project was archived while the text still reads fine. Adds an opt-in
     `Catalog reviewed through:` marker with a 120-day window, tighter than the 180-day prose
     window.

  Checks 2 and 3 are deliberately advisory: a rename or a quiet project is a prompt to
  re-evaluate an entry, not grounds to auto-delete it. Wired into `policies/doc-freshness.md`
  and the maintenance loop's inventory review.
- Structural sensitive-data gates: `hooks/scripts/check_gitignore_protected.py` (blocks
  removal of required `.gitignore` rules), `check_forbidden_paths.py` (blocks tracking
  files under never-commit paths), and `check_scan_contract.py` (a git-blob-hash ledger
  that blocks when a required heavy scanner — Presidio text/image, local OCR,
  dicom-phi-scan, phi-scan, HoundDog local, or a local SonarQube CE scan — has not been
  re-run since the files it covers changed). Each is inert until its root config exists.
  Ships `hooks/{gitignore-protected,forbidden-paths}.example` and
  `hooks/scan-contract.json.example`, `policies/sensitive-data-scan-gates.md`, commented
  `.pre-commit-config.yaml` blocks, and smoke tests. Wired into the bootstrap
  medical/regulated trigger, `strict-phi-agent-guidance.md`, `AGENTS.md`,
  `inventory/medical-data-security.md` (also adds a SonarQube CE row), and both READMEs.
- `prompts/bootstrap-checklist.md`: a phase-by-phase tick-list companion to
  `bootstrap-project.md`, including the conditional sensitive-data branch (Phase S).
- `inventory/medical-data-security.md`: added ExifTool (metadata detect/strip),
  Poppler (PDF text/page-image/attachment extraction backend), and pypdf (pure-Python
  text-layer extraction; the strict guard's optional PDF pass) as the extraction/
  sanitization backends feeding the OCR → Presidio redaction chain, plus an
  "extract before you scan" step and cross-references in `hooks/scan-contract.json.example`.
- `template-checks` GitHub Actions workflow: path-filtered validation for maintained
  Markdown, Actions examples, shell hooks, Python policy scripts, and committed secrets.
- `prompts/sensitive-data-leak-prevention.md`: runtime/dev leak-prevention guidance
  (logs, temp files, test/CI output, caches, telemetry, third-party/AI egress) with
  a leak-surface control table, awareness/easy-clearance practices, and verification
  steps. Wired into the bootstrap medical/regulated trigger, `AGENTS.md`,
  `strict-phi-agent-guidance.md`, and `inventory/medical-data-security.md`.
- `policies/sensitive-data-runtime-leaks.md`: registers the runtime-leak rule with
  tiered enforcement (gitignore artifact dirs + strict guard, `make clean-sensitive`,
  log-scanning tests, telemetry-egress review, HoundDog data-flow scan) and clear
  remediation; intentionally no false "redaction" hard gate. Listed in
  `policies/README.md`, `AGENTS.md`, and the bootstrap wiring step.
- `inventory/cloud-and-infra.md`: **Observability & error monitoring** section —
  self-hosted Sentry (`getsentry/self-hosted`), managed Sentry free tier, GlitchTip,
  and OpenTelemetry, with the keep-event-data-on-your-infra / no-BAA-on-free-tiers
  caveat cross-linked to the runtime-leak policy and prompt.

### Changed

- Template CI pins Markdownlint and applies the repository's established style choices;
  gitleaks receives the read-only pull-request permission it needs for PR scans.
- **References to the private notes repo: cited, not hidden.** The repo stays private, so
  pointing at `kgrizz-git/Notes_and_Ideas` is encouraged rather than avoided — an agent with
  access should read it, since it is more current than any summary here. Convention is
  `repo → path` marked *(private)* rather than a `github.com` hyperlink, which 404s for anyone
  else and gave the false impression the content was reachable. Provenance added to
  `agent-tooling-efficiency.md`, and `source-repos-to-review.md` now lists useful entry points
  (`reference/tools/`, `reference/agents/`, `info/`, `agents_and_skills/`). AGENTS.md principle
  9 is "recommendations stand on their own" — each entry must be actionable without the source,
  which is a floor on quality, not a ban on citing. Principle 10: multi-phase progress is
  written to `.context/`, not remembered.
- Corrected the Modal entry, which credited the maintainer's notes repo for a `modal` skill
  that actually came from `K-Dense-AI/claude-scientific-skills`; now points at Modal's docs.
- `catalog-skills-agents.md`: the auto-chain rule no longer gets its own section. The per-IDE
  table it carried was really "how to install any always-on rule", so it now says that.
- **Python lint in CI.** `template-checks` now runs `ruff check .` (pinned to 0.11.13 to match
  `hooks/.pre-commit-config.yaml`; a version skew is why "it passed locally" stops being true).
  `compileall` only proved the files parse — proof that was insufficient: an F541 had been
  sitting in `hooks/scripts/check_cleanup_hygiene.sh` on main, now fixed. The pre-commit hook
  alone does not cover it either, since it only protects contributors who ran
  `pre-commit install`, and these scripts are policy gates other repos inherit. Adds `ruff.toml`
  so pre-commit and CI read one rule set. `ruff format` is deliberately **not** gated: 11 of 14
  files predate it and reformatting is a separate reviewable change.
- CI path filters gained `docs/**`, `scripts/**`, `tests/**`, `scaffolds/**`, and `ruff.toml`,
  so doc- and Python-only changes actually trigger the checks that cover them.
- **Secret scan no longer breaks on a repo's first push.** `gitleaks-action@v2` derives a range
  from the push event and runs `git log <before>^..<after>`, which fails with "ambiguous
  argument" whenever a push contains the root commit — i.e. the first push of every project
  bootstrapped from this template. Replaced with a pinned, checksum-verified `gitleaks detect`
  over full history: more thorough and immune to the edge case. Drops the now-unneeded
  `pull-requests: read` permission.
- **Removed the stale agent worktree** at `.claude/worktrees/naughty-payne-0208df` (45 MB,
  detached HEAD at an ancestor of `main`, holding the staged-but-reverted `notes_and_ideas/`
  tree). Nothing was tracked in the index, and it had no unique commits. `.gitignore` now
  covers `.claude/worktrees/`, `.worktrees/`, and `worktrees/` — previously this was only in
  `.git/info/exclude`, which is machine-local and would not survive a fresh clone.
- `.gitignore`: added `.agent-state/`, `.serena/`, `.aider*`, `.tokensave/` — rebuildable agent
  indexes and local state.
- `docs/NAVIGATION.md`: fixed five links to template directories that never existed
  (`templates/adrs/`, `briefs/`, `plans/`, `designs/` → the actual flat files).

## [0.4.4] - 2026-07-09

### Added

- `ci/scripts/check_open_prs.py` — advisory `gh pr list` helper with `--branch`,
  `--once-per-day` stamp under `.context/`, and `--json`.
- `ci/examples/open-prs-advisory.yml` — optional daily/advisory Actions reminder
  (`continue-on-error`; never a required check).
- Agent wiring: `policies/commits-and-branches.md`, `prompts/new-agent-session.md`,
  `prompts/maintenance-loop.md`, `AGENTS.md`, `hooks/README.md`, `ci/README.md`.
- Smoke tests for `--help` and once-per-day stamp skip.

### Changed

- Daily open-PR guidance: agents must inspect `.context/open-prs-check.stamp`
  first and skip the script when fresh (token-cheaper than invoking Python/`gh`).

## [0.4.3] - 2026-07-09

### Added

- Archon (`coleam00/archon` / archon.diy) under harness + ai-agent-platforms.
- Pantheon (pantheon.k-dense.ai) under tools-index research + catalog K-Dense section.
- Cross-IDE handoff options (Passoff, handoff, ai-sync) with Reddit discussion seed.
- Sphinx/Pandoc expanded blurbs in `tools-index.md` documentation section.

## [0.4.2] - 2026-07-09

### Added

- `inventory/knowledge-graph-code-mapping.md`: section **AI-generated code wikis & repo
  documentation** — Google Code Wiki, DeepWiki SaaS, deepwiki-open, RepoWiki,
  FSoft CodeWiki, repowise (+ vs-DeepWiki comparison), Ry Walker survey link.

## [0.4.1] - 2026-07-09

### Added

- `policies/github-actions-usage.md` — estimate minutes/storage when changing CI;
  use GHA deliberately (not fearfully, not carelessly).
- `ci/scripts/check_gha_usage.py` — repo run timing + account billing usage summary
  via `gh` (consolidated billing API; legacy actions/shared-storage endpoints retired).

### Changed

- `inventory/search-apis.md`: Firecrawl listed as a crawl tool only (removed API-key
  dashboard / Notes_and_Ideas credential wording from that entry).
- `ci/README.md` / `AGENTS.md`: link usage policy and script.

## [0.4.0] - 2026-07-09

### Added

- Policies: `changelog-conventions.md`, `plans-and-todos.md`; `plans/README.md`.
- Hook: `check_todo_limits.py` (soft 150 / hard 300 lines); optional `prune_backups.sh`.
- Smoke tests: `tests/test_policy_hooks_smoke.py` (unittest) for TODO/file-size hooks.
- Inventory: Salesforce 7 patterns; Osmani harness/factory/long-running; Graphify+NetworkX;
  GraphRAG Workbench; Codex Security plugin; GitHub license compliance preview; Firecrawl
  (product only — no API keys in-repo).
- Agent stubs (`GEMINI.md`, `QWEN.md`, `CLAUDE.md`) clarified as pointers to `AGENTS.md`.

### Changed

- File-size soft/hard defaults: 600 / 1000 lines (was 400 / 800).
- `hooks/README.md` documents existing gitleaks + lint hooks alongside new policy checks.
