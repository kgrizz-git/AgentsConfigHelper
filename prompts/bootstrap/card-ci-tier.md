# Card: CI Tier (P4)

## Ask

1. Solo, small team, or open to public contributors?
2. Will the repo be public? (Public repos get free Actions minutes; private ones burn quota.)
3. What is the Actions budget or plan?
4. What must never merge broken — tests, types, lint, security, all of it?
5. Are there long-running or GPU jobs, or is everything fast and CPU-only?

## Branch

| Situation | Tier | Wire |
|---|---|---|
| Solo, private, early | **minimal** | Pre-commit only + one `ci / test` workflow on PR. No scheduled jobs. |
| Small team, private | **standard** | `ci / test`, lint/type, `security / secret scan`. Dependabot weekly. Branch ruleset requiring those checks. |
| Public or external contributors | **full** | Standard + CodeQL, `CODEOWNERS`, `SECURITY.md`, required review, least-privilege workflow permissions. |
| Regulated data (from P0) | **full + gates** | Above, plus the required sensitive-data CI job from [`../../policies/sensitive-data-scan-gates.md`](../../policies/sensitive-data-scan-gates.md). Non-negotiable. |
| Tight Actions budget | any | Cut matrix breadth and scheduled runs first, not the security jobs. Estimate before wiring: [`../../policies/github-actions-usage.md`](../../policies/github-actions-usage.md). |

**Decide the check *names* now** (e.g. `ci / test`, `security / secret scan`) so the branch
ruleset in P3 matches CI exactly. A ruleset requiring a check name that no workflow produces
blocks every PR forever — this is the single most common bootstrap failure.

## Produce

- Root `.pre-commit-config.yaml` copied from [`../../hooks/.pre-commit-config.yaml`](../../hooks/.pre-commit-config.yaml), with `pre-commit install` run.
- At least one workflow in `.github/workflows/`, chosen from [`../../ci/README.md`](../../ci/README.md).
- The required-check names written into `.context/bootstrap-state.md` for P3 to consume.

## Done when

A PR triggers the workflows, the ruleset's required checks match the names those workflows
report, and the split between pre-commit / CI / agent-side is recorded
([`../../hooks/README.md`](../../hooks/README.md)).
