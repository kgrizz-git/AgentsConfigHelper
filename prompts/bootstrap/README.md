# Bootstrap Topic Cards

Short decision scripts for the bootstrap phases that have a real branch — where the *answer*
changes what you build. Phases with one obvious path stay as single lines in
[`../bootstrap-checklist.md`](../bootstrap-checklist.md) and link straight to their deep doc.

Each card has the same four sections:

1. **Ask** — the questions, in the order to ask them.
2. **Branch** — answer → action table. This is the part that must be followed.
3. **Produce** — the artifacts that must exist afterwards.
4. **Done when** — the observable condition. `scripts/check-bootstrap.sh` checks these.

| Card | Phase | Branches on |
| --- | --- | --- |
| [card-data-classification.md](card-data-classification.md) | P0 → PS | What data may enter the repo |
| [card-environment.md](card-environment.md) | P4.5 | Language and runtime |
| [card-ci-tier.md](card-ci-tier.md) | P4 | Team size, visibility, Actions budget |
| [card-orchestration.md](card-orchestration.md) | P5 | Agent count and workflow shape |
| [card-agent-tooling.md](card-agent-tooling.md) | P5.5 | Repo size and recurring information gaps |

## Rules for using a card

- Ask the questions **before** proposing an answer. Do not infer the data classification or
  team size from the code; both are facts only the user has.
- Record the answer and the resulting action in `.context/bootstrap-state.md` under the phase ID.
- Skipping is allowed; skipping *silently* is not. Write `skipped — <reason>` in the state file.
- A card is guidance for the interview. The deep doc it links to remains the source of truth
  for the details.
