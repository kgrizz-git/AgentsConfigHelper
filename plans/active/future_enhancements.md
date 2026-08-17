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

**Secret handling and consent (required before any provider integration):**

- Rules, config contents, or logs sent to external providers must first undergo redaction of API keys, tokens, and other secrets (e.g., `AWS_*`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, bearer tokens) before leaving the machine.
- Providers must be invoked only after explicit user consent per session/request, with a clear indication of what data is being shared and with which provider.
- Define and document a retention policy: what payloads are stored (locally or by the provider), for how long, and how users can request deletion.
