import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adapter = OpencodePermissionsAdapter();

  DiscoveredConfig opencodeConfig({
    ConfigLocationScope scope = ConfigLocationScope.user,
    bool fromCatalog = true,
    String filePath = '/fixture/.config/opencode/opencode.json',
    ConfigFormat format = ConfigFormat.jsonc,
    ConfigSourceKind kind = ConfigSourceKind.structuredConfig,
  }) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.opencode,
    );
    return DiscoveredConfig.fromPath(
      filePath: filePath,
      descriptor: descriptor,
      scope: scope,
      kind: kind,
      format: format,
      sourceLabel: 'Opencode',
      fromCatalog: fromCatalog,
    );
  }

  ToolConfig config(Map<String, Object?> rawSettings) {
    return ToolConfig(
      toolName: 'Opencode',
      filePath: '/fixture/.config/opencode/opencode.json',
      format: ConfigFormat.jsonc,
      rawSettings: rawSettings,
    );
  }

  OpencodePermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as OpencodePermissionsPresentation?;
  }

  group('OpencodePermissionsAdapter', () {
    test('keeps reviewed field help scoped to stored configuration', () {
      expect(
        OpencodePermissionsHelp.policy.description,
        contains('stored in the permission block'),
      );
      expect(
        OpencodePermissionsHelp.policy.description,
        contains('does not compute that effective policy'),
      );
      expect(
        OpencodePermissionsHelp.global.label,
        'Global',
      );
      expect(
        OpencodePermissionsHelp.toolPermission('bash').label,
        'bash',
      );
      expect(
        OpencodePermissionsHelp.toolPermission('bash').description,
        contains('last matching rule wins'),
      );
    });

    test('reads a scalar permission as the global action', () {
      final result = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.globalAction, 'allow');
      expect(presentationOf(result)?.tools, isEmpty);
      expect(presentationOf(result)?.hasConfiguredPermission, isTrue);
    });

    test(
      'parses an object with a wildcard, scalar tool, and granular tool',
      () {
        final result = adapter.interpret(
          config: config({
            'permission': {
              '*': 'ask',
              'bash': 'allow',
              'edit': {
                '*': 'deny',
                'packages/web/src/content/docs/*.mdx': 'allow',
              },
            },
          }),
          discoveredConfig: opencodeConfig(),
        );

        expect(result.status, PolicyCardStatus.available);
        expect(presentationOf(result)?.globalAction, 'ask');
        expect(presentationOf(result)?.tools['bash']?.action, 'allow');
        expect(presentationOf(result)?.tools['bash']?.patterns, isNull);
        expect(presentationOf(result)?.tools['edit']?.patterns, {
          '*': 'deny',
          'packages/web/src/content/docs/*.mdx': 'allow',
        });
        expect(presentationOf(result)?.tools['edit']?.action, isNull);
      },
    );

    test('applies to both user and project catalog scopes', () {
      final user = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(),
      );
      final project = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(
          filePath: '/fixture/.opencode/opencode.json',
          scope: ConfigLocationScope.project,
        ),
      );

      expect(user.status, PolicyCardStatus.available);
      expect(project.status, PolicyCardStatus.available);
    });

    test('an absent permission is a safe empty policy', () {
      final result = adapter.interpret(
        config: config({'model': 'fixture-model'}),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.hasConfiguredPermission, isFalse);
      expect(presentationOf(result)?.globalAction, isNull);
      expect(presentationOf(result)?.tools, isEmpty);
    });

    test('a present empty object is a configured empty policy', () {
      final result = adapter.interpret(
        config: config({'permission': <String, Object?>{}}),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.hasConfiguredPermission, isTrue);
      expect(presentationOf(result)?.globalAction, isNull);
      expect(presentationOf(result)?.tools, isEmpty);
    });

    test('does not present a card for an invalid scalar action', () {
      final result = adapter.interpret(
        config: config({'permission': 'maybe'}),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('permission'));
    });

    test('does not present a card for a null permission value', () {
      final result = adapter.interpret(
        config: config({'permission': null}),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('permission'));
    });

    test(
      'does not present a card for a wildcard that is not a scalar action',
      () {
        final result = adapter.interpret(
          config: config({
            'permission': {
              '*': {'*': 'allow'},
            },
          }),
          discoveredConfig: opencodeConfig(),
        );

        expect(result.status, PolicyCardStatus.unsupported);
        expect(result.presentation, isNull);
        expect(result.unsupportedReason, contains('*'));
      },
    );

    test('does not present a card for a malformed tool value', () {
      final nonAction = adapter.interpret(
        config: config({
          'permission': {'bash': 'always'},
        }),
        discoveredConfig: opencodeConfig(),
      );
      final nonMapOrString = adapter.interpret(
        config: config({
          'permission': {'bash': 5},
        }),
        discoveredConfig: opencodeConfig(),
      );

      expect(nonAction.status, PolicyCardStatus.unsupported);
      expect(nonAction.unsupportedReason, contains('bash'));
      expect(nonMapOrString.status, PolicyCardStatus.unsupported);
      expect(nonMapOrString.unsupportedReason, contains('bash'));
    });

    test(
      'does not present a card for a pattern map with a non-action value',
      () {
        final result = adapter.interpret(
          config: config({
            'permission': {
              'edit': {'*': 'maybe'},
            },
          }),
          discoveredConfig: opencodeConfig(),
        );

        expect(result.status, PolicyCardStatus.unsupported);
        expect(result.presentation, isNull);
        expect(result.unsupportedReason, contains('edit'));
      },
    );

    test('does not present a card for a non-String tool key', () {
      final result = adapter.interpret(
        config: config({
          'permission': <int, Object?>{1: 'allow'},
        }),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
    });

    test('does not present a card for a non-String pattern key', () {
      final result = adapter.interpret(
        config: config({
          'permission': {
            'bash': <int, Object?>{1: 'allow'},
          },
        }),
        discoveredConfig: opencodeConfig(),
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.presentation, isNull);
      expect(result.unsupportedReason, contains('bash'));
    });

    test('does not apply to a manually added Opencode path', () {
      final result = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(fromCatalog: false),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply when discovery is absent', () {
      final result = adapter.interpret(
        config: config({'permission': 'allow'}),
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
        format: ConfigFormat.jsonc,
        sourceLabel: 'Claude Code',
        fromCatalog: true,
      );

      final result = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: claudeConfig,
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to a non-opencode.json basename', () {
      final result = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(
          filePath: '/fixture/.config/opencode/other.json',
        ),
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });

    test('does not apply to a target with another format or kind', () {
      final json = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(format: ConfigFormat.json),
      );
      final instruction = adapter.interpret(
        config: config({'permission': 'allow'}),
        discoveredConfig: opencodeConfig(
          kind: ConfigSourceKind.instructionDocument,
        ),
      );

      expect(json.status, PolicyCardStatus.notApplicable);
      expect(instruction.status, PolicyCardStatus.notApplicable);
    });
  });
}
