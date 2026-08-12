# MCP Servers And Agent Tooling

Last reviewed: 2026-07-11

Consider MCP servers when they make important project state directly legible to agents. Avoid adding servers that create complexity without improving validation or feedback loops.

> **Choosing CLI + skill vs MCP, and picking between overlapping code-intelligence servers:**
> [`agent-tooling-efficiency.md`](agent-tooling-efficiency.md). Every server's schema is paid on
> every session — MCP earns that cost when interactive state persists (a browser, an editor), and
> rarely for a bounded lookup.

## Useful Categories

- Browser automation and DOM inspection.
- Filesystem and repository search.
- GitHub issues, pull requests, checks, and releases.
- Figma or design source inspection.
- Database inspection for local development.
- Logs, metrics, traces, and local observability.
- Documentation and knowledge-base search.
- Linear, Slack, or project-management context when the user approves.

## Evaluation Criteria

- Does the server expose information the agent otherwise cannot verify?
- Can it be run locally and documented clearly?
- Does it avoid leaking secrets?
- Is the output structured enough for reliable agent use?
- Can CI or local smoke tests verify that it works?
