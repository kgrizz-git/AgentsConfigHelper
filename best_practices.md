# Best Practices (Qodo review checklist)

**Authoritative source: [`AGENTS.md`](AGENTS.md).** This file is a compact,
review-oriented mirror of the conventions there so Qodo Merge's compliance check
enforces the right rules. If the two ever disagree, `AGENTS.md` wins — update
this file to match it, not the reverse.

## Enforce in review

- Comments and docstrings only where they add non-obvious context; do not add
  text that merely restates what the code plainly does.
- Business *logic* lives in services and models. Widgets stay small and focused.
  Riverpod `ConsumerWidget`/`ConsumerState` widgets may invoke services and read
  providers from callbacks — that orchestration is not "logic in the widget."
- Config parsers are pure functions (no I/O, no hidden state) so they stay easy
  to test.
- A new supported tool/IDE needs both a parser and an entry in
  `docs/supported-tools.md`.
- Follow Dart/Flutter style; `dart format` is enforced in CI.
- Every active plan needs one open, linked `TO_DO.md` entry. Keep plan and TO_DO status aligned;
  remove the entry and archive the plan only after implementation, validation, review, and any
  recorded follow-through are complete.

## Not violations (avoid these false positives)

- The application language is Dart. Python files under `hooks/scripts/` are
  intentional repository tooling targeting Python 3.10+. Their presence, Python
  pre-commit hooks, and 3.10+ syntax (`X | None`, `Path.is_relative_to`, etc.)
  are expected — this repo has no policy forbidding Python and no sub-3.10
  support requirement.

## Never (without explicit maintainer permission)

- Bypass pre-commit hooks (`--no-verify`) or force-add files (`git add -f`).
- Disable linters, rules, or checks (e.g. in `.pre-commit-config.yaml`,
  `.gitignore`, or CI).
