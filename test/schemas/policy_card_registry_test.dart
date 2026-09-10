import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/schemas/policy_card_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePresentation extends PolicyCardPresentation {
  const _FakePresentation();

  @override
  List<Object?> get props => [];
}

class _AlwaysAvailableAdapter implements PolicyCardAdapter {
  _AlwaysAvailableAdapter(this.adapterId);

  final String adapterId;

  @override
  String get id => adapterId;

  @override
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    return PolicyCardSelection(
      adapterId: adapterId,
      status: PolicyCardStatus.available,
      presentation: const _FakePresentation(),
    );
  }
}

void main() {
  DiscoveredConfig claudeConfig({bool fromCatalog = true}) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.claudeCode,
    );
    return DiscoveredConfig.fromPath(
      filePath: '/fixture/.claude/settings.json',
      descriptor: descriptor,
      scope: ConfigLocationScope.user,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.json,
      sourceLabel: 'Claude Code',
      fromCatalog: fromCatalog,
    );
  }

  DiscoveredConfig cursorConfig() {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.cursor,
    );
    return DiscoveredConfig.fromPath(
      filePath: '/fixture/.cursor/permissions.json',
      descriptor: descriptor,
      scope: ConfigLocationScope.user,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.json,
      sourceLabel: 'Cursor Agent',
      fromCatalog: true,
    );
  }

  DiscoveredConfig opencodeConfig() {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.opencode,
    );
    return DiscoveredConfig.fromPath(
      filePath: '/fixture/.config/opencode/opencode.json',
      descriptor: descriptor,
      scope: ConfigLocationScope.user,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.jsonc,
      sourceLabel: 'Opencode',
      fromCatalog: true,
    );
  }

  DiscoveredConfig codexConfig() {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.codex,
    );
    return DiscoveredConfig.fromPath(
      filePath: '/fixture/.codex/config.toml',
      descriptor: descriptor,
      scope: ConfigLocationScope.user,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.toml,
      sourceLabel: 'Codex',
      fromCatalog: true,
    );
  }

  ToolConfig config(Map<String, Object?> rawSettings) {
    return ToolConfig(
      toolName: 'Claude Code',
      filePath: '/fixture/.claude/settings.json',
      format: ConfigFormat.json,
      rawSettings: rawSettings,
    );
  }

  group('PolicyCardRegistry', () {
    test(
      'returns the Claude selection for a catalog-discovered Claude '
      'settings config',
      () {
        final registry = PolicyCardRegistry([ClaudeCodePermissionsAdapter()]);

        final selection = registry.select(
          config: config({
            'permissions': {
              'allow': ['Read(./fixtures/**)'],
            },
          }),
          discoveredConfig: claudeConfig(),
        );

        expect(selection.status, PolicyCardStatus.available);
        expect(selection.adapterId, ClaudeCodePermissionsAdapter.adapterId);
        expect(
          selection.presentation,
          isA<ClaudeCodePermissionsPresentation>(),
        );
      },
    );

    test(
      'returns a notApplicable sentinel when no adapter matches',
      () {
        final registry = PolicyCardRegistry([ClaudeCodePermissionsAdapter()]);
        final rawSettings = {
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
          },
        };

        final selections = [
          registry.select(
            config: config(rawSettings),
            discoveredConfig: claudeConfig(fromCatalog: false),
          ),
          registry.select(
            config: config(rawSettings),
            discoveredConfig: cursorConfig(),
          ),
          registry.select(config: config(rawSettings), discoveredConfig: null),
        ];

        for (final selection in selections) {
          expect(selection.status, PolicyCardStatus.notApplicable);
          expect(selection.adapterId, PolicyCardRegistry.noAdapterId);
          expect(selection.isAvailable, isFalse);
          expect(selection.isUnsupported, isFalse);
          expect(selection.presentation, isNull);
          expect(selection.unsupportedReason, isNull);
        }
      },
    );

    test('returns the first registered match', () {
      final registry = PolicyCardRegistry([
        _AlwaysAvailableAdapter('first.adapter'),
        _AlwaysAvailableAdapter('second.adapter'),
      ]);

      final selection = registry.select(
        config: config(const {}),
        discoveredConfig: claudeConfig(),
      );

      expect(selection.status, PolicyCardStatus.available);
      expect(selection.adapterId, 'first.adapter');
    });

    test('delegates interpretation to the Claude adapter unchanged', () {
      final adapter = ClaudeCodePermissionsAdapter();
      final registry = PolicyCardRegistry([adapter]);
      final toolConfig = config({
        'permissions': {
          'defaultMode': 'default',
          'allow': ['Read(./fixtures/**)'],
        },
      });
      final discovered = claudeConfig();

      final viaRegistry = registry.select(
        config: toolConfig,
        discoveredConfig: discovered,
      );
      final direct = adapter.interpret(
        config: toolConfig,
        discoveredConfig: discovered,
      );

      expect(viaRegistry, direct);
      expect(
        viaRegistry.adapterId,
        ClaudeCodePermissionsAdapter.adapterId,
      );
      expect(viaRegistry.status, PolicyCardStatus.available);
    });

    test(
      'resolves a Cursor config to the Cursor adapter when both are '
      'registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
        ]);
        final cursor = cursorConfig();
        final toolConfig = ToolConfig(
          toolName: 'Cursor Agent',
          filePath: cursor.filePath,
          format: ConfigFormat.json,
          rawSettings: const {
            'mcpAllowlist': ['github:*'],
          },
        );

        final selection = registry.select(
          config: toolConfig,
          discoveredConfig: cursor,
        );

        expect(selection.status, PolicyCardStatus.available);
        expect(selection.adapterId, CursorPermissionsAdapter.adapterId);
        expect(selection.presentation, isA<CursorPermissionsPresentation>());
      },
    );

    test(
      'resolves a Claude config to Claude even when the Cursor adapter is '
      'registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
        ]);
        final claude = claudeConfig();
        final toolConfig = config({
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
          },
        });

        final selection = registry.select(
          config: toolConfig,
          discoveredConfig: claude,
        );

        expect(selection.status, PolicyCardStatus.available);
        expect(selection.adapterId, ClaudeCodePermissionsAdapter.adapterId);
        expect(
          selection.presentation,
          isA<ClaudeCodePermissionsPresentation>(),
        );
      },
    );

    test(
      'resolves an Opencode config to the Opencode adapter when all three '
      'are registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
          OpencodePermissionsAdapter(),
        ]);
        final opencode = opencodeConfig();
        final toolConfig = ToolConfig(
          toolName: 'Opencode',
          filePath: opencode.filePath,
          format: ConfigFormat.jsonc,
          rawSettings: const {
            'permission': 'allow',
          },
        );

        final selection = registry.select(
          config: toolConfig,
          discoveredConfig: opencode,
        );

        expect(selection.status, PolicyCardStatus.available);
        expect(selection.adapterId, OpencodePermissionsAdapter.adapterId);
        expect(
          selection.presentation,
          isA<OpencodePermissionsPresentation>(),
        );
      },
    );

    test(
      'resolves Claude and Cursor configs even when the Opencode adapter '
      'is registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
          OpencodePermissionsAdapter(),
        ]);
        final claude = claudeConfig();
        final claudeToolConfig = config({
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
          },
        });
        final claudeSelection = registry.select(
          config: claudeToolConfig,
          discoveredConfig: claude,
        );

        expect(
          claudeSelection.adapterId,
          ClaudeCodePermissionsAdapter.adapterId,
        );
        expect(
          claudeSelection.presentation,
          isA<ClaudeCodePermissionsPresentation>(),
        );

        final cursor = cursorConfig();
        final cursorToolConfig = ToolConfig(
          toolName: 'Cursor Agent',
          filePath: cursor.filePath,
          format: ConfigFormat.json,
          rawSettings: const {
            'mcpAllowlist': ['github:*'],
          },
        );
        final cursorSelection = registry.select(
          config: cursorToolConfig,
          discoveredConfig: cursor,
        );

        expect(cursorSelection.adapterId, CursorPermissionsAdapter.adapterId);
        expect(
          cursorSelection.presentation,
          isA<CursorPermissionsPresentation>(),
        );
      },
    );

    test(
      'resolves a Codex config to the Codex adapter when all four '
      'are registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
          OpencodePermissionsAdapter(),
          CodexPermissionsAdapter(),
        ]);
        final codex = codexConfig();
        final toolConfig = ToolConfig(
          toolName: 'Codex',
          filePath: codex.filePath,
          format: ConfigFormat.toml,
          rawSettings: const {
            'sandbox_mode': 'workspace-write',
          },
        );

        final selection = registry.select(
          config: toolConfig,
          discoveredConfig: codex,
        );

        expect(selection.status, PolicyCardStatus.available);
        expect(selection.adapterId, CodexPermissionsAdapter.adapterId);
        expect(
          selection.presentation,
          isA<CodexPermissionsPresentation>(),
        );
      },
    );

    test(
      'resolves Claude, Cursor, and Opencode configs even when the Codex '
      'adapter is registered',
      () {
        final registry = PolicyCardRegistry([
          ClaudeCodePermissionsAdapter(),
          CursorPermissionsAdapter(),
          OpencodePermissionsAdapter(),
          CodexPermissionsAdapter(),
        ]);
        final codex = codexConfig();
        final codexRulesConfig = ToolConfig(
          toolName: 'Codex',
          filePath: '/fixture/.codex/rules/default.rules',
          format: ConfigFormat.text,
        );
        final codexRules = DiscoveredConfig.fromPath(
          filePath: '/fixture/.codex/rules/default.rules',
          descriptor: ToolDescriptorRegistry.catalog.firstWhere(
            (item) => item.id == ToolId.codex,
          ),
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.instructionDocument,
          format: ConfigFormat.text,
          sourceLabel: 'Codex',
          fromCatalog: true,
        );

        final declined = registry.select(
          config: codexRulesConfig,
          discoveredConfig: codexRules,
        );
        expect(
          declined.adapterId,
          PolicyCardRegistry.noAdapterId,
        );

        final codexToolConfig = ToolConfig(
          toolName: 'Codex',
          filePath: codex.filePath,
          format: ConfigFormat.toml,
        );
        final empty = registry.select(
          config: codexToolConfig,
          discoveredConfig: codex,
        );
        expect(empty.adapterId, CodexPermissionsAdapter.adapterId);
      },
    );
  });
}
