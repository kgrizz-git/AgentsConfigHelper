import 'package:agents_config_helper/catalog/registry_path_matching.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';

export 'package:agents_config_helper/catalog/registry_path_matching.dart'
    show RegistryMatchResult, ValidationException;

/// Registry of all supported tool configurations for discovery.
class ToolDescriptorRegistry {
  /// The catalog of supported tool descriptors in order.
  static const List<ToolDescriptor> catalog = [
    ToolDescriptor(
      id: ToolId.claudeCode,
      displayName: 'Claude Code',
      targets: [
        ConfigTarget(
          relativePath: '.claude/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.claude/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.claude/CLAUDE.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'CLAUDE.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.claude/CLAUDE.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.codex,
      displayName: 'Codex',
      targets: [
        ConfigTarget(
          relativePath: '.codex/config.toml',
          format: ConfigFormat.toml,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.codex/config.toml',
          format: ConfigFormat.toml,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.codex/rules/default.rules',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.codex/rules/*.rules',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.codex/AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.opencode,
      displayName: 'Opencode',
      targets: [
        ConfigTarget(
          relativePath: '.config/opencode/opencode.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.opencode/opencode.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.config/opencode/AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.paseo,
      displayName: 'Paseo',
      targets: [
        ConfigTarget(
          relativePath: '.paseo/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: 'paseo.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.cursorIde,
      displayName: 'Cursor IDE',
      targets: [
        ConfigTarget(
          relativePath: 'Library/Application Support/Cursor/User/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.config/Cursor/User/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: 'AppData/Roaming/Cursor/User/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cursor/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.cursor,
      displayName: 'Cursor Agent',
      targets: [
        ConfigTarget(
          relativePath: '.cursor/permissions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cursor/permissions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cursorrules',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.cursor/rules/*.mdc',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'CLAUDE.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.kiro,
      displayName: 'Kiro',
      targets: [
        ConfigTarget(
          relativePath: '.kiro/settings/permissions.yaml',
          format: ConfigFormat.yaml,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.kiro/steering/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.devin,
      displayName: 'Devin',
      targets: [
        ConfigTarget(
          relativePath: '.devin/rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.config/devin/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.devin/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.config/devin/AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.antigravityIde,
      displayName: 'Antigravity IDE',
      targets: [
        ConfigTarget(
          relativePath: '.gemini/antigravity-ide/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.antigravityApp,
      displayName: 'Antigravity App',
      targets: [
        ConfigTarget(
          relativePath: '.gemini/antigravity-app/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.antigravity,
      displayName: 'Antigravity CLI',
      targets: [
        ConfigTarget(
          relativePath: '.gemini/antigravity-cli/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.gemini/GEMINI.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'GEMINI.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.agents/rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.agyAcp,
      displayName: 'Agy-ACP',
      targets: [
        ConfigTarget(
          relativePath: '.openab/agy-acp/sessions.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.kilo,
      displayName: 'Kilo',
      targets: [
        ConfigTarget(
          relativePath: '.config/kilo/kilo.jsonc',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.config/kilo/kilo.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        // Optional/legacy cache file; may be absent on current installs.
        // Secrets more commonly live in kilo.jsonc (provider apiKey) —
        // backups for all of these still go to the app support directory.
        ConfigTarget(
          relativePath: '.config/kilo/models.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.config/kilo/AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.config/kilo/agents/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'kilo.jsonc',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: 'kilo.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.kilo/kilo.jsonc',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.kilo/kilo.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.kilo/agents/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.cline,
      displayName: 'Cline',
      targets: [
        ConfigTarget(
          relativePath: '.cline/data/settings/global-settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cline/data/settings/cline_mcp_settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cline/data/settings/providers.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.cline/rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.clinerules',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        // Official primary workspace rules layout is a directory of
        // .md/.txt files (see docs.cline.bot/customization/cline-rules).
        ConfigTarget(
          relativePath: '.clinerules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.clinerules/*.txt',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.cline/rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        // Compatibility paths documented by Cline for global rules.
        // Documents/Cline/Rules is primary; ~/Cline/Rules is only discovered
        // when that Documents location is absent (see DiscoveryRequest).
        ConfigTarget(
          relativePath: 'Documents/Cline/Rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'Documents/Cline/Rules/*.txt',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        // Linux/WSL fallback when Documents/Cline/Rules is absent.
        ConfigTarget(
          relativePath: 'Cline/Rules/*.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'Cline/Rules/*.txt',
          format: ConfigFormat.text,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.lmStudio,
      displayName: 'LM Studio',
      targets: [
        ConfigTarget(
          relativePath: '.lmstudio/settings.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        // Hub layout is publisher/model-name (two path segments), e.g.
        // .lmstudio/hub/models/bytedance/seed-oss-36b/model.yaml.
        ConfigTarget(
          relativePath: '.lmstudio/hub/models/*/*/model.yaml',
          format: ConfigFormat.yaml,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.lmstudio/hub/models/*/*/manifest.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.lmstudio/hub/presets/*.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
      ],
    ),
    ToolDescriptor(
      id: ToolId.copilot,
      displayName: 'GitHub Copilot',
      targets: [
        // Editable CLI settings (JSONC). Both this and config.json are
        // discovered when present; this is the user-editable settings file.
        ConfigTarget(
          relativePath: '.copilot/settings.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        // Managed CLI application state (auth, plugins). Surfaced for
        // visibility alongside settings.json — not a precedence/hide rule.
        ConfigTarget(
          relativePath: '.copilot/config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.copilot/mcp-config.json',
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.copilot/copilot-instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.copilot/instructions/**/*.instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.github/copilot/settings.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.github/copilot/settings.local.json',
          format: ConfigFormat.jsonc,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.structuredConfig,
        ),
        ConfigTarget(
          relativePath: '.github/copilot-instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.github/instructions/**/*.instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath:
              '.config/github-copilot/intellij/global-copilot-instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: 'AppData/Local/github-copilot/intellij/global-copilot-instructions.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
    // Cross-tool [agents.md](https://agents.md/) convention — not owned by
    // any single agent. Tool-specific copies (e.g. ~/.codex/AGENTS.md) stay
    // on those tools' descriptors.
    ToolDescriptor(
      id: ToolId.agentsMd,
      displayName: 'AGENTS.md (shared)',
      targets: [
        ConfigTarget(
          relativePath: 'AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.project,
          kind: ConfigSourceKind.instructionDocument,
        ),
        ConfigTarget(
          relativePath: '.agents/AGENTS.md',
          format: ConfigFormat.markdown,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
        ),
      ],
    ),
  ];

  /// Returns the descriptor for the given [id], or null if not found.
  static ToolDescriptor? getById(ToolId id) {
    for (final descriptor in catalog) {
      if (descriptor.id == id) return descriptor;
    }
    return null;
  }

  /// See [RegistryPathMatching.isMatch].
  static bool isMatch(String expectedPattern, String actualNormalizedPath) =>
      RegistryPathMatching.isMatch(expectedPattern, actualNormalizedPath);

  /// See [RegistryPathMatching.matchPath].
  static RegistryMatchResult matchPath(
    String normalizedAbsolutePath, {
    String? normalizedHomePath,
    List<String> normalizedProjectRoots = const [],
    String? normalizedCopilotHomePath,
    bool enableClineRulesFallback = true,
  }) => RegistryPathMatching.matchPath(
    normalizedAbsolutePath,
    catalog: catalog,
    normalizedHomePath: normalizedHomePath,
    normalizedProjectRoots: normalizedProjectRoots,
    normalizedCopilotHomePath: normalizedCopilotHomePath,
    enableClineRulesFallback: enableClineRulesFallback,
  );
}
