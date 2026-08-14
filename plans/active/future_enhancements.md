# Future Enhancements

Status: active
Created: 2026-08-14

This document tracks broader ideas, ecosystem integrations, and high-level enhancements that fall outside the current phased implementation roadmap.

## 1. IDE Extensions

Develop dedicated plugins/extensions for major IDEs (e.g., VS Code, IntelliJ, Cursor).

- Allow users to manage their agent configurations directly from within their editor without switching to the standalone desktop app.
- Sync configurations between the IDE extension and the `~/AgentsConfigHelper/` template library.

## 2. In-App AI Assistant Integration

Integrate directly with user-provided AI providers (e.g., OpenAI, Anthropic, Google Gemini) via API keys.

- **Context-Aware Assistance:** Allow users to ask questions directly inside the app, automatically passing their current active agent configuration file as context.
- **Rule Generation:** Use the integrated AI to suggest or generate safe, secure rules and permissions based on a natural language prompt from the user (e.g., "Allow this agent to read from src but not write to tests").
- **Config Auditing:** Have the AI review a configuration file and flag potentially unsafe command permissions or over-scoped folder access.
