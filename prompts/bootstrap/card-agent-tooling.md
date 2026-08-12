# Card: Agent Tooling & Context Efficiency (P5.5)

Runs after orchestration (P5), because tools attach to roles. Menu and rationale:
[`../../inventory/agent-tooling-efficiency.md`](../../inventory/agent-tooling-efficiency.md).

> **The default answer is "none for now."** A fresh scaffold has no recurring information gap
> to close. Recommend **zero to two** tools, never a suite.

## Ask

1. Is this a fresh scaffold or an existing codebase? Roughly how many source files?
2. What language mix? (Serena's value depends on language-server quality.)
3. Where do agent sessions actually waste context today — hunting symbols, re-reading
   architecture, looking up third-party APIs, or reproducing browser bugs?
4. Is code review recurring and structured, or ad-hoc?
5. Does work move between agents/IDEs (Claude Code → Cursor → Codex) or stay in one?
6. Any constraint against local indexing or external services (air-gapped, regulated)?

## Branch

| Answer | Action |
|---|---|
| Fresh scaffold, < ~50 files | **Install nothing.** Adopt the handoff practice and the contract only. Revisit at the first maintenance loop. |
| Repeatedly looking up third-party APIs | Context7, CLI + skill. Confirm security-critical details upstream. |
| Losing context hunting symbols / doing cross-file refactors | Serena, scoped to the coder/debugger role. Verify on this repo's languages first. |
| Recurring structured PR review | code-review-graph, scoped to the reviewer role only. |
| Architecture/topology questions across code *and* docs | Graphify + NetworkX **or** TokenSave — pick one, they overlap. |
| Recurring browser/UX debugging | chrome-devtools-mcp. MCP is right here: browser state is genuinely persistent. |
| Work moves between agents or IDEs | Adopt [`../../templates/handoff.md`](../../templates/handoff.md). This applies to **every** project. |
| Regulated data (from P0) | Local-only tools; no cloud indexing. Re-check what each tool transmits before installing. |
| More than two tools look appealing | Install one. Measure. The overlap warning in the inventory file exists because loading four erases the savings. |

## Produce

- `.agent-state/` added to `.gitignore`.
- The contract block from [`../../policies/agent-tooling-contract.md`](../../policies/agent-tooling-contract.md) pasted into the project's `AGENTS.md`.
- An **Agent tooling** section in `.context/project-profile.md`: adopted, rejected-as-redundant,
  and the date last evaluated.
- One smoke test per installed tool (index a fixture, one query, tear down).
- [`../../templates/handoff.md`](../../templates/handoff.md) available to the project.

## Done when

- The profile records a decision for every tool considered — including the rejections and why.
  A recorded rejection is what stops the next agent from re-litigating it.
- `.gitignore` covers `.agent-state/`.
- Every installed tool has been run once successfully, and the native fallback (`rg`, language
  server, tests) still works with the tool disabled.

## Evidence rule

Do not decide on stars or vendor token-savings claims. Prefer, in order: a local evaluation on
this repo → reproducible third-party benchmarks → transparent project-authored benchmarks →
popularity. Headline "90% fewer tokens" figures usually compare targeted retrieval against a
whole-repository baseline and do not transfer.
