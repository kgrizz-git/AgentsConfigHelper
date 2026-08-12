# Plan: [Title]

Last reviewed: 2026-07-11
Date: YYYY-MM-DD
Author: [agent or human]
Status: draft | approved | in-progress | complete | abandoned
Linked issue/PR: [url or n/a]

## Goal

One paragraph. What problem does this solve, and for whom?

## Out of scope

- [explicit exclusion 1]
- [explicit exclusion 2]

## Approach

Brief description of the chosen approach and why it was preferred over alternatives.

### Alternatives considered

| Option | Why not chosen |
|---|---|
| [option A] | [reason] |

## Proposed file changes

```
[file or module]  — [what changes and why]
```

## Phases & checklist

### Phase 1: [name]

- [ ] [task]
- [ ] [task]

### Phase 2: [name]

- [ ] [task]

## Verification

How will we know this is done and correct?

- [ ] [test or check]
- [ ] [test or check]

## Open questions

- [ ] [question — assign to owner if known]

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| [risk] | low/med/high | low/med/high | [mitigation] |

## Completion steps (when status = complete)

When this plan is complete, follow this workflow:

1. **Update plan status** to `complete` or `abandoned`
2. **Move this file to `plans/archive/`** (preserve git history)
3. **Log completion** in appropriate changelog:
   - User-visible changes → `CHANGELOG.md`
   - Internal/harness changes → `CHANGELOG.dev.md`
   - Maintenance/security → `MAINTENANCE.md`
4. **Remove related items from `to_do.md`**
5. **Clean up `.context/` scratch files** (archive or delete)
6. **Update `orchestration-state.md`** if present (set phase to `complete`/`blocked`)
7. **Reference the completion** with links to related commits/PRs

Use [`prompts/cleanup-completed-work.md`](../prompts/cleanup-completed-work.md) for systematic cleanup.
