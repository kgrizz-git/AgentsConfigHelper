import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adapter = CursorPermissionsAdapter();

  DiscoveredConfig cursorConfig({
    ConfigLocationScope scope = ConfigLocationScope.user,
    bool fromCatalog = true,
    String filePath = '/fixture/.cursor/permissions.json',
    ConfigFormat format = ConfigFormat.json,
    ConfigSourceKind kind = ConfigSourceKind.structuredConfig,
  }) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.cursor,
    );
    return DiscoveredConfig.fromPath(
      filePath: filePath,
      descriptor: descriptor,
      scope: scope,
      kind: kind,
      format: format,
      sourceLabel: 'Cursor Agent',
      fromCatalog: fromCatalog,
    );
  }

  ToolConfig config(Map<String, Object?> rawSettings) {
    return ToolConfig(
      toolName: 'Cursor Agent',
      filePath: '/fixture/.cursor/permissions.json',
      format: ConfigFormat.json,
      rawSettings: rawSettings,
    );
  }

  CursorPermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as CursorPermissionsPresentation?;
  }

  group('CursorPermissionsAdapter', () {
    test('keeps reviewed field help scoped to stored configuration', () {
      expect(
        CursorPermissionsHelp.policy.description,
        contains('stored'),
      );
      expect(
        CursorPermissionsHelp.policy.description,
        contains('does not compute that effective policy'),
      );
      expect(
        CursorPermissionsHelp.mcpAllowlist.description,
        'Lists MCP server:tool patterns declared in this file. Cursor decides '
        'how these match MCP calls at runtime.',
      );
      expect(
        CursorPermissionsHelp.terminalAllowlist.description,
        'Lists terminal command or prefix patterns declared in this file. '
        'Cursor decides how these match terminal commands at runtime.',
      );
      expect(
        CursorPermissionsHelp.allowInstructions.description,
        contains('Auto-review'),
      );
      expect(
        CursorPermissionsHelp.blockInstructions.description,
        contains('Auto-review'),
      );
    });

    test('reads validated values from the top-level policy object', () {
      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*', 'linear:list_issues'],
          'terminalAllowlist': ['git'],
          'autoRun': {
            'allow_instructions': ['Read-only inspections are fine.'],
            'block_instructions': ['Pause delete operations for review.'],
          },
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(
        presentationOf(result)?.mcpAllowlist,
        ['github:*', 'linear:list_issues'],
      );
      expect(presentationOf(result)?.terminalAllowlist, ['git']);
      expect(
        presentationOf(result)?.allowInstructions,
        ['Read-only inspections are fine.'],
      );
      expect(
        presentationOf(result)?.blockInstructions,
        ['Pause delete operations for review.'],
      );
      expect(presentationOf(result)?.hasUnclassifiedSettings, isFalse);
      expect(
        () => presentationOf(result)!.mcpAllowlist!.add('other:*'),
        throwsUnsupportedError,
      );
    });

    test('applies to both user and project catalog scopes', () {
      final user = adapter.interpret(
        config: config({
          'terminalAllowlist': ['git'],
        }),
        discoveredConfig: cursorConfig(),
      );
      final project = adapter.interpret(
        config: config({
          'terminalAllowlist': ['git'],
        }),
        discoveredConfig: cursorConfig(scope: ConfigLocationScope.project),
      );

      expect(user.status, PolicyCardStatus.available);
      expect(project.status, PolicyCardStatus.available);
    });

    test('preserves omitted versus explicitly empty fields', () {
      final omitted = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: cursorConfig(),
      );
      final explicitEmpty = adapter.interpret(
        config: config({
          'mcpAllowlist': <String>[],
          'terminalAllowlist': ['git'],
          'autoRun': {
            'allow_instructions': <String>[],
            'block_instructions': <String>[],
          },
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(presentationOf(omitted)?.terminalAllowlist, isNull);
      expect(presentationOf(omitted)?.mcpAllowlist, ['github:*']);
      expect(presentationOf(omitted)?.allowInstructions, isNull);
      expect(presentationOf(omitted)?.blockInstructions, isNull);

      expect(presentationOf(explicitEmpty)?.mcpAllowlist, isEmpty);
      expect(presentationOf(explicitEmpty)?.allowInstructions, isEmpty);
      expect(presentationOf(explicitEmpty)?.blockInstructions, isEmpty);
      expect(presentationOf(explicitEmpty)?.terminalAllowlist, ['git']);
    });

    test('an empty object is a valid empty policy', () {
      final result = adapter.interpret(
        config: config({}),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.mcpAllowlist, isNull);
      expect(presentationOf(result)?.terminalAllowlist, isNull);
      expect(presentationOf(result)?.allowInstructions, isNull);
      expect(presentationOf(result)?.blockInstructions, isNull);
      expect(presentationOf(result)?.hasUnclassifiedSettings, isFalse);
    });

    test('reports unknown siblings as unclassified but stays available', () {
      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
          'autoRun': {
            'allow_instructions': ['ok'],
            'someFutureKey': 'x',
          },
          'unknownTopLevel': 1,
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.hasUnclassifiedSettings, isTrue);
    });

    test('does not present a partial card for a non-list recognized field', () {
      final result = adapter.interpret(
        config: config({'mcpAllowlist': 'github:*'}),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('mcpAllowlist'));
    });

    test('does not present a card for a list with a non-string entry', () {
      final result = adapter.interpret(
        config: config({
          'terminalAllowlist': ['git', 5],
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('terminalAllowlist'));
    });

    test('does not present a card for an autoRun that is not a Map', () {
      final result = adapter.interpret(
        config: config({'autoRun': 'not-a-map'}),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('autoRun'));
    });

    test('rejects a malformed autoRun subfield as unsupported', () {
      final result = adapter.interpret(
        config: config({
          'autoRun': {'allow_instructions': 'nope'},
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
    });

    test('rejects a non-String autoRun sub-key as unsupported', () {
      final result = adapter.interpret(
        config: config({
          'autoRun': <int, Object?>{1: 'x'},
        }),
        discoveredConfig: cursorConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
    });

    test('does not apply to a manually added Cursor path', () {
      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: cursorConfig(fromCatalog: false),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply when discovery is absent', () {
      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: null,
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to a different tool descriptor', () {
      final claudeDescriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.claudeCode,
      );
      final claudeConfig = DiscoveredConfig.fromPath(
        filePath: '/fixture/.claude/settings.json',
        descriptor: claudeDescriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Claude Code',
        fromCatalog: true,
      );

      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: claudeConfig,
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to a different Cursor structured-JSON target', () {
      final result = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: cursorConfig(
          filePath: '/fixture/.cursor/mcp.json',
        ),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test(
      'does not apply to a near-miss path outside the .cursor directory',
      () {
        final result = adapter.interpret(
          config: config({
            'mcpAllowlist': ['github:*'],
          }),
          discoveredConfig: cursorConfig(
            filePath: '/fixture/workspace.cursor/permissions.json',
          ),
        );

        expect(result.status, PolicyCardStatus.notApplicable);
      },
    );

    test('does not apply to a Cursor target with another format or kind', () {
      final yaml = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: cursorConfig(format: ConfigFormat.yaml),
      );
      final instruction = adapter.interpret(
        config: config({
          'mcpAllowlist': ['github:*'],
        }),
        discoveredConfig: cursorConfig(
          kind: ConfigSourceKind.instructionDocument,
        ),
      );

      expect(yaml.status, PolicyCardStatus.notApplicable);
      expect(instruction.status, PolicyCardStatus.notApplicable);
    });
  });
}
