import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final parser = JsonConfigParser();
  final adapter = CursorPermissionsAdapter();

  CursorPermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as CursorPermissionsPresentation?;
  }

  final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
    (item) => item.id == ToolId.cursor,
  );
  final discoveredConfig = DiscoveredConfig.fromPath(
    filePath: '/fixture/.cursor/permissions.json',
    descriptor: descriptor,
    scope: ConfigLocationScope.user,
    kind: ConfigSourceKind.structuredConfig,
    format: ConfigFormat.json,
    sourceLabel: 'Cursor Agent',
    fromCatalog: true,
  );

  ToolConfig parseFixture(String relativePath) {
    final content = File(p.join('test', 'fixtures', relativePath))
        .readAsStringSync();
    return parser.parse(
      content,
      filePath: discoveredConfig.filePath,
      toolName: 'Cursor Agent',
      format: ConfigFormat.json,
    );
  }

  PolicyCardSelection interpret(ToolConfig config) {
    return adapter.interpret(
      config: config,
      discoveredConfig: discoveredConfig,
    );
  }

  group('Cursor permissions fixtures', () {
    test('user and project fixtures parse into an available presentation', () {
      final user = interpret(
        parseFixture('cursor_home/.cursor/permissions.json'),
      );
      final project = interpret(
        parseFixture('cursor_home/workspace/.cursor/permissions.json'),
      );

      expect(user.status, PolicyCardStatus.available);
      expect(
        presentationOf(user)?.mcpAllowlist,
        ['github:*', 'linear:list_issues'],
      );
      expect(presentationOf(user)?.terminalAllowlist, ['git', 'npm']);
      expect(
        presentationOf(user)?.allowInstructions,
        ['Read-only inspections are fine.'],
      );
      expect(
        presentationOf(user)?.blockInstructions,
        ['Pause delete operations for review.'],
      );

      expect(project.status, PolicyCardStatus.available);
      expect(presentationOf(project)?.terminalAllowlist, ['cargo build']);
      expect(presentationOf(project)?.mcpAllowlist, isNull);
      expect(presentationOf(project)?.allowInstructions, isNull);
    });

    test('a JSONC fixture parses as JSONC and stays available', () {
      final config = parseFixture(
        'edge_cases/cursor_permissions_comments.jsonc',
      );
      final result = interpret(config);

      expect(result.status, PolicyCardStatus.available);
      expect(config.parseWarnings, isNotEmpty);
      expect(config.parsedAsJsonc, isTrue);
      expect(
        config.originalContent,
        contains('// MCP servers allowed by this project.'),
      );
      expect(
        presentationOf(result)?.mcpAllowlist,
        ['github:*', 'linear:list_issues'],
      );
      expect(presentationOf(result)?.terminalAllowlist, ['git', 'npm']);
    });

    test('an explicitly empty field and an empty object are valid states', () {
      final explicitEmpty = interpret(
        parseFixture('edge_cases/cursor_permissions_explicit_empty.json'),
      );
      final empty = interpret(
        parseFixture('edge_cases/cursor_permissions_empty.json'),
      );

      expect(explicitEmpty.status, PolicyCardStatus.available);
      expect(presentationOf(explicitEmpty)?.mcpAllowlist, isEmpty);
      expect(presentationOf(explicitEmpty)?.terminalAllowlist, ['git']);
      expect(presentationOf(explicitEmpty)?.allowInstructions, isEmpty);
      expect(presentationOf(explicitEmpty)?.blockInstructions, isEmpty);

      expect(empty.status, PolicyCardStatus.available);
      expect(presentationOf(empty)?.mcpAllowlist, isNull);
      expect(presentationOf(empty)?.terminalAllowlist, isNull);
      expect(presentationOf(empty)?.hasUnclassifiedSettings, isFalse);
    });

    test('unknown siblings stay available but are reported unclassified', () {
      final result = interpret(
        parseFixture('edge_cases/cursor_permissions_unknown_siblings.json'),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.hasUnclassifiedSettings, isTrue);
    });

    test('malformed recognized fields are unsupported (raw-editor-first)', () {
      final nonList = interpret(
        parseFixture('edge_cases/cursor_permissions_non_list.json'),
      );
      final mixedArray = interpret(
        parseFixture('edge_cases/cursor_permissions_mixed_array.json'),
      );
      final autoRunNotMap = interpret(
        parseFixture('edge_cases/cursor_permissions_auto_run_not_map.json'),
      );
      final malformedSubfield = interpret(
        parseFixture('edge_cases/cursor_permissions_malformed_subfield.json'),
      );

      for (final result in [
        nonList,
        mixedArray,
        autoRunNotMap,
        malformedSubfield,
      ]) {
        expect(result.status, PolicyCardStatus.unsupported);
        expect(result.presentation, isNull);
      }
    });

    test('a .json Cursor file parsed as JSONC opens with a JSONC notice', () {
      final config = parseFixture(
        'edge_cases/cursor_permissions_comments.jsonc',
      );
      final assessment = const FidelityAssessor().assessOpening(
        format: config.format,
        filePath: '/fixture/.cursor/permissions.json',
        rawOnly: false,
        parsedAsJsonc: config.parsedAsJsonc,
      );

      expect(assessment, isNotNull);
      expect(assessment?.formatLabel, 'JSONC');
    });
  });
}
