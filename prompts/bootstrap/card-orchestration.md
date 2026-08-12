# Card: Orchestration Tier (P5)

## Ask

1. Is agent work happening in an IDE, or is this a deployed multi-agent product?
2. Roughly how many distinct agent roles?
3. Does the work branch and loop (plan → act → observe → replan), or run start-to-finish?
4. Does anyone need routing, retries, or observability at scale?

## Branch

| Situation | Tier | Reasoning |
| --- | --- | --- |
| Single agent, IDE workflow | `none` | No framework overhead is justified. Most projects land here. |
| 3–10 roles, file-based handoffs, IDE | `hub-and-spoke` | Lightest thing that works; no server. See [`../../inventory/catalog-skills-agents.md`](../../inventory/catalog-skills-agents.md). |
| Cyclical plan→act→observe, stateful branching | `langgraph` | Graphs handle cycles that linear pipelines cannot. |
| Production multi-agent API needing routing + observability | `symphony` | Only when the infrastructure cost is repaid at scale. |
| Not yet clear | `uncertain` | Pick `none`, revisit after the first scaffold. |

**Do not default to Symphony for IDE work.** Hub-and-spoke covers most local multi-agent
workflows at a fraction of the cost. The decision table in
[`../../inventory/harness-engineering.md`](../../inventory/harness-engineering.md) is the
source of truth.

Then pick a **minimal** set of skills and subagents from
[`../../inventory/catalog-skills-agents.md`](../../inventory/catalog-skills-agents.md) — the
catalog is a menu, not a checklist.

## Produce

- `Tier` + one-sentence rationale in `.context/project-profile.md`.
- Skills/subagents sorted into install-now / evaluate-later / skip-for-now, **each with a reason**.
- Any external repos worth mining added to [`../../inventory/source-repos-to-review.md`](../../inventory/source-repos-to-review.md).

## Done when

The profile's orchestration section is filled, and every installed skill has a stated reason.
An unexplained install is a future agent's unexplained deletion.
