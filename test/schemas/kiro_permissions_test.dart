import 'dart:convert';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/kiro_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adapter = KiroPermissionsAdapter();

  const allCapabilities = [
    'fs_read',
    'fs_write',
    'shell',
    'web_fetch',
    'web_search',
    'mcp',
    'subagent',
    'skill',
    'power',
    'context',
    'diagnostics',
    'sandbox_network',
    'all',
    'builtin',
    'filesystem',
  ];

  DiscoveredConfig kiroConfig({
    ConfigLocationScope scope = ConfigLocationScope.user,
    bool fromCatalog = true,
    String filePath = '/fixture/.kiro/settings/permissions.yaml',
    ConfigFormat format = ConfigFormat.yaml,
    ConfigSourceKind kind = ConfigSourceKind.structuredConfig,
    ToolId toolId = ToolId.kiro,
  }) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == toolId,
    );
    return DiscoveredConfig.fromPath(
      filePath: filePath,
      descriptor: descriptor,
      scope: scope,
      kind: kind,
      format: format,
      sourceLabel: 'Kiro',
      fromCatalog: fromCatalog,
    );
  }

  ToolConfig config(
    Map<String, Object?> rawSettings, {
    ConfigFormat format = ConfigFormat.yaml,
  }) {
    return ToolConfig(
      toolName: 'Kiro',
      filePath: '/fixture/.kiro/settings/permissions.yaml',
      format: format,
      rawSettings: rawSettings,
    );
  }

  KiroPermissionsPresentation? presentationOf(PolicyCardSelection selection) {
    return selection.presentation as KiroPermissionsPresentation?;
  }

  group('KiroPermissionsAdapter', () {
    test('keeps reviewed help scoped to stored configuration', () {
      expect(
        KiroPermissionsHelp.policy.description,
        contains('stored in this Kiro permissions.yaml file'),
      );
      expect(
        KiroPermissionsHelp.policy.description,
        contains('does not compute the effective policy'),
      );
      expect(
        KiroPermissionsHelp.rule.description,
        contains("not Kiro's effective decision"),
      );
      expect(
        KiroPermissionsHelp.capability('fs_read').label,
        'Filesystem read',
      );
      expect(
        KiroPermissionsHelp.effect('evaluate').description,
        contains('weakest effect'),
      );
      expect(
        KiroPermissionsHelp.match.description,
        contains('Stored glob patterns'),
      );
      expect(
        KiroPermissionsHelp.exclude.description,
        contains('must not match'),
      );
      expect(
        KiroPermissionsAdapter.documentationUri,
        Uri.parse(
          'https://kiro.dev/docs/permissions/',
        ),
      );
    });

    test('applies only to the catalog-discovered Kiro user target', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'shell', 'effect': 'allow'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(result.adapterId, KiroPermissionsAdapter.adapterId);
      expect(result.suppressGenericRulesSection, isTrue);
    });

    test('does not apply to a manually added Kiro path', () {
      final result = adapter.interpret(
        config: config(const {}),
        discoveredConfig: kiroConfig(fromCatalog: false),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
      expect(result.suppressGenericRulesSection, isFalse);
    });

    test('does not apply when discovery is absent', () {
      final result = adapter.interpret(
        config: config(const {}),
        discoveredConfig: null,
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to a different tool descriptor', () {
      final result = adapter.interpret(
        config: config(const {}),
        discoveredConfig: kiroConfig(toolId: ToolId.claudeCode),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to the wrong scope, format, or kind', () {
      final project = adapter.interpret(
        config: config(const {}),
        discoveredConfig: kiroConfig(scope: ConfigLocationScope.project),
      );
      final json = adapter.interpret(
        config: config(const {}),
        discoveredConfig: kiroConfig(format: ConfigFormat.json),
      );
      final configJson = adapter.interpret(
        config: config(const {}, format: ConfigFormat.json),
        discoveredConfig: kiroConfig(),
      );
      final instruction = adapter.interpret(
        config: config(const {}),
        discoveredConfig: kiroConfig(
          kind: ConfigSourceKind.instructionDocument,
        ),
      );

      expect(project.status, PolicyCardStatus.notApplicable);
      expect(json.status, PolicyCardStatus.notApplicable);
      expect(configJson.status, PolicyCardStatus.notApplicable);
      expect(instruction.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to near-miss paths', () {
      final paths = [
        '/fixture/.kiro/settings/nested/permissions.yaml',
        '/fixture/.kiro/other/permissions.yaml',
        '/fixture/other/settings/permissions.yaml',
        '/fixture/.kiro2/settings/permissions.yaml',
        '/fixture/.kiro/settings/other.yaml',
        '/fixture/.kiro/settings/permissions.yaml.bak',
      ];

      for (final path in paths) {
        final result = adapter.interpret(
          config: config(const {}),
          discoveredConfig: kiroConfig(filePath: path),
        );
        expect(
          result.status,
          PolicyCardStatus.notApplicable,
          reason: path,
        );
      }
    });

    test('parses every documented capability', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            for (final capability in allCapabilities)
              {'capability': capability, 'effect': 'allow'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(
        presentationOf(result)?.rules.map((rule) => rule.capability),
        allCapabilities,
      );
    });

    test('parses every documented effect', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            for (final effect in ['deny', 'ask', 'allow', 'evaluate'])
              {'capability': 'shell', 'effect': effect},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(
        presentationOf(result)?.rules.map((rule) => rule.effect),
        ['deny', 'ask', 'allow', 'evaluate'],
      );
    });

    test('keeps rule order and duplicate rules as written', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            {
              'capability': 'shell',
              'effect': 'allow',
              'match': ['git *', 'npm *'],
              'exclude': ['git push *'],
            },
            {
              'capability': 'shell',
              'effect': 'allow',
              'match': ['git *', 'npm *'],
              'exclude': ['git push *'],
            },
            {'capability': 'fs_read', 'effect': 'deny'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      final rules = presentationOf(result)!.rules;
      expect(rules, hasLength(3));
      expect(rules[0], rules[1]);
      expect(rules[2].capability, 'fs_read');
      expect(rules[2].match, isNull);
      expect(rules[2].exclude, isNull);
    });

    test('preserves omitted versus explicitly empty pattern lists', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            {
              'capability': 'shell',
              'effect': 'allow',
              'match': <Object?>[],
              'exclude': <Object?>[],
            },
            {'capability': 'fs_read', 'effect': 'deny'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      final rules = presentationOf(result)!.rules;
      expect(rules[0].match, isEmpty);
      expect(rules[0].exclude, isEmpty);
      expect(rules[1].match, isNull);
      expect(rules[1].exclude, isNull);
    });

    test('treats absent and empty rules as an available empty state', () {
      final absent = adapter.interpret(
        config: config({'model': 'fixture-model'}),
        discoveredConfig: kiroConfig(),
      );
      final empty = adapter.interpret(
        config: config({'rules': <Object?>[]}),
        discoveredConfig: kiroConfig(),
      );

      expect(absent.status, PolicyCardStatus.available);
      expect(presentationOf(absent)?.rules, isEmpty);
      expect(presentationOf(absent)?.hasUnclassifiedSettings, isTrue);
      expect(empty.status, PolicyCardStatus.available);
      expect(presentationOf(empty)?.rules, isEmpty);
      expect(presentationOf(empty)?.hasUnclassifiedSettings, isFalse);
    });

    test('treats an explicit null rules value as unsupported', () {
      final result = adapter.interpret(
        config: config({'rules': null}),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.suppressGenericRulesSection, isTrue);
      expect(result.unsupportedReason, contains('rules'));
    });

    test('treats a non-list rules value as unsupported', () {
      final result = adapter.interpret(
        config: config({'rules': 'not-a-list'}),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.unsupportedReason, contains('not a list'));
      expect(result.suppressGenericRulesSection, isTrue);
    });

    test('rejects a non-map rule entry with its one-based index', () {
      final result = adapter.interpret(
        config: config({
          'rules': ['shell'],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.unsupportedReason, contains('rule 1'));
      expect(result.unsupportedReason, contains('not a map'));
    });

    test('rejects missing or unknown capabilities and effects', () {
      final missingCapability = adapter.interpret(
        config: config({
          'rules': [
            {'effect': 'allow'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );
      final missingEffect = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'shell'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );
      final unknownCapability = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'network', 'effect': 'allow'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );
      final unknownEffect = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'shell', 'effect': 'permit'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      for (final selection in [
        missingCapability,
        missingEffect,
        unknownCapability,
        unknownEffect,
      ]) {
        expect(selection.status, PolicyCardStatus.unsupported);
        expect(selection.presentation, isNull);
        expect(selection.suppressGenericRulesSection, isTrue);
      }
      expect(missingCapability.unsupportedReason, contains('capability'));
      expect(missingEffect.unsupportedReason, contains('effect'));
      expect(unknownCapability.unsupportedReason, contains('capability'));
      expect(unknownEffect.unsupportedReason, contains('effect'));
    });

    test('rejects unknown rule keys', () {
      final result = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'shell', 'effect': 'allow', 'mode': 'strict'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.unsupportedReason, contains('unknown key "mode"'));

      final emptyKey = adapter.interpret(
        config: config({
          'rules': [
            {'capability': 'shell', 'effect': 'allow', '': 'strict'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(emptyKey.status, PolicyCardStatus.unsupported);
      expect(emptyKey.unsupportedReason, contains('unknown key'));
    });

    test('rejects scalar and non-string pattern lists', () {
      final scalarMatch = adapter.interpret(
        config: config({
          'rules': [
            {
              'capability': 'shell',
              'effect': 'allow',
              'match': 'git *',
            },
          ],
        }),
        discoveredConfig: kiroConfig(),
      );
      final nonStringMatch = adapter.interpret(
        config: config({
          'rules': [
            {
              'capability': 'shell',
              'effect': 'allow',
              'match': ['git *', 42],
            },
          ],
        }),
        discoveredConfig: kiroConfig(),
      );
      final scalarExclude = adapter.interpret(
        config: config({
          'rules': [
            {
              'capability': 'shell',
              'effect': 'allow',
              'exclude': 'git push *',
            },
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      for (final selection in [scalarMatch, nonStringMatch, scalarExclude]) {
        expect(selection.status, PolicyCardStatus.unsupported);
        expect(selection.unsupportedReason, contains('must be a list'));
      }
    });

    test('shows valid rules with unknown top-level settings and policies', () {
      final result = adapter.interpret(
        config: config({
          'policies': ['read-workspace'],
          'model': 'fixture-model',
          'rules': [
            {'capability': 'fs_read', 'effect': 'allow'},
          ],
        }),
        discoveredConfig: kiroConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.rules, hasLength(1));
      expect(presentationOf(result)?.hasUnclassifiedSettings, isTrue);
    });

    test('does not mutate the raw settings map', () {
      final raw = <String, Object?>{
        'policies': ['read-workspace'],
        'rules': [
          {
            'capability': 'shell',
            'effect': 'allow',
            'match': ['git *'],
            'exclude': ['git push *'],
          },
        ],
      };
      final before = jsonEncode(raw);

      adapter.interpret(config: config(raw), discoveredConfig: kiroConfig());

      expect(jsonEncode(raw), before);
    });

    test('defaults the generic Rules suppression flag to false', () {
      const selection = PolicyCardSelection(
        adapterId: 'other.adapter',
        status: PolicyCardStatus.available,
      );

      expect(selection.suppressGenericRulesSection, isFalse);
    });

    test('includes the generic Rules suppression flag in equality', () {
      const shown = PolicyCardSelection(
        adapterId: KiroPermissionsAdapter.adapterId,
        status: PolicyCardStatus.available,
      );
      const suppressed = PolicyCardSelection(
        adapterId: KiroPermissionsAdapter.adapterId,
        status: PolicyCardStatus.available,
        suppressGenericRulesSection: true,
      );

      expect(shown, isNot(equals(suppressed)));
    });
  });
}
