# Phase 10: New Tools Discovery Paths

**Date:** 2026-08-19

## Kilo

- **Global Config:** `~/.config/kilo/kilo.jsonc` (Windows: `%USERPROFILE%\.config\kilo\kilo.jsonc`)
- **Global Models/Providers:** `~/.config/kilo/models.json` (Stores custom API keys, base URLs, and model definitions)
- **Global Rules:** `~/.config/kilo/AGENTS.md` and `~/.config/kilo/agents/*.md`
- **Project Config:** `kilo.jsonc` or `.kilo/kilo.jsonc`
- **Project Rules:** `AGENTS.md`

## Cline

- **Global Settings/API:** `~/.cline/data/settings/` (Specifically `global-settings.json`, `cline_mcp_settings.json`, and `providers.json`)
- **Global Rules:** `~/.cline/rules/`
- **Project Rules:** `.clinerules` and `.cline/rules/*.md`

## LM Studio

- **Global Settings:** `~/.lmstudio/settings.json` (Windows: `%USERPROFILE%\.lmstudio\settings.json`)
- **Model Metadata:** `~/.lmstudio/hub/models/` (Stores `model.yaml` and `manifest.json` for model configurations, separate from weights)
- **Presets:** `~/.lmstudio/hub/presets/`

## GitHub Copilot

- **Copilot CLI:** `~/.copilot/config.json` and `mcp-config.json` (Windows: `%USERPROFILE%\.copilot\`)
- **VS Code Extension:** Managed via `settings.json`. No default global instructions file exists (relies on project-level `.github/copilot-instructions.md`).
- **JetBrains Plugin:**
  - macOS/Linux: `~/.config/github-copilot/intellij/global-copilot-instructions.md`
  - Windows: `%LOCALAPPDATA%\github-copilot\intellij\global-copilot-instructions.md`
