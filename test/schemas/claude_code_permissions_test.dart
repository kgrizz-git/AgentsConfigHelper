import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adapter = ClaudeCodePermissionsAdapter();

  DiscoveredConfig claudeConfig({
    ConfigLocationScope scope = ConfigLocationScope.user,
    bool fromCatalog = true,
  }) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.claudeCode,
    );
    return DiscoveredConfig.fromPath(
      filePath: '/fixture/.claude/settings.json',
      descriptor: descriptor,
      scope: scope,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.json,
      sourceLabel: 'Claude Code',
      fromCatalog: fromCatalog,
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

  group('ClaudeCodePermissionsAdapter', () {
    test('reads validated nested values from raw settings', () {
      final result = adapter.interpret(
        config: config({
          'permissions': {
            'defaultMode': 'default',
            'allow': ['Read(./fixtures/**)'],
            'ask': ['Bash(git status)'],
            'deny': ['Read(./private/**)'],
          },
        }),
        discoveredConfig: claudeConfig(),
      );

      expect(result.status, ClaudeCodePermissionsStatus.available);
      expect(result.presentation?.defaultMode, 'default');
      expect(result.presentation?.allow, ['Read(./fixtures/**)']);
      expect(result.presentation?.ask, ['Bash(git status)']);
      expect(result.presentation?.deny, ['Read(./private/**)']);
      expect(
        () => result.presentation!.allow.add('Write(./fixtures/**)'),
        throwsUnsupportedError,
      );
    });

    test('reports documented but unclassified sibling settings', () {
      final result = adapter.interpret(
        config: config({
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
            'disableBypassPermissionsMode': 'disable',
          },
        }),
        discoveredConfig: claudeConfig(),
      );

      expect(result.status, ClaudeCodePermissionsStatus.available);
      expect(result.presentation?.hasUnclassifiedSettings, isTrue);
    });

    test('does not present a partial card for invalid recognized values', () {
      final result = adapter.interpret(
        config: config({
          'permissions': {
            'allow': ['Read(./fixtures/**)', 5],
          },
        }),
        discoveredConfig: claudeConfig(),
      );

      expect(result.status, ClaudeCodePermissionsStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('allow'));
    });

    test(
      'presents an empty policy for Claude settings without permissions',
      () {
        final result = adapter.interpret(
          config: config({'model': 'fixture-model'}),
          discoveredConfig: claudeConfig(),
        );

        expect(result.status, ClaudeCodePermissionsStatus.available);
        expect(result.presentation?.hasConfiguredPolicy, isFalse);
        expect(result.presentation?.allow, isEmpty);
      },
    );

    test('does not apply to manually added Claude paths', () {
      final result = adapter.interpret(
        config: config({
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
          },
        }),
        discoveredConfig: claudeConfig(fromCatalog: false),
      );

      expect(result.status, ClaudeCodePermissionsStatus.notApplicable);
    });

    test('does not apply to a different tool descriptor', () {
      final cursorDescriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.cursor,
      );
      final cursorConfig = DiscoveredConfig.fromPath(
        filePath: '/fixture/.cursor/permissions.json',
        descriptor: cursorDescriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Cursor Agent',
        fromCatalog: true,
      );

      final result = adapter.interpret(
        config: config({
          'permissions': {
            'allow': ['Read(./fixtures/**)'],
          },
        }),
        discoveredConfig: cursorConfig,
      );

      expect(result.status, ClaudeCodePermissionsStatus.notApplicable);
    });
  });
}
