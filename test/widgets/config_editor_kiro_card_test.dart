import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/kiro_permissions.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:agents_config_helper/widgets/structured_save_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('ConfigEditor Kiro card integration', () {
    DiscoveredConfig kiroConfig() {
      final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.kiro,
      );
      return DiscoveredConfig.fromPath(
        filePath:
            '${Directory.systemTemp.path}/.kiro/settings/permissions.yaml',
        descriptor: descriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.yaml,
        sourceLabel: 'Kiro',
        fromCatalog: true,
      );
    }

    Widget editor({
      required ToolConfig config,
      required DiscoveredConfig discoveredConfig,
      required SaveConfigCallback onSave,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ConfigEditor(
            config: config,
            discoveredConfig: discoveredConfig,
            onSave: onSave,
            resolvePath: (path) => path,
            onShowHistory: () {},
          ),
        ),
      );
    }

    testWidgets(
      'renders the Kiro card and omits the generic Rules editor for a valid '
      'Kiro target',
      (tester) async {
        final discoveredConfig = kiroConfig();
        const originalContent = '''
rules:
  - capability: shell
    effect: allow
    match: ["git *"]
''';
        final config = ToolConfig(
          toolName: 'Kiro',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.yaml,
          originalContent: originalContent,
          rawSettings: const {
            'rules': [
              {
                'capability': 'shell',
                'effect': 'allow',
                'match': ['git *'],
              },
            ],
          },
        );
        var saveCount = 0;

        await tester.pumpWidget(
          editor(
            config: config,
            discoveredConfig: discoveredConfig,
            onSave:
                (
                  config, {
                  rawContent,
                  allowRewrite,
                  overwriteConfirmed,
                }) async {
                  saveCount++;
                  return config;
                },
          ),
        );

        expect(find.text('Kiro permissions'), findsOneWidget);
        expect(find.text('Shell'), findsOneWidget);
        expect(find.text('allow'), findsOneWidget);
        expect(find.text('Rules'), findsNothing);
        expect(find.byType(StringListEditor), findsNothing);
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );

        final capabilityTooltip = KiroPermissionsHelp.capability('shell')
            .description;
        await tester.ensureVisible(find.byTooltip(capabilityTooltip));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(capabilityTooltip));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(config.originalContent, originalContent);
        expect(saveCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'shows the Kiro unsupported reason and omits the generic Rules editor',
      (tester) async {
        final discoveredConfig = kiroConfig();
        const originalContent = 'rules: not-a-list\n';
        final config = ToolConfig(
          toolName: 'Kiro',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.yaml,
          originalContent: originalContent,
          rawSettings: const {'rules': 'not-a-list'},
        );

        await tester.pumpWidget(
          editor(
            config: config,
            discoveredConfig: discoveredConfig,
            onSave: (
              config, {
              rawContent,
              allowRewrite,
              overwriteConfirmed,
            }) async => config,
          ),
        );

        expect(find.text('Kiro permissions'), findsNothing);
        expect(
          find.text(
            'Kiro permission "rules" is not a list. Use the raw editor to '
            'review it.',
          ),
          findsOneWidget,
        );
        expect(find.text('Rules'), findsNothing);
        expect(find.byType(StringListEditor), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
