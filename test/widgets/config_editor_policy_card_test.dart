import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/widgets/claude_code_permissions_card.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/policy_card_widget_registry.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigEditor policy-card integration', () {
    testWidgets(
      'shows the nested permissions notice for a non-Claude tool with Map '
      'permissions',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.cursor,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: '${Directory.systemTemp.path}/.cursor/permissions.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'Cursor Agent',
          fromCatalog: true,
        );
        final config = ToolConfig(
          toolName: 'Cursor Agent',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.json,
          originalContent: '{"permissions":{"allow":["Read(./fixtures/**)"]}}',
          rawSettings: const {
            'permissions': {
              'allow': ['Read(./fixtures/**)'],
            },
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConfigEditor(
                config: config,
                discoveredConfig: discoveredConfig,
                onSave: (config, {rawContent, allowRewrite}) async => config,
                resolvePath: (path) => path,
                onShowHistory: () {},
              ),
            ),
          ),
        );

        expect(
          find.text(
            'Nested permissions are preserved but not editable here yet.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );
        expect(find.byType(StringListEditor), findsOneWidget);
      },
    );

    testWidgets(
      'shows the nested permissions notice for a manual-path Claude config '
      'with Map permissions',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.claudeCode,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: '${Directory.systemTemp.path}/.claude/settings.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'Claude Code',
        );
        final config = ToolConfig(
          toolName: 'Claude Code',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.json,
          originalContent: '{"permissions":{"allow":["Read(./fixtures/**)"]}}',
          rawSettings: const {
            'permissions': {
              'allow': ['Read(./fixtures/**)'],
            },
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConfigEditor(
                config: config,
                discoveredConfig: discoveredConfig,
                onSave: (config, {rawContent, allowRewrite}) async => config,
                resolvePath: (path) => path,
                onShowHistory: () {},
              ),
            ),
          ),
        );

        expect(find.text('Claude Code permissions'), findsNothing);
        expect(
          find.text(
            'Nested permissions are preserved but not editable here yet.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );
        expect(find.byType(StringListEditor), findsOneWidget);
      },
    );

    testWidgets(
      'shows doc-launcher failure feedback from the registry-built Claude '
      'card',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.claudeCode,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: '${Directory.systemTemp.path}/.claude/settings.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'Claude Code',
          fromCatalog: true,
        );
        final config = ToolConfig(
          toolName: 'Claude Code',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.json,
          originalContent: '{"permissions":{"allow":["Read(./fixtures/**)"]}}',
          rawSettings: const {
            'permissions': {
              'allow': ['Read(./fixtures/**)'],
            },
          },
        );
        // url_launcher's launchUrl never completes in testWidgets, so inject a
        // registry whose Claude builder supplies a deterministically failing
        // launcher.
        final widgetRegistry = PolicyCardWidgetRegistry({
          ClaudeCodePermissionsAdapter.adapterId: (selection) {
            return ClaudeCodePermissionsCard(
              presentation:
                  selection.presentation! as ClaudeCodePermissionsPresentation,
              onOpenDocumentation: (_) async => false,
            );
          },
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConfigEditor(
                config: config,
                discoveredConfig: discoveredConfig,
                onSave: (config, {rawContent, allowRewrite}) async => config,
                resolvePath: (path) => path,
                onShowHistory: () {},
                widgetRegistry: widgetRegistry,
              ),
            ),
          ),
        );

        expect(find.text('Claude Code permissions'), findsOneWidget);

        await tester.ensureVisible(
          find.text('Claude Code permissions documentation'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Claude Code permissions documentation'));
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to open Claude Code permissions documentation.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
