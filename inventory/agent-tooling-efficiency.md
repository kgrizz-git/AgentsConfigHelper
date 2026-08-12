# Token-Efficient Agent Tooling

Last reviewed: 2026-08-11
Catalog reviewed through: 2026-08-11

Menu for deciding **which** context/code-intelligence tools an agent-facing repo installs, and
**whether** to install any at all. The neighbouring files profile individual tools; this file
owns the choice *between* overlapping ones.

Distilled from `kgrizz-git/Notes_and_Ideas` → `reference/tools/token-efficient-agent-tooling.md`
*(private)*, which carries the fuller treatment plus per-tool notes under `reference/tools/`.
**Read the source first if you have access** — it is revised more often than this summary.

- Tool profiles for graphs and code maps → [`knowledge-graph-code-mapping.md`](knowledge-graph-code-mapping.md)
- MCP server evaluation criteria → [`mcp-servers.md`](mcp-servers.md)
- The rule to paste into a generated project → [`policies/agent-tooling-contract.md`](../policies/agent-tooling-contract.md)

> **Default for a fresh scaffold: install nothing.** An empty repo cannot justify an index.
> Native search, the language server, the test suite, and source docs are the baseline every
> recommendation below must beat.

## Add a tool only to close a recurring information gap

| Need | Default option | Boundary |
| --- | --- | --- |
| Unknown third-party API or version-specific usage | [Context7](https://github.com/upstash/context7) (CLI + skill) | Widely adopted for current library docs. Catalog includes community content — confirm security/API critical details upstream. MCP only if its interactive tools beat the persistent schema cost. |
| One-off browser inspection, traces, audits | [chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Official Chrome tooling. MCP earns its cost here because browser state is genuinely persistent. Not a substitute for code intelligence. |
| Symbol navigation, cross-file edits, refactors | [Serena](https://github.com/oraios/serena) | Mature LSP-backed option. Vendor evaluations are evidence, not proof — verify on this repo's languages. |
| PR blast radius and review slices | [code-review-graph](https://github.com/tirth8205/code-review-graph) | Review-specific. Published benchmarks are unusually candid about limits; savings do not transfer to small edits. |
| Architecture across code, docs, and other artifacts | [Graphify](https://github.com/Graphify-Labs/graphify) + NetworkX | Broad coverage; project-authored benchmarks do not establish general coding-agent gains. Choose for topology, not editing. |
| Local semantic code index over MCP | [TokenSave](https://github.com/aovestdipaperino/tokensave) | Rust/libSQL, local-only, 30+ languages. Comparatively niche — treat performance claims as self-reported until measured here. |
| Resuming work in another agent or IDE | A structured handoff file ([`templates/handoff.md`](../templates/handoff.md)) | The practice matters more than any product. Reach for an MCP handoff server only if selective cross-session retrieval is actually needed. |

Headline token-reduction numbers for graph tools are workload-specific and usually compare
targeted retrieval against a whole-repository baseline. Read them as an invitation to measure
locally, not as promised savings.

## Assign tools to roles, not to everyone

| Role | Focus | Output |
| --- | --- | --- |
| Planner / researcher | Context7; Graphify **or** TokenSave when topology is the bottleneck | Architecture slice, affected areas, source links |
| Coder / debugger | Serena; native search and tests | Minimal change + verification |
| Reviewer | code-review-graph; diff and test results | Blast radius, risks, verdict |
| Browser / UX | chrome-devtools-mcp | Repro steps, trace/audit evidence |

**Overlap warning.** Serena (symbol-aware editing) and one structural tool (architecture and
impact questions) complement each other. Graphify, TokenSave, and code-review-graph's structural
functions substantially overlap — pick one. Loading all four into every agent duplicates indexes
and MCP schemas, makes tool choice ambiguous, and can erase the savings the tools exist to provide.

## CLI + skills, or MCP?

| Situation | Prefer | Why |
| --- | --- | --- |
| Bounded lookup, batch task, generated script | CLI + skill | Agent loads focused instructions and one command surface |
| Interactive loop with retained state | MCP | Persistent browser/editor/service state outweighs schema overhead |
| Several agents with distinct jobs | Role-scoped tools | Each agent sees a smaller interface |
| Quick task in a small repo | Native tools only | Indexing setup will not repay itself |

This is a default, not a ban on MCP.

## Adoption sequence

1. Establish a baseline task using native search, tests, and docs.
2. Add the single tool that removes the clearest bottleneck.
3. Run it on a representative task. Record setup time, task time, result quality, context use,
   and failure modes.
4. Assign it to the role where it helped. Drop overlapping tools that did not earn their
   complexity.
5. Record the decision in `.context/project-profile.md` → **Agent tooling**, and paste the
   contract from [`policies/agent-tooling-contract.md`](../policies/agent-tooling-contract.md)
   into the project's `AGENTS.md`.

## Evidence standard

Popularity is a weak proxy for production value. Prefer evidence in this order:

1. A local evaluation on this repo's language mix, size, and agent client.
2. Reproducible third-party benchmarks, or adoption evidence from comparable teams.
3. Transparent project-authored benchmarks that state their baseline and limitations.
4. Repository stars, release activity, vendor claims.

Never let (4) alone decide. Record whether each tool was adopted, kept as a complement, or
rejected as redundant — a rejection with a reason saves the next agent from re-litigating it.

## Keeping this file honest

Tool facts (install commands, maintenance status, whether a project still exists) rot faster
than the 180-day `Last reviewed` window in [`policies/doc-freshness.md`](../policies/doc-freshness.md).
Two mechanisms cover this file:

- `Last reviewed:` — the standard prose-accuracy marker.
- `Catalog reviewed through:` — the date someone last asked *"is this still the right menu?"*
  Refresh it when a new tool in this space is evaluated, whether or not it was adopted.
  [`ci/scripts/check_doc_links.py`](../ci/scripts/check_doc_links.py) reports dead
  links and a stale catalog date; [`prompts/maintenance-loop.md`](../prompts/maintenance-loop.md)
  schedules the review.
