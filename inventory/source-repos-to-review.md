# Source Repositories To Review

Last reviewed: 2026-08-11

Repos worth inspecting for reusable skills, prompts, conventions, tools, or architecture
ideas. This is a starting list — add entries as you discover new candidates.

Entries marked *(private)* are the maintainer's own repos, where new tools are first catalogued
and evaluated before durable findings are distilled into this template. **An agent with access
should read them directly** — they are more current than the summaries here. Everything in this
template is still actionable without them.

---

## Curated starting list

| Repo | Why useful |
| --- | --- |
| `kgrizz-git/Notes_and_Ideas` *(private)* | **The richest tool catalog feeding this template — check it first.** Ongoing curated notes on AI/ML tooling, coding-agent harnesses, MCP servers, model providers and pricing, context-engineering and token-efficiency research, plus ~15 subagents and ~60 skills (scientific, engineering, writing, dev). Useful entry points: `reference/tools/`, `reference/agents/`, `info/`, `agents_and_skills/`. Findings are distilled here as they mature — see `inventory/catalog-skills-agents.md` and `inventory/agent-tooling-efficiency.md`. |
| <https://github.com/K-Dense-AI/claude-scientific-skills> | Large library of `SKILL.md`-format scientific skills (bio, chem, physics, ML, writing). MIT license. See `inventory/catalog-skills-agents.md` |
| <https://github.com/openai/symphony> | OpenAI multi-agent orchestration framework. Task graphs, routing, parallelism, observability |
| <https://github.com/juanceresa/sift-kg> | Knowledge graph construction from codebases for LLM grounding. See `inventory/knowledge-graph-code-mapping.md` |
| <https://github.com/obra/superpowers> | Agentic skills framework + core methodology (planning, TDD, debugging, review) |
| <https://github.com/obra/superpowers-skills> | Community-editable Superpowers skills companion |
| <https://github.com/garry-tan/gstack> | Agentic workflow conventions and project scaffolding patterns |
| <https://github.com/coleam00/archon> | Open-source harness builder / command layer for coding agents (YAML workflows, worktrees, multi-channel dispatch). See `inventory/harness-engineering.md` |
| <https://github.com/TheMrGU/Ai-Agent-Context-Passoff> | MCP handoff between Cursor / Claude Code / Codex (local SQLite). Cross-IDE session continuity |
| <https://github.com/anthropics/mcp> | Model Context Protocol reference implementation and server examples |

---

## User-added sources

Add entries here as they are identified:

```text
- <repo-url-or-path> — <why it may be useful>
```

---

## Review checklist

For each source repo:

- What reusable skills, prompts, rules, or scripts does it contain?
- Which conventions are project-specific and should not be copied?
- Are there useful CI, security, testing, docs, or release patterns?
- Are there licensing or attribution constraints?
- Is the repo actively maintained? (last commit, open issues, stars)
- What small adaptation, if any, should be added to this project?
