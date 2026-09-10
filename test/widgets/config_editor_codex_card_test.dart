import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/schemas/codex_permissions.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toml/toml.dart';

void main() {
  group('ConfigEditor Codex card integration', () {
    DiscoveredConfig codexConfig(String filePath) {
      final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.codex,
      );
      return DiscoveredConfig.fromPath(
        filePath: filePath,
        descriptor: descriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.toml,
        sourceLabel: 'Codex',
        fromCatalog: true,
      );
    }

    Future<void> pumpCodexEditor(
      WidgetTester tester,
      ToolConfig config,
      DiscoveredConfig discoveredConfig, {
      bool tomlStructuredSaveEnabled = false,
      Future<ToolConfig> Function(
        ToolConfig config, {
        String? rawContent,
        bool? allowRewrite,
      })?
      onSave,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              discoveredConfig: discoveredConfig,
              tomlStructuredSaveEnabled: tomlStructuredSaveEnabled,
              onSave:
                  onSave ??
                  (config, {rawContent, allowRewrite}) async => config,
              resolvePath: (path) => path,
              onShowHistory: () {},
            ),
          ),
        ),
      );
    }

    testWidgets(
      'renders the Codex card under the default TOML opt-out',
      (tester) async {
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: 'sandbox_mode = "workspace-write"\n',
          rawSettings: const {'sandbox_mode': 'workspace-write'},
        );

        await pumpCodexEditor(tester, config, discoveredConfig);

        expect(find.text('Codex permissions'), findsOneWidget);
        expect(
          find.text('sandbox_mode → workspace-write'),
          findsOneWidget,
        );
        // The opt-in banner still shows; no structured edit controls appear.
        expect(
          find.text('Structured TOML editing is disabled'),
          findsOneWidget,
        );
        expect(find.byType(StringListEditor), findsNothing);
        expect(
          find.text(
            'Nested permissions are preserved but not editable here yet.',
          ),
          findsNothing,
        );
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows the profile card and hides the nested notice for a Codex '
      'permissions table',
      (tester) async {
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent:
              'default_permissions = "project-edit"\n'
              '[permissions.project-edit.filesystem]\n'
              '":minimal" = "read"\n',
          rawSettings: const {
            'default_permissions': 'project-edit',
            'permissions': {
              'project-edit': {
                'filesystem': {':minimal': 'read'},
              },
            },
          },
        );

        await pumpCodexEditor(tester, config, discoveredConfig);

        expect(find.text('Codex permissions'), findsOneWidget);
        expect(find.text('• :minimal → read'), findsOneWidget);
        expect(
          find.text(
            'Nested permissions are preserved but not editable here yet.',
          ),
          findsNothing,
        );
        expect(find.byType(StringListEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows banner plus raw editor, without a nested notice, for a '
      'malformed Codex file under opt-out',
      (tester) async {
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: 'sandbox_mode = 42\n',
          rawSettings: const {'sandbox_mode': 42},
        );

        await pumpCodexEditor(tester, config, discoveredConfig);

        expect(find.text('Codex permissions'), findsNothing);
        expect(
          find.text('Structured TOML editing is disabled'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Nested permissions are preserved but not editable here yet.',
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows no structured editors for a manual-path TOML file under opt-out',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.codex,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: '${Directory.systemTemp.path}/manual.toml',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.toml,
          sourceLabel: 'Codex',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: 'sandbox_mode = "workspace-write"\n',
          rawSettings: const {'sandbox_mode': 'workspace-write'},
        );

        await pumpCodexEditor(tester, config, discoveredConfig);

        expect(find.text('Codex permissions'), findsNothing);
        expect(find.byType(StringListEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the Codex card is read-only', (tester) async {
      final discoveredConfig = codexConfig(
        '${Directory.systemTemp.path}/.codex/config.toml',
      );
      final config = ToolConfig(
        toolName: 'Codex',
        filePath: discoveredConfig.filePath,
        format: ConfigFormat.toml,
        originalContent: 'default_permissions = ":workspace"\n',
        rawSettings: const {'default_permissions': ':workspace'},
      );
      final rawBefore = config.originalContent;
      var saveCount = 0;

      await pumpCodexEditor(
        tester,
        config,
        discoveredConfig,
        onSave: (config, {rawContent, allowRewrite}) async {
          saveCount++;
          return config;
        },
      );

      expect(find.text('Codex permissions'), findsOneWidget);
      await tester.ensureVisible(
        find.byTooltip(CodexPermissionsHelp.selection.description),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(CodexPermissionsHelp.selection.description),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(saveCount, 0);
      expect(config.originalContent, rawBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows the nested-rules notice instead of the Rules editor for a '
      'map-shaped rules table',
      (tester) async {
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: '[rules]\nkey = "value"\n',
          rawSettings: const {
            'rules': {'key': 'value'},
          },
        );

        await pumpCodexEditor(
          tester,
          config,
          discoveredConfig,
          tomlStructuredSaveEnabled: true,
        );

        expect(
          find.text('Nested rules are preserved but not editable here yet.'),
          findsOneWidget,
        );
        expect(
          find.text('Define custom rules for this agent.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows the nested-rules notice for a scalar rules value',
      (tester) async {
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: 'rules = "legacy"\n',
          rawSettings: const {'rules': 'legacy'},
        );

        await pumpCodexEditor(
          tester,
          config,
          discoveredConfig,
          tomlStructuredSaveEnabled: true,
        );

        expect(
          find.text('Nested rules are preserved but not editable here yet.'),
          findsOneWidget,
        );
        expect(find.byType(StringListEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows the unsupported reason, not a card, for a malformed Codex '
      'file under opt-in',
      (tester) async {
        // Tall surface: the ListView builds lazily, so below-fold rows
        // need scrolling or a viewport that fits them.
        await tester.binding.setSurfaceSize(const Size(800, 2500));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: 'sandbox_mode = 42\n',
          rawSettings: const {'sandbox_mode': 42},
        );

        await pumpCodexEditor(
          tester,
          config,
          discoveredConfig,
          tomlStructuredSaveEnabled: true,
        );

        expect(find.text('Codex permissions'), findsNothing);
        expect(
          find.text(
            'Codex permission "sandbox_mode" is not a supported value. '
            'Use the raw editor to review it.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'an opt-in save round-trips the permissions table through the '
      'editor composition',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 2500));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const originalContent =
            'default_permissions = "project-edit"\n'
            '[permissions.project-edit.filesystem]\n'
            '":minimal" = "read"\n';
        final discoveredConfig = codexConfig(
          '${Directory.systemTemp.path}/.codex/config.toml',
        );
        final config = ToolConfig(
          toolName: 'Codex',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.toml,
          originalContent: originalContent,
          rawSettings: const {
            'default_permissions': 'project-edit',
            'permissions': {
              'project-edit': {
                'filesystem': {':minimal': 'read'},
              },
            },
          },
        );
        ToolConfig? savedConfig;

        await pumpCodexEditor(
          tester,
          config,
          discoveredConfig,
          tomlStructuredSaveEnabled: true,
          onSave: (updated, {rawContent, allowRewrite}) async {
            savedConfig = updated;
            return updated;
          },
        );

        // Make the editor dirty through the raw editor, then save.
        await tester.enterText(
          find.byType(TextField),
          '$originalContent# test note\n',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm & Save'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(savedConfig, isNotNull);
        final serialized = TomlConfigParser().serializeWithOutcome(
          savedConfig!,
        );
        final roundTripped = TomlDocument.parse(serialized.content).toMap();
        expect(
          (roundTripped['permissions']! as Map)['project-edit'],
          ((savedConfig!.rawSettings['permissions']!) as Map)['project-edit'],
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
