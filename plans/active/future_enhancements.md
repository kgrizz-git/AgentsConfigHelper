# Future Enhancements

Status: active
Created: 2026-08-14

This document tracks broader ideas, ecosystem integrations, and high-level enhancements that fall outside the current phased implementation roadmap.

## Discovery-expansion candidates

These candidates are not agent/IDE tools, but may have useful project- or user-level config
files the app could discover and edit (raw text, YAML, JSON, or TOML as appropriate). Research
exact paths and formats before adding `ToolId`s; prefer files users actually edit over generated
CI caches.

### GitHub Actions, workflows, and repository automation

- GitHub Actions workflows — `.github/workflows/*.{yml,yaml}` (CI, release, PR checks). Decide
  whether each workflow is its own sidebar entry or is grouped under one “GitHub Actions” tool.
- Dependabot — `.github/dependabot.yml` / `.github/dependabot.yaml`.
- Common `.github/` configs — e.g. `CODEOWNERS`, `FUNDING.yml`, `ISSUE_TEMPLATE/`,
  `PULL_REQUEST_TEMPLATE*`, `labeler.yml`, and actionlint config. Pick a small high-value subset
  rather than every file under `.github/`.
- Renovate — `renovate.json`, `.github/renovate.json`, `renovate.json5` (if dependency-bot parity
  is a product goal).

### Code quality, security, and documentation platforms

Add first-class discovery only where there is a durable on-disk config; skip pure SaaS UI settings
with no repository or user-level file.

- SonarQube / SonarCloud — `sonar-project.properties`; scanner keys embedded in Gradle, Maven, or
  CI environment may remain docs-only.
- CodeRabbit — `.coderabbit.yaml`.
- Qodo / PR-Agent — `.pr_agent.toml` and successor Qodo config names.
- DeepSource — `.deepsource.toml`.
- Semgrep — `.semgrep.yml` / `.semgrep.yaml`, `.semgrep/` rule packs; workflow wrappers belong
  with GitHub Actions if that tool is added.
- CodeQL — `.github/codeql/codeql-config.yml` and related query-suite configs.
- Mintlify — `docs.json` / `mint.json`.
- Other common adjacent configs to evaluate — `codecov.yml` / `.codecov.yml`,
  `.pre-commit-config.yaml` (if not already discoverable), `.mdlrc` / `.markdownlint.yaml`, and
  `actionlint.yaml` — only when they fit the product story.

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
