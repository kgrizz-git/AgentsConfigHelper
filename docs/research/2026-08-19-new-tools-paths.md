# Phase 10: New Tools Discovery Paths

**Date:** 2026-08-19 (updated 2026-08-20 after review)

## Kilo

- **Global Config:** `~/.config/kilo/kilo.jsonc` or `kilo.json` (Windows: `%USERPROFILE%\.config\kilo\`)
- **Global Models cache (optional/legacy):** `~/.config/kilo/models.json` — may be absent on current installs; not the primary credentials store
- **Secrets note:** Official docs warn that `provider.*.options.apiKey` (and similar) can appear in `kilo.jsonc`. Prefer env vars for credentials. Never commit config that contains secrets.
- **Global Rules / agents:** `~/.config/kilo/AGENTS.md` and `~/.config/kilo/agents/*.md`
- **Project Config:** `kilo.jsonc` / `kilo.json`, or `.kilo/kilo.jsonc` / `.kilo/kilo.json` (`.kilo/` wins if both exist)
- **Project agents:** `.kilo/agents/*.md`
- **Project Rules:** root `AGENTS.md` is registered under the shared **AGENTS.md (shared)**
  catalog entry (not under Kilo), because Codex, Opencode, Cursor, Kiro, Devin, Kilo, and
  Cline all load it. Tool-specific copies stay on each tool (e.g. `~/.config/kilo/AGENTS.md`).

## Cline

- **Global Settings/API:** `~/.cline/data/settings/` — specifically `global-settings.json`, `cline_mcp_settings.json`, and `providers.json` (providers often holds API keys)
- **Global Rules:** `~/.cline/rules/`, `~/Documents/Cline/Rules/`, and Linux/WSL
  fallback `~/Cline/Rules/`
- **Project Rules (primary):** `.clinerules/` directory of `.md` / `.txt` files
- **Project Rules (legacy/alternate):** `.clinerules` file and `.cline/rules/*.md`

## LM Studio

- **Global Settings:** `~/.lmstudio/settings.json` (Windows: `%USERPROFILE%\.lmstudio\settings.json`)
- **Model Metadata (hub):** `~/.lmstudio/hub/models/<publisher>/<model>/model.yaml` and `manifest.json` (two path segments under `models/`; weights live separately under `~/.lmstudio/models/` and are intentionally not discovered)
- **Presets:** `~/.lmstudio/hub/presets/*.json`

## GitHub Copilot

- **Copilot CLI editable settings:** `~/.copilot/settings.json` (Windows: `%USERPROFILE%\.copilot\`);
  when `COPILOT_HOME` is set, that directory replaces `~/.copilot` for CLI user files
  (`settings.json`, `config.json`, `mcp-config.json`, personal instructions)
- **Copilot CLI managed state:** `~/.copilot/config.json` (auth/plugins; also
  discovered when present — user-editable settings live in `settings.json`;
  older user settings migrate to `settings.json`)
- **Copilot CLI MCP:** `~/.copilot/mcp-config.json`
- **CLI personal instructions:** `~/.copilot/copilot-instructions.md` and
  `~/.copilot/instructions/**/*.instructions.md`
- **Repo/project settings:** `.github/copilot/settings.json` and
  `.github/copilot/settings.local.json` (personal; gitignore)
- **Project instructions:** `.github/copilot-instructions.md` and
  `.github/instructions/**/*.instructions.md`
- **Shared AGENTS.md:** project `AGENTS.md` and `~/.agents/AGENTS.md` (catalog entry
  `AGENTS.md (shared)`)
- **VS Code Extension:** Managed via `settings.json` (not a dedicated auto-discovered instructions file beyond project `.github/` paths).
- **JetBrains Plugin:**
  - macOS/Linux: `~/.config/github-copilot/intellij/global-copilot-instructions.md`
  - Windows: `%LOCALAPPDATA%\github-copilot\intellij\global-copilot-instructions.md` (registered as `AppData/Local/...` under the user home, matching the Cursor IDE Windows path pattern)

## Secret-bearing backup policy

All backups created by `BackupService` are written exclusively under the app support
`backups/` directory — never as sibling `.bak` files next to the original. This is
mandatory for secret-bearing configs (Cline `providers.json`, Kilo `kilo.jsonc` with
inline API keys, optional `models.json`, Copilot MCP configs, etc.) so project trees
never gain commit-able backup artifacts.

## Hook Integration Note

No `.pre-commit-config.yaml` changes are needed for the new tools. Existing tools like
`gitleaks` correctly scan all repo content automatically. Combined with the global-only
backup policy above, secret-bearing configs edited through this app do not bleed into
git history via `.bak` siblings. The standard gitleaks hook remains sufficient without
path-specific exemptions.
