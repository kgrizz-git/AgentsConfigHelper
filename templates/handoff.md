# Template: Handoff Packet

Last reviewed: 2026-08-11

Write to `.context/handoff.md` (or paste as an issue/PR comment) before work moves between
agents, IDEs, or sessions — Claude Code → Cursor → Codex → a human reviewer.

The point is **selective loading**: the next agent reads a compact factual packet instead of
inheriting a large transcript or re-discovering the architecture. Keep it short enough that
reading it is obviously cheaper than rediscovery.

---

```markdown
# Handoff: <task>

Date: YYYY-MM-DD
From: <agent/IDE>  →  To: <agent/IDE or human>
Branch: <branch>   Base: <base>

## Goal and constraints

- Goal: (one sentence)
- Constraints: (deadline, data classification, API/compat limits, "do not touch X")
- Out of scope: (what was deliberately not done)

## What changed

- Files: (paths, grouped by purpose — not a raw diff)
- Decisions: (what was chosen and *why*, especially options rejected)

## Evidence

- Commands/tests run: (exact commands + result)
- What is verified vs assumed:
- Known limitations / things left broken:

## Next action

- (the single next concrete step)
```

---

## Rules

- **Facts only.** No narration of the session, no apologies, no summary of what was hard.
- Record decisions *with reasons*. A rejected option without a reason gets re-litigated.
- Separate **verified** from **assumed**. This is the field that most often prevents a
  downstream error.
- Never paste secrets, tokens, or real PII/PHI — the packet is likely to be copied into a
  chat, an issue, or another tool. Under a `regulated` classification, apply
  [`../prompts/sensitive-data-leak-prevention.md`](../prompts/sensitive-data-leak-prevention.md)
  to this file too.
- Delete it once the work lands. A stale handoff is worse than none — see
  [`../policies/plans-and-todos.md`](../policies/plans-and-todos.md).

Rationale and when a handoff MCP server is worth it:
[`../inventory/agent-tooling-efficiency.md`](../inventory/agent-tooling-efficiency.md).
