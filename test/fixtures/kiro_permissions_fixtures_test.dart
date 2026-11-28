import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:agents_config_helper/schemas/kiro_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final adapter = KiroPermissionsAdapter();
  final parser = YamlConfigParser();
  final fixtureRoot = p.join(
    Directory.current.path,
    'test',
    'fixtures',
  );
  final stagingPath = p.join(
    fixtureRoot,
    'staging_home',
    '.kiro',
    'settings',
    'permissions.yaml',
  );
  final edgeRoot = p.join(fixtureRoot, 'edge_cases');

  String readFixture(String path) => File(path).readAsStringSync();

  ToolConfig parseFixture(String path) {
    return parser.parse(
      readFixture(path),
      filePath: path,
      toolName: 'Kiro',
      format: ConfigFormat.yaml,
    );
  }

  PolicyCardSelection selectionFor(ToolConfig config) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.kiro,
    );
    final discovered = DiscoveredConfig.fromPath(
      filePath: '/fixture/.kiro/settings/permissions.yaml',
      descriptor: descriptor,
      scope: ConfigLocationScope.user,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.yaml,
      sourceLabel: 'Kiro',
      fromCatalog: true,
    );
    return adapter.interpret(
      config: config,
      discoveredConfig: discovered,
    );
  }

  KiroPermissionsPresentation? presentationOf(PolicyCardSelection selection) {
    return selection.presentation as KiroPermissionsPresentation?;
  }

  String edgeFixture(String name) => p.join(edgeRoot, name);

  group('Kiro permission fixtures', () {
    test('the staging fixture is a valid Kiro example', () {
      final selection = selectionFor(parseFixture(stagingPath));

      expect(selection.status, PolicyCardStatus.available);
      final presentation = presentationOf(selection)!;
      expect(presentation.rules, hasLength(4));
      expect(
        presentation.rules.map((rule) => rule.effect),
        containsAll(['allow', 'deny', 'ask', 'evaluate']),
      );
      expect(
        presentation.rules.first.match,
        ['git *', 'npm *'],
      );
      expect(
        presentation.rules.first.exclude,
        ['git push *'],
      );
      expect(presentation.rules[2].match, isNull);
      expect(presentation.hasUnclassifiedSettings, isFalse);
    });

    test('all documented effects and meta-capabilities parse', () {
      final selection = selectionFor(
        parseFixture(edgeFixture('kiro_permissions_all_effects.yaml')),
      );

      expect(selection.status, PolicyCardStatus.available);
      final rules = presentationOf(selection)!.rules;
      expect(
        rules.map((rule) => rule.capability),
        ['all', 'builtin', 'filesystem', 'sandbox_network'],
      );
      expect(
        rules.map((rule) => rule.effect),
        ['deny', 'ask', 'allow', 'evaluate'],
      );
    });

    test('empty and absent rules are available empty states', () {
      final empty = selectionFor(
        parseFixture(edgeFixture('kiro_permissions_empty.yaml')),
      );
      final absent = selectionFor(
        parseFixture(edgeFixture('kiro_permissions_absent_rules.yaml')),
      );

      expect(empty.status, PolicyCardStatus.available);
      expect(presentationOf(empty)!.rules, isEmpty);
      expect(presentationOf(empty)!.hasUnclassifiedSettings, isFalse);
      expect(absent.status, PolicyCardStatus.available);
      expect(presentationOf(absent)!.rules, isEmpty);
      expect(presentationOf(absent)!.hasUnclassifiedSettings, isTrue);
    });

    test('policies and a valid rules list remain available with a notice', () {
      final selection = selectionFor(
        parseFixture(edgeFixture('kiro_permissions_policies.yaml')),
      );

      expect(selection.status, PolicyCardStatus.available);
      expect(presentationOf(selection)!.rules, hasLength(1));
      expect(presentationOf(selection)!.hasUnclassifiedSettings, isTrue);
    });

    test('malformed fixtures are unsupported', () {
      const malformed = [
        'kiro_permissions_non_list_rules.yaml',
        'kiro_permissions_null_rules.yaml',
        'kiro_permissions_non_map_rule.yaml',
        'kiro_permissions_missing_capability.yaml',
        'kiro_permissions_missing_effect.yaml',
        'kiro_permissions_unknown_capability.yaml',
        'kiro_permissions_unknown_effect.yaml',
        'kiro_permissions_scalar_match.yaml',
        'kiro_permissions_non_string_match.yaml',
        'kiro_permissions_unknown_rule_key.yaml',
      ];

      for (final name in malformed) {
        final selection = selectionFor(parseFixture(edgeFixture(name)));
        expect(
          selection.status,
          PolicyCardStatus.unsupported,
          reason: name,
        );
        expect(selection.presentation, isNull, reason: name);
        expect(
          selection.suppressGenericRulesSection,
          isTrue,
          reason: name,
        );
      }
    });

    test('the valid staging fixture round-trips without changing bytes', () {
      final original = readFixture(stagingPath);
      final config = parseFixture(stagingPath);

      final outcome = parser.serializeWithOutcome(
        config,
        originalContent: original,
      );

      expect(outcome.usedFallback, isFalse);
      expect(outcome.content, original);
      expect(outcome.content, contains('- capability: shell'));
      expect(outcome.content, contains('effect: evaluate'));
    });

    test('all Kiro fixtures contain no secret-like content', () {
      final files = <File>[
        File(stagingPath),
        ...Directory(edgeRoot)
            .listSync()
            .whereType<File>()
            .where((file) => p.basename(file.path).startsWith('kiro_')),
      ];
      final secretLike = RegExp(
        r'(api[_-]?key|secret|password|bearer\s+|sk-[A-Za-z0-9]{8,})',
        caseSensitive: false,
      );

      for (final file in files) {
        final content = file.readAsStringSync();
        expect(
          secretLike.hasMatch(content),
          isFalse,
          reason: file.path,
        );
      }
    });
  });
}
