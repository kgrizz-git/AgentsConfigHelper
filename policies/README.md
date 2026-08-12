# Policies

Last reviewed: 2026-08-11

Durable, opt-in repo rules a project can adopt and enforce. Each policy states the rule,
the rationale, sensible defaults, and how it is enforced (hook, CI, or convention).

Policies are **defaults to tune**, not laws. Pick what fits the project; change thresholds
in one place and let [`hooks/`](../hooks/) and [`ci/`](../ci/) enforce them.

## Policy files

| Policy | Enforced by |
|---|---|
| [file-size-and-counts.md](file-size-and-counts.md) — file/function size & per-dir file counts | `hooks/scripts/check_file_size.py` |
| [plans-and-todos.md](plans-and-todos.md) — plans lifecycle, archiving, living `to_do` caps | `hooks/scripts/check_todo_limits.py` + convention |
| [changelog-conventions.md](changelog-conventions.md) — public vs developer changelogs + SemVer | convention / release hygiene |
| [doc-freshness.md](doc-freshness.md) — `Last reviewed` markers & staleness windows | `hooks/scripts/check_doc_freshness.py` |
| [commits-and-branches.md](commits-and-branches.md) — commit messages, branch naming, PR hygiene, advisory open-PR check | convention + `ci/scripts/check_open_prs.py` (+ optional daily workflow) |
| [security-baseline.md](security-baseline.md) — secrets, deps, SAST expectations | hooks + CI (see `inventory/security-quality.md`) |
| [sensitive-data-runtime-leaks.md](sensitive-data-runtime-leaks.md) — runtime/dev leaks into logs, temp files, caches, telemetry | convention + hooks + CI (guidance: `prompts/sensitive-data-leak-prevention.md`) |
| [sensitive-data-scan-gates.md](sensitive-data-scan-gates.md) — protected `.gitignore` rules, forbidden tracked paths, heavy-scanner contract/ledger | `hooks/scripts/check_gitignore_protected.py`, `check_forbidden_paths.py`, `check_scan_contract.py` + CI |
| [github-repository-hygiene.md](github-repository-hygiene.md) — default-branch rulesets, reviews/checks, GitHub security, and PII/PHI/path gates | GitHub settings + hooks + required CI |
| [github-actions-usage.md](github-actions-usage.md) — Actions minutes/storage stewardship | convention + `ci/scripts/check_gha_usage.py` |
| [garbage-collection.md](garbage-collection.md) — dead code, stale TODOs, unused deps | CI + agent prompts |
| [agent-tooling-contract.md](agent-tooling-contract.md) — one code-intelligence tool per role, `.agent-state/` untracked, per-tool smoke test | convention + `.gitignore` + smoke test (menu: `inventory/agent-tooling-efficiency.md`) |

## Template self-checks

This repo's own assets are validated by the `template-checks` workflow: Markdown lint,
relative-link resolution (`ci/scripts/check_doc_links.py --internal-only --strict`), Python
lint (`ruff check .`, rules in [`../ruff.toml`](../ruff.toml)), byte-compile, shellcheck on
`hooks/scripts`, and a gitleaks secret scan. Keep the ruff pin in the workflow and in
[`../hooks/.pre-commit-config.yaml`](../hooks/.pre-commit-config.yaml) in sync — a version
skew is the usual reason a check passes locally and fails in CI.

`ruff format` is available via pre-commit but is deliberately **not** a CI gate: most existing
files predate it, so reformatting is a separate reviewable change rather than something a lint
gate forces.

## How to adopt

1. Read the policy and adjust thresholds to the project.
2. Wire the matching check in [`hooks/.pre-commit-config.yaml`](../hooks/.pre-commit-config.yaml)
   and/or a CI workflow.
3. Record the decision (e.g. in an ADR via [`templates/adr.md`](../templates/adr.md)).

## Enforcement tiers

- **Advisory** — surfaced in review/CI logs, does not block.
- **Soft gate** — warns locally (pre-commit), blocks in CI.
- **Hard gate** — blocks commit and CI.

Start advisory, promote to gates once the team agrees a rule is durable.
