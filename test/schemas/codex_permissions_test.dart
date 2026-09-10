import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adapter = CodexPermissionsAdapter();

  DiscoveredConfig codexConfig({
    ConfigLocationScope scope = ConfigLocationScope.user,
    bool fromCatalog = true,
    String filePath = '/fixture/.codex/config.toml',
    ConfigFormat format = ConfigFormat.toml,
    ConfigSourceKind kind = ConfigSourceKind.structuredConfig,
  }) {
    final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
      (item) => item.id == ToolId.codex,
    );
    return DiscoveredConfig.fromPath(
      filePath: filePath,
      descriptor: descriptor,
      scope: scope,
      kind: kind,
      format: format,
      sourceLabel: 'Codex',
      fromCatalog: fromCatalog,
    );
  }

  ToolConfig config(
    Map<String, Object?> rawSettings, {
    ConfigFormat format = ConfigFormat.toml,
  }) {
    return ToolConfig(
      toolName: 'Codex',
      filePath: '/fixture/.codex/config.toml',
      format: format,
      rawSettings: rawSettings,
    );
  }

  CodexPermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as CodexPermissionsPresentation?;
  }

  group('CodexPermissionsAdapter', () {
    test('keeps reviewed help scoped to stored configuration', () {
      expect(CodexPermissionsHelp.policy.description, contains('stored'));
      expect(
        CodexPermissionsHelp.policy.description,
        contains('does not compute that effective policy'),
      );
      expect(
        CodexPermissionsHelp.network.description,
        contains('does not check enforcement'),
      );
      expect(
        CodexPermissionsHelp.profile('x').description,
        contains('never resolved here'),
      );
    });

    test('matches user and project catalog targets', () {
      for (final scope in [
        ConfigLocationScope.user,
        ConfigLocationScope.project,
      ]) {
        final result = adapter.interpret(
          config: config({'sandbox_mode': 'workspace-write'}),
          discoveredConfig: codexConfig(scope: scope),
        );
        expect(result.status, PolicyCardStatus.available);
        expect(result.adapterId, CodexPermissionsAdapter.adapterId);
      }
    });

    test('declines other tools, manual paths, and non-TOML formats', () {
      final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.cursor,
      );
      final otherTool = DiscoveredConfig.fromPath(
        filePath: '/fixture/.cursor/permissions.json',
        descriptor: descriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Cursor Agent',
        fromCatalog: true,
      );
      expect(
        adapter
            .interpret(
              config: config({}, format: ConfigFormat.json),
              discoveredConfig: otherTool,
            )
            .status,
        PolicyCardStatus.notApplicable,
      );
      expect(
        adapter
            .interpret(
              config: config({'sandbox_mode': 'workspace-write'}),
              discoveredConfig: codexConfig(fromCatalog: false),
            )
            .status,
        PolicyCardStatus.notApplicable,
      );
      expect(
        adapter
            .interpret(
              config: config(
                {'sandbox_mode': 'workspace-write'},
                format: ConfigFormat.json,
              ),
              discoveredConfig: codexConfig(format: ConfigFormat.json),
            )
            .status,
        PolicyCardStatus.notApplicable,
      );
    });

    test('declines profile files, other basenames, and near-miss paths', () {
      for (final filePath in [
        '/fixture/.codex/dev.config.toml',
        '/fixture/.codex/other.toml',
        '/fixture/workspace.codex/config.toml',
        '/etc/codex/config.toml',
      ]) {
        expect(
          adapter
              .interpret(
                config: config({'sandbox_mode': 'workspace-write'}),
                discoveredConfig: codexConfig(filePath: filePath),
              )
              .status,
          PolicyCardStatus.notApplicable,
          reason: filePath,
        );
      }
    });

    test('declines sibling Codex catalog targets', () {
      expect(
        adapter
            .interpret(
              config: config({'sandbox_mode': 'workspace-write'}),
              discoveredConfig: codexConfig(
                filePath: '/fixture/.codex/rules/default.rules',
                kind: ConfigSourceKind.instructionDocument,
                format: ConfigFormat.text,
              ),
            )
            .status,
        PolicyCardStatus.notApplicable,
      );
    });

    test('reads legacy keys as stored, including retired values', () {
      final result = adapter.interpret(
        config: config({
          'sandbox_mode': 'danger-full-access',
          'approval_policy': 'untrusted',
        }),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.sandboxMode, 'danger-full-access');
      expect(presentationOf(result)?.approvalPolicy, 'untrusted');
      expect(
        presentationOf(result)?.hasConfiguredPermissions,
        isTrue,
      );
    });

    test('shows a built-in selection without a same-file table', () {
      final result = adapter.interpret(
        config: config({'default_permissions': ':workspace'}),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.defaultPermissions, ':workspace');
      expect(presentationOf(result)?.profiles, isEmpty);
    });

    test('shows a same-file profile for the selection', () {
      final result = adapter.interpret(
        config: config({
          'default_permissions': 'project-edit',
          'permissions': {
            'project-edit': {
              'description': 'Edits.',
            },
          },
        }),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.profiles.single.name, 'project-edit');
      expect(
        presentationOf(result)?.profiles.single.description,
        'Edits.',
      );
    });

    test('reads a full profile without resolving extends', () {
      final result = adapter.interpret(
        config: config({
          'default_permissions': 'project-edit',
          'permissions': {
            'project-edit': {
              'extends': ':workspace',
              'workspace_roots': {'~/code/app': true},
              'filesystem': {
                ':minimal': 'read',
                'glob_scan_max_depth': 3,
                ':workspace_roots': {'.': 'write', '**/*.env': 'deny'},
              },
              'network': {
                'enabled': true,
                'allow_local_binding': false,
                'domains': {'api.openai.com': 'allow'},
                'unix_sockets': {'/var/run/docker.sock': 'allow'},
              },
            },
          },
        }),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      final profile = presentationOf(result)?.profiles.single;
      expect(profile?.extendsProfile, ':workspace');
      expect(profile?.workspaceRoots, {'~/code/app': true});
      expect(profile?.globScanMaxDepth, 3);
      expect(profile?.filesystem?.length, 2);
      expect(profile?.filesystem?.first.access, 'read');
      expect(profile?.filesystem?.last.subpaths, {
        '.': 'write',
        '**/*.env': 'deny',
      });
      expect(profile?.network?.enabled, isTrue);
      expect(profile?.network?.domains, {'api.openai.com': 'allow'});
      expect(
        profile?.network?.unixSockets,
        {'/var/run/docker.sock': 'allow'},
      );
      expect(profile?.network?.allowLocalBinding, isFalse);
    });

    test('shows both halves when sandbox_mode coexists with profiles', () {
      final result = adapter.interpret(
        config: config({
          'sandbox_mode': 'workspace-write',
          'default_permissions': 'project-edit',
          'permissions': {
            'project-edit': <String, Object?>{},
          },
        }),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.sandboxMode, 'workspace-write');
      expect(presentationOf(result)?.profiles.single.name, 'project-edit');
    });

    test('flags a present sandbox_workspace_write table without parsing', () {
      final result = adapter.interpret(
        config: config({
          'sandbox_workspace_write': {'network_access': true},
        }),
        discoveredConfig: codexConfig(),
      );

      expect(result.status, PolicyCardStatus.available);
      expect(
        presentationOf(result)?.hasSandboxWorkspaceWriteTable,
        isTrue,
      );
      // Table-only files still render the empty state.
      expect(
        presentationOf(result)?.hasConfiguredPermissions,
        isFalse,
      );
    });

    test('renders an empty state for absent and empty blocks', () {
      final absent = adapter.interpret(
        config: config({'model': 'fixture-model'}),
        discoveredConfig: codexConfig(),
      );
      expect(absent.status, PolicyCardStatus.available);
      expect(
        presentationOf(absent)?.hasConfiguredPermissions,
        isFalse,
      );

      final emptyTable = adapter.interpret(
        config: config({
          'permissions': <String, Object?>{},
        }),
        discoveredConfig: codexConfig(),
      );
      expect(emptyTable.status, PolicyCardStatus.available);
      expect(
        presentationOf(emptyTable)?.hasConfiguredPermissions,
        isFalse,
      );
      expect(presentationOf(emptyTable)?.profiles, isEmpty);
    });

    test('declines wrong-typed recognized values with a reason', () {
      final malformed = <Map<String, Object?>>[
        {'sandbox_mode': 42},
        {'approval_policy': true},
        {'default_permissions': 7},
        {'permissions': 'project-edit'},
        {
          'permissions': ['project-edit'],
        },
        {'permissions': 42},
        {
          'permissions': {
            'broken': {'extends': 42},
          },
        },
        {
          'permissions': {
            'broken': {
              'workspace_roots': {'~/code/app': 'yes'},
            },
          },
        },
        {
          'permissions': {
            'broken': {
              'filesystem': {':minimal': 'execute'},
            },
          },
        },
        {
          'permissions': {
            'broken': {
              'filesystem': {'glob_scan_max_depth': 'deep'},
            },
          },
        },
        {
          'permissions': {
            'broken': {
              'network': {'enabled': 'yes'},
            },
          },
        },
      ];
      for (final raw in malformed) {
        final result = adapter.interpret(
          config: config(raw),
          discoveredConfig: codexConfig(),
        );
        expect(
          result.status,
          PolicyCardStatus.unsupported,
          reason: '$raw',
        );
        expect(result.unsupportedReason, isNotNull);
      }
    });

    test(
      'returns available or unsupported, never notApplicable, post-guard',
      () {
        final shapes = <Map<String, Object?>>[
          {},
          {'sandbox_mode': 'workspace-write'},
          {'permissions': <String, Object?>{}},
          {'permissions': 'broken'},
        ];
        for (final raw in shapes) {
          final result = adapter.interpret(
            config: config(raw),
            discoveredConfig: codexConfig(),
          );
          expect(
            result.status,
            isNot(PolicyCardStatus.notApplicable),
            reason: '$raw',
          );
          if (result.status == PolicyCardStatus.available) {
            expect(result.presentation, isNotNull);
          }
        }
      },
    );
  });
}
