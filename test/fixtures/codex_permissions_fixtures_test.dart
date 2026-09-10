import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final parser = TomlConfigParser();
  final adapter = CodexPermissionsAdapter();

  CodexPermissionsPresentation? presentationOf(
    PolicyCardSelection selection,
  ) {
    return selection.presentation as CodexPermissionsPresentation?;
  }

  final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
    (item) => item.id == ToolId.codex,
  );

  DiscoveredConfig discovered({
    required String filePath,
    required ConfigLocationScope scope,
  }) {
    return DiscoveredConfig.fromPath(
      filePath: filePath,
      descriptor: descriptor,
      scope: scope,
      kind: ConfigSourceKind.structuredConfig,
      format: ConfigFormat.toml,
      sourceLabel: 'Codex',
      fromCatalog: true,
    );
  }

  ToolConfig parseFixture(String relativePath, DiscoveredConfig target) {
    final content = File(p.join('test', 'fixtures', relativePath))
        .readAsStringSync();
    return parser.parse(
      content,
      filePath: target.filePath,
      toolName: 'Codex',
      format: ConfigFormat.toml,
    );
  }

  group('Codex permission fixtures', () {
    test('a legacy fixture renders stored sandbox keys', () {
      for (final scope in [
        ConfigLocationScope.user,
        ConfigLocationScope.project,
      ]) {
        final target = discovered(
          filePath: '/fixture/.codex/config.toml',
          scope: scope,
        );
        final result = adapter.interpret(
          config: parseFixture(
            'edge_cases/codex_permissions_legacy.toml',
            target,
          ),
          discoveredConfig: target,
        );

        expect(result.status, PolicyCardStatus.available);
        expect(presentationOf(result)?.sandboxMode, 'workspace-write');
        expect(presentationOf(result)?.approvalPolicy, 'on-request');
        expect(
          presentationOf(result)?.hasConfiguredPermissions,
          isTrue,
        );
      }
    });

    test('a profile fixture decodes the quoted dotted sub-table', () {
      final target = discovered(
        filePath: '/fixture/.codex/config.toml',
        scope: ConfigLocationScope.user,
      );
      final result = adapter.interpret(
        config: parseFixture(
          'edge_cases/codex_permissions_profile.toml',
          target,
        ),
        discoveredConfig: target,
      );

      expect(result.status, PolicyCardStatus.available);
      expect(presentationOf(result)?.defaultPermissions, 'project-edit');
      final profile = presentationOf(result)?.profiles.single;
      expect(profile?.extendsProfile, ':workspace');
      expect(profile?.globScanMaxDepth, 3);
      expect(profile?.filesystem?.last.subpaths, {
        '.': 'write',
        '**/*.env': 'deny',
      });
      expect(profile?.network?.enabled, isTrue);
    });

    test('a malformed fixture is unsupported', () {
      final target = discovered(
        filePath: '/fixture/.codex/config.toml',
        scope: ConfigLocationScope.user,
      );
      final result = adapter.interpret(
        config: parseFixture(
          'edge_cases/codex_permissions_malformed.toml',
          target,
        ),
        discoveredConfig: target,
      );

      expect(result.status, PolicyCardStatus.unsupported);
      expect(result.unsupportedReason, isNotNull);
    });

    test('an empty fixture renders the empty state', () {
      final target = discovered(
        filePath: '/fixture/.codex/config.toml',
        scope: ConfigLocationScope.user,
      );
      final result = adapter.interpret(
        config: parseFixture(
          'edge_cases/codex_permissions_empty.toml',
          target,
        ),
        discoveredConfig: target,
      );

      expect(result.status, PolicyCardStatus.available);
      expect(
        presentationOf(result)?.hasConfiguredPermissions,
        isFalse,
      );
    });

    test('a profile-file basename never matches', () {
      final target = discovered(
        filePath: '/fixture/.codex/dev.config.toml',
        scope: ConfigLocationScope.user,
      );
      final result = adapter.interpret(
        config: parseFixture(
          'edge_cases/codex_permissions_profile.toml',
          target,
        ),
        discoveredConfig: target,
      );

      expect(result.status, PolicyCardStatus.notApplicable);
    });
  });
}
