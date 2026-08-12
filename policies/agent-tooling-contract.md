# Policy: Agent Tooling Contract

Last reviewed: 2026-08-11
Enforced by: convention + `.gitignore` + per-tool smoke test

## Why

Agent tooling accumulates silently. Each MCP server adds schema to every session, each index
adds state to rebuild and secrets to leak, and overlapping tools make it ambiguous which one an
agent should reach for — which can cost more context than the tools save. This policy makes the
decision rule explicit so contributors and agents do not re-argue it per session.

Selection guidance and the tool menu live in
[`inventory/agent-tooling-efficiency.md`](../inventory/agent-tooling-efficiency.md).

## The contract

Paste this into the generated project's `AGENTS.md`, adapting the tool names to what is actually
installed. It is deliberately client-agnostic — it constrains behavior, not which IDE or model a
contributor uses.

```md
## Agent tooling policy

- Search and read targeted files before requesting broad repository context.
- Use one primary code-intelligence/indexing tool per role or task.
- Prefer a CLI plus task-specific skill for batch work; use MCP when persistent,
  interactive state materially helps.
- Record decisions, changed files, verification, and next steps in a handoff before
  changing agents or IDEs.
- Keep credentials, generated indexes, and local agent state out of version control.
```

## Supporting rules

| Rule | Default | Tier |
|---|---|---|
| Generated indexes and agent state live in `.agent-state/` | gitignored; rebuild documented in `AGENTS.md` | hard gate (`.gitignore`) |
| Each installed tool has a smoke test | index a fixture, run one query, remove the state | soft gate |
| Native fallback keeps working | `rg`, language server, source docs, and tests suffice when an optional service is down | advisory |
| MCP servers are project- or role-scoped | no global installs by default | advisory |
| Committed config is portable | pinned command names, no machine paths, no tokens | soft gate |
| Adoption is recorded | `.context/project-profile.md` → Agent tooling: adopted / rejected + reason | convention |

## Smoke test shape

A tool that cannot be verified in one command should not be a dependency of the workflow:

```sh
# example: index a fixture, query it, tear down
<tool> index tests/fixtures/sample_pkg
<tool> query "where is parse_config defined"
rm -rf .agent-state/<tool>
```

Wire it into CI only if the tool is required for the project to build or review. Optional
tooling should degrade to the native fallback rather than break CI.

## Adopting

1. Work the agent-tooling card during bootstrap
   ([`prompts/bootstrap/card-agent-tooling.md`](../prompts/bootstrap/card-agent-tooling.md)).
2. Add `.agent-state/` to `.gitignore`.
3. Paste the contract block above into `AGENTS.md`.
4. Record adopted and rejected tools in the project profile.
