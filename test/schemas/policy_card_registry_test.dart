import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
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
  });
}
