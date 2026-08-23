import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final parser = JsonConfigParser();
  final adapter = ClaudeCodePermissionsAdapter();
  final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
    (item) => item.id == ToolId.claudeCode,
  );
  final discoveredConfig = DiscoveredConfig.fromPath(
    filePath: '/fixture/.claude/settings.json',
    descriptor: descriptor,
    scope: ConfigLocationScope.user,
    kind: ConfigSourceKind.structuredConfig,
    format: ConfigFormat.json,
    sourceLabel: 'Claude Code',
    fromCatalog: true,
  );

  ToolConfig parseFixture(String relativePath) {
    final content = File(p.join('test', 'fixtures', relativePath))
        .readAsStringSync();
    return parser.parse(
      content,
      filePath: discoveredConfig.filePath,
      toolName: 'Claude Code',
      format: ConfigFormat.json,
    );
  }

  group('Claude Code permission fixtures', () {
    test('staging fixtures cover complete and omitted optional fields', () {
      final complete = parseFixture('staging_home/.claude/settings.json');
      final omitted = parseFixture(
        'staging_home/workspace/.claude/settings.json',
      );

      expect(
        adapter
            .interpret(config: complete, discoveredConfig: discoveredConfig)
            .status,
        ClaudeCodePermissionsStatus.available,
      );
      expect(
        adapter
            .interpret(config: omitted, discoveredConfig: discoveredConfig)
            .status,
        ClaudeCodePermissionsStatus.available,
      );
    });

    test('extra documented permission setting stays unclassified', () {
      final config = parseFixture('edge_cases/claude_permissions_extra.json');
      final result = adapter.interpret(
        config: config,
        discoveredConfig: discoveredConfig,
      );

      expect(result.status, ClaudeCodePermissionsStatus.available);
      expect(result.presentation?.hasUnclassifiedSettings, isTrue);
    });

    test('invalid and mixed-type permission fixtures use the raw fallback', () {
      for (final path in [
        'edge_cases/claude_permissions_invalid.json',
        'edge_cases/claude_permissions_mixed_array.json',
      ]) {
        final result = adapter.interpret(
          config: parseFixture(path),
          discoveredConfig: discoveredConfig,
        );
        expect(result.status, ClaudeCodePermissionsStatus.unsupported);
      }
    });

    test('fixture without permissions does not opt into the card', () {
      final result = adapter.interpret(
        config: parseFixture(
          'edge_cases/claude_permissions_without_permissions.json',
        ),
        discoveredConfig: discoveredConfig,
      );

      expect(result.status, ClaudeCodePermissionsStatus.notApplicable);
    });

    test(
      'comment-bearing JSON retains raw content and warns about JSONC fallback',
      () {
        final config = parseFixture(
          'edge_cases/claude_permissions_comments.jsonc',
        );

        expect(config.parseWarnings, isNotEmpty);
        expect(config.originalContent, contains('A comment must remain'));
        expect(
          adapter
              .interpret(config: config, discoveredConfig: discoveredConfig)
              .status,
          ClaudeCodePermissionsStatus.available,
        );
      },
    );
  });
}
