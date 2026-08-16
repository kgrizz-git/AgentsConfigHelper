# Supported Tools

Last reviewed: 2026-08-11

Config format reference for each supported AI agent and IDE. Used by AgentsConfigHelper
to auto-detect, parse, visualize, and edit settings across tools.

## Quick comparison

| Tool | Config format | User config | Project config | Rules file | Permissions model |
| --- | --- | --- | --- | --- | --- |
| Claude Code | JSON | `~/.claude/settings.json` | `.claude/settings.json` | `CLAUDE.md` | allow/ask/deny arrays |
| Codex CLI | TOML | `~/.codex/config.toml` | `.codex/config.toml` | `AGENTS.md` | sandbox + permission profiles |
| Opencode | JSON | `~/.config/opencode/opencode.json` | `.opencode/opencode.json` | `AGENTS.md` | per-tool allow/ask/deny |
| Paseo | JSON | `~/.paseo/config.json` | `paseo.json` | skills | delegated to provider |
| Cursor | JSON | `~/.cursor/permissions.json` | `.cursor/rules/*.mdc` | `.mdc` + `AGENTS.md` | allowlist + classifier |
| Kiro | YAML | `~/.kiro/settings/permissions.yaml` | `.kiro/steering/*.md` | steering + `AGENTS.md` | capability-based |
| Devin | JSON | `~/.config/devin/config.json` | `.devin/config.json` | `AGENTS.md` | scope-based allow/deny |
| Antigravity | JSON | `~/.gemini/antigravity-cli/settings.json` | `.agents/rules/` | `GEMINI.md` + rules | action(target) + presets |
| agy-acp | JSON | `~/.openab/agy-acp/sessions.json` | host ACP config (e.g. Zed `agent_servers`) | via agy hooks | ACP permission bridge |
| VS Code / GitHub Copilot _(deferred)_ | Markdown | — | `.github/copilot-instructions.md` | `.github/copilot-instructions.md` | instructions only (no permission model) |

---

## Claude Code

### Claude Code Config paths

| Scope | Path |
| --- | --- |
| User settings | `~/.claude/settings.json` |
| Project shared | `.claude/settings.json` |
| Project local | `.claude/settings.local.json` |
| Managed (enterprise) | `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS), `/etc/claude-code/managed-settings.json` (Linux), `C:\Program Files\ClaudeCode\managed-settings.json` (Windows) |
| Global state | `~/.claude.json` |
| MCP servers | `.mcp.json` |

### Claude Code Config format

JSON with permissions, hooks, env, model settings.

```json
{
  "permissions": {
    "defaultMode": "default",
    "allow": ["Bash(npm run *)", "Bash(git status)"],
    "ask": ["Bash(git push *)"],
    "deny": ["Read(./.env)"]
  },
  "hooks": { "PreToolUse": [...] },
  "env": { "NODE_ENV": "development" },
  "model": "claude-sonnet-4-20250514",
  "autoMemoryEnabled": true
}
```

### Claude Code Permissions

- **Rule types:** `allow`, `ask`, `deny` — arrays of tool pattern strings
- **Evaluation:** deny → ask → allow (first match wins)
- **Modes:** `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`
- **Pattern format:** `ToolName` or `ToolName(glob-pattern)`

### Claude Code Rules

| Scope | Path |
| --- | --- |
| Managed | OS-specific system paths |
| User | `~/.claude/CLAUDE.md` |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` |
| Local | `./CLAUDE.local.md` |

Also supports `.claude/rules/*.md` (modular topic rules) and `~/.claude/skills/` (on-demand skills).

### Claude Code CLI

`claude`, `claude -c` (continue), `claude -p` (non-interactive), `claude mcp`, `claude doctor`, `claude import codex`

**Key flags:** `--permission-mode`, `--allowedTools`, `--disallowedTools`, `--settings <path>`

**Sources:** [Settings](https://code.claude.com/docs/en/settings) · [CLAUDE.md](https://code.claude.com/docs/en/claude-md) · [Permissions](https://code.claude.com/docs/en/permissions) · [CLI](https://code.claude.com/docs/en/cli-reference)

---

## Codex CLI

### Codex CLI Config paths

| Scope | Path |
| --- | --- |
| User config | `~/.codex/config.toml` |
| Project config | `.codex/config.toml` |
| System config | `/etc/codex/config.toml` (Unix) |
| Profile files | `~/.codex/<profile>.config.toml` |
| Rules | `~/.codex/rules/default.rules`, `.codex/rules/*.rules` |
| Hooks | `~/.codex/hooks.json` or `[hooks]` in config.toml |

Override home with `CODEX_HOME` env var.

### Codex CLI Config format

TOML with model, sandbox, permissions, MCP, hooks sections.

```toml
model = "o4-mini"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
default_permissions = ":workspace"

[sandbox_workspace_write]
network_access = true
writable_roots = ["/tmp"]

[permissions.project-edit.filesystem]
"/src" = "write"
"/.env" = "deny"
```

### Codex CLI Permissions

- **Legacy:** `sandbox_mode` (`read-only`, `workspace-write`, `danger-full-access`) + `approval_policy` (`untrusted`, `on-request`, `never`)
- **Profiles (beta):** Named profiles under `[permissions.<name>]` with filesystem and network rules
- **Filesystem:** `read`, `write`, `deny`
- **Network:** domain allow/deny with wildcards
- **Sandbox:** macOS Seatbelt, Linux bwrap+seccomp, Windows native

### Codex CLI Rules

| Scope | Path |
| --- | --- |
| Global | `~/.codex/AGENTS.md` or `~/.codex/AGENTS.override.md` |
| Project | `AGENTS.md` (walk root → CWD) |
| Command rules | `.codex/rules/*.rules` (Starlark) |

### Codex CLI CLI

`codex`, `codex exec`, `codex resume`, `codex review`, `codex login`, `codex mcp`, `codex update`

**Key flags:** `-c key=value`, `-s <mode>`, `-a <policy>`, `--profile <name>`, `--yolo`

**Sources:** [Config basic](https://developers.openai.com/codex/config-basic) · [Config reference](https://developers.openai.com/codex/config-reference) · [Permissions](https://developers.openai.com/codex/permissions) · [AGENTS.md](https://developers.openai.com/codex/agent-configuration/agents-md) · [Rules](https://developers.openai.com/codex/rules) · [CLI](https://developers.openai.com/codex/cli/reference)

---

## Opencode

### Opencode Config paths

| Scope | Path |
| --- | --- |
| Global | `~/.config/opencode/opencode.json` |
| Project | `opencode.json` in project root |
| Project (.opencode) | `.opencode/opencode.json` |
| Custom | `OPENCODE_CONFIG` env var |
| Managed | `/Library/Application Support/opencode/` (macOS), `/etc/opencode/` (Linux) |
| Auth | `~/.local/share/opencode/auth.json` |

**Precedence (lowest→highest):** remote → global → custom env → project → `.opencode/` dirs → inline env → managed → MDM

### Opencode Config format

JSON. Schema at `https://opencode.ai/config.json`.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5",
  "permission": {
    "bash": { "*": "ask", "git *": "allow", "rm *": "deny" },
    "edit": { "*": "deny", "packages/web/src/**/*.mdx": "allow" }
  },
  "instructions": ["docs/guidelines.md"],
  "mcp": { ... },
  "plugin": [ ... ]
}
```

### Opencode Permissions

- **Per-tool:** `allow`, `ask`, `deny` for each tool
- **Tools:** `read`, `edit`, `glob`, `grep`, `bash`, `task`, `skill`, `lsp`, `question`, `webfetch`, `websearch`, `external_directory`, `doom_loop`
- **Pattern matching:** `*` (zero+ chars), `?` (one char)
- **Per-agent overrides** supported

### Opencode Rules

| Scope | Path |
| --- | --- |
| Project | `AGENTS.md` |
| Global | `~/.config/opencode/AGENTS.md` |
| Skills | `.opencode/skills/<name>/SKILL.md` |
| Agents | `.opencode/agents/<name>.md` |

### Opencode CLI

`opencode`, `opencode run`, `opencode serve`, `opencode web`, `opencode auth login`, `opencode mcp add`, `opencode agent create`

**Key env vars:** `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG_CONTENT`, `OPENCODE_PERMISSION`

**Sources:** [Config schema](https://opencode.ai/config.json)

---

## Paseo

### Paseo Config paths

| Scope | Path |
| --- | --- |
| Global daemon | `~/.paseo/config.json` |
| Project | `paseo.json` in repo root |
| Hub | `.paseo/hub.yml` + `.paseo/workflows/*.yml` |
| Custom home | `PASEO_HOME` env var |

**Home directory structure:** `~/.paseo/` contains config, worktrees, agents, schedules, chat, projects.

### Paseo Config format

JSON. Schema at `https://paseo.sh/schemas/paseo.config.v1.json`.

```json
{
  "daemon": {
    "listen": "127.0.0.1:6767",
    "mcp": { "enabled": true, "injectIntoAgents": true },
    "browserTools": { "enabled": true },
    "auth": { "password": "bcrypt-hash" }
  },
  "agents": {
    "providers": {
      "my-claude": {
        "extends": "claude",
        "env": { "ANTHROPIC_API_KEY": "..." },
        "disallowedTools": ["WebSearch"]
      }
    }
  }
}
```

### Paseo Permissions

- Delegates to underlying agent provider (Claude, Codex, OpenCode, etc.)
- Runtime permission management via `paseo permit ls/allow/deny`
- Per-provider: passes `allowedTools`, `disallowedTools`, sandbox settings
- Daemon-level: password auth, hostname restrictions

### Paseo Rules

- Orchestration skills installed to `~/.agents/skills/`
- Project `paseo.json` defines worktree hooks, scripts, services
- Hub workflows in `.paseo/workflows/*.yml`

### Paseo CLI

`paseo run`, `paseo ls`, `paseo attach`, `paseo send`, `paseo stop`, `paseo workspace create`, `paseo schedule create`, `paseo permit allow/deny`, `paseo daemon start`

**Sources:** [Schema](https://paseo.sh/schemas/paseo.config.v1.json)

---

## Cursor

### Cursor Config paths

| Scope | Path |
| --- | --- |
| User permissions | `~/.cursor/permissions.json` |
| User CLI config | `~/.cursor/cli-config.json` |
| User MCP | `~/.cursor/mcp.json` |
| Project rules | `.cursor/rules/*.mdc` |
| Project permissions | `<workspace>/.cursor/permissions.json` |
| Project MCP | `.cursor/mcp.json` |
| Legacy rules | `.cursorrules` (deprecated) |
| Cross-tool | `AGENTS.md`, `CLAUDE.md` |

### Cursor Config format

Multiple JSON files for different concerns.

**`permissions.json`:**

```json
{
  "mcpAllowlist": ["github:*", "linear:list_issues"],
  "terminalAllowlist": ["git", "npm", "cargo build"],
  "autoRun": {
    "allow_instructions": ["Read-only inspections are fine."],
    "block_instructions": ["Pause delete operations for review."]
  }
}
```

**`cli-config.json`:**

```json
{
  "permissions": {
    "allow": ["Shell(ls)", "Shell(git)", "Read(src/**/*.ts)"],
    "deny": ["Shell(rm)", "Read(.env*)"]
  },
  "approvalMode": "allowlist"
}
```

**`.cursor/rules/*.mdc`** — YAML frontmatter + markdown body with `description`, `globs`, `alwaysApply` fields.

### Cursor Permissions

- **Run modes:** Auto-review (LLM classifier), Allowlist, Run Everything
- **Sources:** Team admin → `permissions.json` → IDE Settings UI
- **CLI tokens:** `Shell(cmd)`, `Read(path)`, `Write(path)`, `WebFetch(domain)`, `Mcp(server:tool)`
- **Sandbox:** `sandbox.json` for OS-level constraints

### Cursor Rules

| File | Status | Format |
| --- | --- | --- |
| `.cursor/rules/*.mdc` | Primary | YAML frontmatter + markdown |
| `AGENTS.md` | Cross-tool | Plain markdown |
| `CLAUDE.md` | Claude compat | Plain markdown |
| `.cursorrules` | Deprecated | Plain text |

**Application modes:** Always Apply, Auto-Attached (glob), Agent Requested (description), Manual (@-mention)

### Cursor CLI

`cursor-agent`, `cursor agent login`, `cursor agent mcp`, `cursor agent sandbox`, `cursor agent models`

**Key flags:** `-p` (non-interactive), `-f`/`--force` (skip prompts), `--sandbox`, `--mode plan|ask`

**Sources:** [Rules](https://cursor.com/docs/rules) · [Permissions](https://cursor.com/docs/reference/permissions) · [CLI config](https://cursor.com/docs/cli/reference/configuration) · [CLI permissions](https://cursor.com/docs/cli/reference/permissions) · [Sandbox](https://cursor.com/docs/reference/sandbox)

---

## Kiro

### Kiro Config paths

| Scope | Path |
| --- | --- |
| User MCP | `~/.kiro/settings/mcp.json` |
| User permissions | `~/.kiro/settings/permissions.yaml` |
| User agents | `~/.kiro/agents/` |
| User steering | `~/.kiro/steering/` |
| Project MCP | `.kiro/settings/mcp.json` |
| Workspace permissions | `~/.kiro/workspace-roots/<hash>/permissions.yaml` (outside repo) |
| Project agents | `.kiro/agents/` |
| Project steering | `.kiro/steering/` |
| Project specs | `.kiro/specs/` |

### Kiro Config format

**`permissions.yaml`:**

```yaml
rules:
  - capability: shell
    effect: allow
    match: ["git *", "npm *", "npx *"]
  - capability: fs_write
    effect: allow
    match: ["src/**", "tests/**"]
  - capability: fs_read
    effect: deny
    match: ["**/.env", "**/*.pem"]
```

**Custom agent (`.kiro/agents/*.json` or `*.md`):**

```json
{
  "name": "my-agent",
  "model": "claude-sonnet-4",
  "tools": ["read", "write", "shell"],
  "permissions": { "rules": [...] }
}
```

### Kiro Permissions

- **Capabilities:** `fs_read`, `fs_write`, `shell`, `web_fetch`, `web_search`, `mcp`, `subagent`, `skill`, `power`, `context`, `diagnostics`, `sandbox_network`
- **Effects:** `deny`, `ask`, `allow` (deny > ask > allow)
- **Scopes:** User → Workspace → Agent → Session
- **Autonomy modes:** Autopilot, Supervised

### Kiro Rules

- **Steering files:** `.kiro/steering/*.md` with `inclusion` mode (`always`, `fileMatch`, `auto`, `manual`)
- **AGENTS.md:** Read natively
- **Specs:** Structured requirements/design/tasks in `.kiro/specs/`

### Kiro CLI

`kiro-cli chat`, `kiro-cli login`, `kiro-cli settings`, `kiro-cli agent`, `kiro-cli mcp`, `kiro-cli doctor`

**Key flags:** `--trust-all-tools`, `--trust-tools`, `--effort`, `--agent`, `--no-interactive`

**Sources:** [Configuration](https://kiro.dev/docs/configuration/) · [Permissions](https://kiro.dev/docs/permissions/) · [CLI commands](https://kiro.dev/docs/reference/cli-commands/) · [Custom agents](https://kiro.dev/docs/custom-agents/creating/) · [Steering](https://kiro.dev/docs/steering)

---

## Devin

### Devin Config paths

| Scope | Path |
| --- | --- |
| User config | `~/.config/devin/config.json` |
| Project shared | `.devin/config.json` |
| Project local | `.devin/config.local.json` |
| User MCP | `~/.config/devin/mcp_config.json` |
| Project MCP | `.devin/mcp_config.json` |
| Enterprise | Machine-wide `system.json` (admin-managed) |
| User rules | `~/.config/devin/AGENTS.md` |
| Project rules | `AGENTS.md` |

### Devin Config format

```json
{
  "agent": { "model": "swe-1-6-fast" },
  "permissions": {
    "allow": ["Read(**)", "Exec(git)"],
    "deny": ["Exec(sudo)"],
    "ask": ["Write(**/.env*)"]
  },
  "sandbox": {
    "allowed_domains": [],
    "network_mode": "full"
  },
  "read_config_from": {
    "cursor": true, "windsurf": true, "claude": true
  }
}
```

### Devin Permissions

- **Modes:** Normal, Accept Edits, Smart, Bypass/YOLO, Autonomous (with sandbox)
- **Syntax:** `Read(glob)`, `Write(glob)`, `Exec(prefix)`, `Fetch(url-pattern)`, `mcp__server__tool`
- **Precedence:** Org → Session → Project local → Project → User
- **Deny wins over allow**

### Devin Rules

| Scope | Path |
| --- | --- |
| Global | `~/.config/devin/AGENTS.md` |
| Project | `AGENTS.md` |
| Local | `AGENTS.local.md` |
| Modular | `.devin/rules/*.md` (with `trigger` frontmatter) |
| Legacy | `.windsurfrules`, `CLAUDE.md`, `.cursor/rules/*.md` (via `read_config_from`) |

### Devin CLI

`devin`, `devin --sandbox`, `devin --permission-mode`, `devin mcp add`, `devin rules list`, `devin auth login`, `devin sandbox setup`

**Slash commands:** `/mode`, `/model`, `/config`, `/permissions`

**Sources:** [Config](https://docs.devin.ai/cli/reference/configuration/config-file) · [Permissions](https://docs.devin.ai/cli/reference/permissions) · [Commands](https://docs.devin.ai/cli/reference/commands) · [Rules](https://docs.devin.ai/cli/extensibility/rules)

---

## Antigravity (agy)

### Antigravity (agy) Config paths

| Scope | Path |
| --- | --- |
| User settings | `~/.gemini/antigravity-cli/settings.json` |
| User keybindings | `~/.gemini/antigravity-cli/keybindings.json` |
| User rules | `~/.gemini/GEMINI.md` |
| User MCP | `~/.gemini/config/mcp_config.json` |
| User skills | `~/.gemini/config/skills/` |
| Workspace rules | `<workspace>/.agents/rules/` |
| Workspace MCP | `<workspace>/.agents/mcp_config.json` |
| Workspace skills | `<workspace>/.agents/skills/` |
| Project config | `~/.gemini/config/projects/` |

### Antigravity (agy) Config format

```json
{
  "model": "Gemini 3.5 Flash (High)",
  "toolPermission": "request-review",
  "permissions": {
    "allow": ["command(git)", "command(npm test)"],
    "deny": ["command(rm -rf)", "command(sudo)"],
    "ask": ["command(*)"]
  },
  "enableTerminalSandbox": false
}
```

### Antigravity (agy) Permissions

- **Presets:** `request-review` (default), `proceed-in-sandbox`, `always-proceed`, `strict`
- **Actions:** `read_file`, `write_file`, `read_url`, `execute_url`, `command`, `unsandboxed`, `mcp`
- **Targets:** paths, globs, domains, command prefixes/regex, MCP server/tool
- **Precedence:** Deny > Ask > Allow
- **Write implies Read** on same path

### Antigravity (agy) Rules

| Scope | Path |
| --- | --- |
| Global | `~/.gemini/GEMINI.md` |
| Workspace | `.agents/rules/*.md` (or legacy `.agent/rules/`) |
| Activation | Manual, Always On, Model Decision, Glob |

**Related systems:**

- Workflows: `.agents/workflows/*.md` (invoked via `/workflow-name`)
- Skills: `.agents/skills/SKILL.md`

### Antigravity (agy) CLI

`agy`, `agy -p` (non-interactive), `agy --model`, `agy --sandbox`, `agy --dangerously-skip-permissions`, `agy models`, `agy agents`

**Slash commands:** `/config`, `/permissions`, `/model`, `/mcp`, `/skills`, `/agents`, `/resume`, `/rewind`

**Sources:** [Using](https://antigravity.google/docs/cli/using) · [Permissions](https://antigravity.google/docs/cli/permissions) · [Reference](https://antigravity.google/docs/cli/reference) · [Rules/workflows](https://antigravity.google/docs/rules-workflows)

---

## VS Code / GitHub Copilot

> **Status:** Deferred — listed for parity/tracking; no dedicated parser or auto-discovery
> yet. Instructions are plain Markdown and fall under the deferred Markdown sources.

### VS Code / GitHub Copilot Config paths

| Scope | Path |
| --- | --- |
| Project instructions | `.github/copilot-instructions.md` (repo root) |
| User/agent settings | VS Code `settings.json` (`github.copilot.*`, `chat.agents`) |
| Agent definitions | `.github/agents/*.md` (or `.github/chatmodes/*.chatmode.md`) |

### VS Code / GitHub Copilot Config format

Plain **Markdown** for instructions/agents. No structured permission model — VS Code
Copilot reads instructions and applies the host IDE's trust/sandbox settings. Chat agents
can be defined as Markdown with YAML frontmatter (name, description, tools, skills).

### VS Code / GitHub Copilot Rules

- **Instructions:** `.github/copilot-instructions.md` — project-level guidance, plain Markdown.
- **Agents:** `.github/agents/<name>.md` with frontmatter.
- **Chat modes:** `.github/chatmodes/*.chatmode.md`.

### VS Code / GitHub Copilot CLI

`code` (VS Code), `github-copilot` / `copilot` (CLI), `gh copilot`.

**Sources:** [Copilot overview](https://code.visualstudio.com/docs/copilot/overview) · [Agent skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) · [GitHub Copilot](https://github.com/features/copilot)

---

## Config format summary

| Format | Tools | Parser approach |
| --- | --- | --- |
| JSON/JSONC | Claude, Cursor, Paseo, Devin, Antigravity, Opencode, agy-acp | `dart:convert` + `json_ast` (preserves comments & trailing commas) |
| TOML | Codex | `toml` Dart package |
| YAML | Kiro (permissions), Paseo (hub/workflows) | `yaml` Dart package |
| Markdown | All tools' rules files (`.md`/`.mdc`/`.cursorrules`) — **deferred** (see below) | raw-text editor (planned) |

## Deferred / not yet supported

These sources are known but intentionally excluded from V1 auto-discovery until a
dedicated raw-text editor exists (see "Detection and Registry → Deferred Sources"):

- **Markdown rules** — `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, Kiro steering, Cursor `.mdc`
  (YAML frontmatter + markdown body), Codex `.rules`, Devin `.devin/rules/*.md`.
- **Starlark** — Codex command rules (`.codex/rules/*.rules`).
- **Plain text** — Cursor `.cursorrules` (deprecated).
- **VS Code / GitHub Copilot** — instructions live in `.github/copilot-instructions.md`
  (Markdown); not given a dedicated tool entry or parser yet. Tracked in the master plan
  under deferred-tools work.

Adding VS Code / GitHub Copilot as a first-class supported tool is tracked in the master plan.

## Permissions model taxonomy

| Model | Tools | Pattern |
| --- | --- | --- |
| Allow/Ask/Deny arrays | Claude, Antigravity | List of `Tool(pattern)` strings |
| Per-tool allow/ask/deny | Opencode | Object mapping tool → action |
| Capability-based | Kiro | `capability` + `effect` + `match` |
| Allowlist + classifier | Cursor | Static allowlist + LLM hints |
| Sandbox + profiles | Codex | Sandbox mode + named permission profiles |
| Scope-based | Devin | `Read/Write/Exec/Fetch(pattern)` |

## agy-acp

ACP (Agent Client Protocol) stdio adapter for Google's Antigravity CLI (`agy`). Bridges
`agy` into any ACP-compatible host (Zed, Paseo) by speaking JSON-RPC over stdin/stdout,
spawning `agy` as a subprocess, and streaming responses back as incremental updates.

**This is a custom fork** (`kgrizz-git/agy-acp`, branch `mine`) of
[`hicder/agy-acp`](https://github.com/hicder/agy-acp) that adds an ACP
permission-prompt bridge — the feature that distinguishes it from upstream.

### agy-acp Config paths

| Scope | Path |
| --- | --- |
| Session store | `~/.openab/agy-acp/sessions.json` |
| Session lock | `~/.openab/agy-acp/sessions.json.lock` |
| Permission bridge socket | `/tmp/agy-acp-perm-{PID}.sock` (Unix) |
| Private hooks dir | `/tmp/agy-acp-hooks-{PID}/.agents/hooks.json` (auto-created, deleted on Drop) |
| agy conversation DBs | `~/.gemini/antigravity-cli/conversations/*.db` |
| agy auth/settings | `~/.gemini/antigravity-cli/settings.json` |
| Zed host config | `~/.config/zed/settings.json` (`agent_servers` section) |

### agy-acp Config format

**Session store (`sessions.json`):**

```json
{
  "sessions": {
    "<acp-session-uuid>": {
      "conversation_id": "<agy-conversation-id> | null",
      "last_step_idx": 42,
      "model_id": "<model-name> | null"
    }
  }
}
```

**Zed `agent_servers` config:**

```json
{
  "agent_servers": {
    "agy": {
      "type": "custom",
      "command": "agy-acp",
      "args": ["--permission-prompts"],
      "env": {
        "AGY_ACP_AUTO_ALLOW": "ask_question,reads,searches"
      }
    }
  }
}
```

### agy-acp Permissions model

The fork's defining feature is a full permission bridge (1,135 lines in `permission.rs`).
When `--permission-prompts` is enabled:

1. Adapter starts a **Unix socket server** at `/tmp/agy-acp-perm-{PID}.sock`
2. Writes a `PreToolUse` hook into a private temp dir, passed to `agy` via `--add-dir`
3. `agy` runs with `--dangerously-skip-permissions` — the adapter becomes the sole gate
4. Hook subcommand connects to bridge socket, sends payload, receives decision
5. Bridge sends `session/request_permission` to ACP client with: **Allow**, **Always allow**, **Reject**, **Always reject**

**Auto-allow policy (`AGY_ACP_AUTO_ALLOW` env var):**

| Value | Effect |
| --- | --- |
| _(default)_ `ask_question` | Only model questions auto-allowed |
| `reads` | Adds `view_file`, `view_code_item`, `list_dir` |
| `searches` | Adds `grep_search`, `codebase_search`, `find_by_name` |
| `none` | Nothing auto-allowed |

**Hard limits (always apply):**

- Workspace boundary — absolute paths outside workspace root still prompt
- No network reads — `read_url_content` and `search_web` excluded
- Credential-looking paths always prompt (`.env`, `.pem`, `.key`, `id_rsa`, `.ssh/`, paths containing `token`, `secret`, `password`, `credential`)

**Sensitive patterns (`AGY_ACP_SENSITIVE_PATTERNS`):** comma-separated extra substrings added to the built-in denylist.

### agy-acp CLI

`agy-acp` — runs the adapter
`agy-acp permission-hook` — invoked by the PreToolUse hook subcommand

**Key flags:** `--permission-prompts` (enables the permission bridge)

**Key env vars:**

- `AGY_ACP_AUTO_ALLOW` — auto-allow policy
- `AGY_ACP_SENSITIVE_PATTERNS` — extra sensitive path patterns

**Source:** Local fork at `~/MyCode/agy-acp` (Rust, `permission.rs`, `adapter.rs`, `hook_root.rs`, `types.rs`)

---

## Detection and Registry

For auto-discovery, the app uses a pure-Dart `ToolDescriptor` registry located in `lib/catalog/tool_descriptor_registry.dart`.

### V1 Boundary

In Phase 1, only exact parser-supported structured config files are automatically discovered:

- **JSON/JSONC**
- **YAML**
- **TOML**

### Deferred Sources

Markdown rules, system prompts, glob-matched directories, and instruction sources (like `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.mdc` files) are explicitly deferred. They will not appear in sidebar discovery until a dedicated raw-text editor exists.
