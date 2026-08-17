# Template: Bootstrap State

Last reviewed: 2026-08-11

Copy to `.context/bootstrap-state.md` at the start of Phase 0 and update it **as each phase
completes**, not at the end. `.context/` is gitignored, so this never ships with the project.

This file is the reason bootstrap survives a context reset, an interrupted session, or a
handoff to a different agent. Without it, a resumed session has no way to know it stopped at P4.
Status values: `pending` | `in-progress` | `done` | `skipped — <reason>`.

---

```markdown
# Bootstrap State

Started: YYYY-MM-DD
Last updated: YYYY-MM-DD
Template version: (read from VERSION)
Checklist: prompts/bootstrap-checklist.md

## Status

| Phase | Topic | Status | Notes |
|---|---|---|---|
| P0 | Discovery | pending | |
| PS | Sensitive data | pending | Only if P0 flags real/possible regulated data |
| P1 | Profile | pending | |
| P2 | Remote repointed | pending | |
| P3 | Repo hygiene & GitHub settings | pending | |
| P4 | Hooks & CI | pending | |
| P4.5 | Environment | pending | |
| P5 | Skills, subagents & orchestration | pending | |
| P5.5 | Agent tooling & context efficiency | pending | |
| P6 | Agent harness & knowledge | pending | |
| P7 | Docs & gardening | pending | |
| P8 | Scaffold, validate, hand off | pending | |

## Decisions

<!-- One line per decision that a later phase or a future session depends on. -->

- Data classification:
- Approval owner (if regulated):
- Required CI check names (P4 → consumed by P3):
- Orchestration tier:
- Agent tooling adopted / rejected:

## Open questions

-

## Next action

<!-- The single next step, so a resumed session starts here instead of re-deriving. -->
-
```

---

## Rules

- Write `skipped — <reason>` rather than leaving a phase `pending`. Silent skips are the failure
  mode this file exists to prevent.
- Update **Next action** before ending any session mid-bootstrap.
- P3 consumes the required-check names decided in P4 — record them when decided, not later.
- Verify claims with `scripts/check-bootstrap.sh`; it checks repo evidence, not this file.
  If they disagree, the repo is right.
- Once P8 is `done`, the file's job is over. Fold anything durable into
  `.context/project-profile.md` and let cleanup remove it
  ([`../policies/plans-and-todos.md`](../policies/plans-and-todos.md)).
