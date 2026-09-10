import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final parser = JsonConfigParser();
  final adapter = OpencodePermissionsAdapter();

  OpencodePermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as OpencodePermissionsPresentation?;
  }

  final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
    (item) => item.id == ToolId.opencode,
  );
  final discoveredConfig = DiscoveredConfig.fromPath(
    filePath: '/fixture/.config/opencode/opencode.json',
    descriptor: descriptor,
    scope: ConfigLocationScope.user,
    kind: ConfigSourceKind.structuredConfig,
    format: ConfigFormat.jsonc,
    sourceLabel: 'Opencode',
    fromCatalog: true,
  );

  ToolConfig parseFixture(String relativePath) {
    final content = File(p.join('test', 'fixtures', relativePath))
        .readAsStringSync();
    return parser.parse(
      content,
      filePath: discoveredConfig.filePath,
      toolName: 'Opencode',
      format: ConfigFormat.jsonc,
    );
  }

  PolicyCardSelection interpret(ToolConfig config) {
    return adapter.interpret(
      config: config,
      discoveredConfig: discoveredConfig,
    );
  }

  group('Opencode permission fixtures', () {
    test('a scalar permission fixture sets the global action', () {
      final result = interpret(
        parseFixture('edge_cases/opencode_permission_global.json'),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.globalAction, 'allow');
      expect(presentationOf(result)?.hasConfiguredPermission, isTrue);
    });

    test('an object fixture parses wildcard, scalar, and granular tools', () {
      final result = interpret(
        parseFixture('edge_cases/opencode_permission_object.json'),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.globalAction, 'ask');
      expect(presentationOf(result)?.tools['bash']?.action, 'allow');
      expect(presentationOf(result)?.tools['edit']?.patterns, {
        '*': 'deny',
        'packages/web/src/content/docs/*.mdx': 'allow',
      });
    });

    test('a malformed scalar action is unsupported', () {
      final result = interpret(
        parseFixture('edge_cases/opencode_permission_malformed.json'),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('permission'));
    });

    test('a null permission and a non-object permission are unsupported', () {
      final nullPermission = interpret(
        parseFixture('edge_cases/opencode_permission_null.json'),
      );
      final arrayPermission = interpret(
        parseFixture('edge_cases/opencode_permission_array.json'),
      );

      for (final result in [nullPermission, arrayPermission]) {
        expect(result.status, PolicyCardStatus.unsupported);
        expect(result.presentation, isNull);
      }
    });

    test('a JSONC fixture parses as JSONC and stays available', () {
      final config = parseFixture(
        'edge_cases/opencode_permission_comments.jsonc',
      );
      final result = interpret(config);

      expect(result.status, PolicyCardStatus.available);
      expect(config.parseWarnings, isNotEmpty);
      expect(config.parsedAsJsonc, isTrue);
      expect(
        config.originalContent,
        contains('// A token-free Opencode fixture.'),
      );
      expect(presentationOf(result)?.tools['bash']?.action, 'allow');
    });

    test('a .json Opencode file parsed as JSONC opens with a JSONC notice', () {
      final config = parseFixture(
        'edge_cases/opencode_permission_comments.jsonc',
      );
      final assessment = const FidelityAssessor().assessOpening(
        format: config.format,
        filePath: '/fixture/.config/opencode/opencode.json',
        rawOnly: false,
        parsedAsJsonc: config.parsedAsJsonc,
      );

      expect(assessment, isNotNull);
      expect(assessment?.formatLabel, 'JSONC');
    });
  });
}
