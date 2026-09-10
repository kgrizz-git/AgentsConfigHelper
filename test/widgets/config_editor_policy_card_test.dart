import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/opencode_permissions.dart';
import 'package:agents_config_helper/widgets/claude_code_permissions_card.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:agents_config_helper/widgets/policy_card_widget_registry.dart';
import 'package:agents_config_helper/widgets/string_list_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigEditor policy-card integration', () {
    testWidgets(
      'shows the nested permissions notice, not the flat editor, for a '
      'tool with no matching adapter with Map permissions',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.lmStudio,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath: '${Directory.systemTemp.path}/.lmstudio/settings.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.json,
          sourceLabel: 'LM Studio',
          fromCatalog: true,
        );
        final config = ToolConfig(
          toolName: 'LM Studio',
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
      'falls back to the flat editor when the widget registry cannot build '
      'the card',
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
        // An available selection whose adapterId has no registered builder
        // makes buildCard return null; ConfigEditor falls through to the flat
        // editor rather than rendering nothing.
        final widgetRegistry = PolicyCardWidgetRegistry(const {});

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

        expect(find.text('Claude Code permissions'), findsNothing);
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsOneWidget,
        );
        expect(find.byType(StringListEditor), findsNWidgets(2));
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

    testWidgets(
      'renders the Cursor card for a catalog-discovered permissions.json',
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
          originalContent: '{"mcpAllowlist":["github:*"]}',
          rawSettings: const {
            'mcpAllowlist': ['github:*'],
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

        expect(find.text('Cursor Agent permissions'), findsOneWidget);
        expect(find.text('MCP allowlist (1)'), findsOneWidget);
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
      },
    );

    testWidgets(
      'shows unsupported-reason text, not a card, for a malformed Cursor '
      'recognized field',
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
          originalContent: '{"mcpAllowlist":"github:*"}',
          rawSettings: const {
            'mcpAllowlist': 'github:*',
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

        expect(find.text('Cursor Agent permissions'), findsNothing);
        expect(
          find.text(
            'Cursor permission "mcpAllowlist" is not a supported value. '
            'Use the raw editor to review it.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the Cursor card is read-only', (tester) async {
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
      const originalContent = '{"mcpAllowlist":["github:*"]}';
      final config = ToolConfig(
        toolName: 'Cursor Agent',
        filePath: discoveredConfig.filePath,
        format: ConfigFormat.json,
        originalContent: originalContent,
        rawSettings: const {
          'mcpAllowlist': ['github:*'],
        },
      );
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              discoveredConfig: discoveredConfig,
              onSave: (config, {rawContent, allowRewrite}) async {
                saveCount++;
                return config;
              },
              resolvePath: (path) => path,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cursor Agent permissions'), findsOneWidget);
      expect(
        find.text('Allowed directories or commands for this agent.'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byTooltip(CursorPermissionsHelp.mcpAllowlist.description),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(CursorPermissionsHelp.mcpAllowlist.description),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(config.originalContent, originalContent);
      expect(saveCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders the Opencode card for a catalog-discovered opencode.json',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.opencode,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath:
              '${Directory.systemTemp.path}/.config/opencode/opencode.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.jsonc,
          sourceLabel: 'Opencode',
          fromCatalog: true,
        );
        final config = ToolConfig(
          toolName: 'Opencode',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.jsonc,
          originalContent: '{"permission":"allow"}',
          rawSettings: const {'permission': 'allow'},
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

        expect(find.text('Opencode permissions'), findsOneWidget);
        expect(find.text('Global'), findsOneWidget);
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
      },
    );

    testWidgets(
      'shows unsupported-reason text, not a card, for a malformed Opencode '
      'permission',
      (tester) async {
        final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
          (item) => item.id == ToolId.opencode,
        );
        final discoveredConfig = DiscoveredConfig.fromPath(
          filePath:
              '${Directory.systemTemp.path}/.config/opencode/opencode.json',
          descriptor: descriptor,
          scope: ConfigLocationScope.user,
          kind: ConfigSourceKind.structuredConfig,
          format: ConfigFormat.jsonc,
          sourceLabel: 'Opencode',
          fromCatalog: true,
        );
        final config = ToolConfig(
          toolName: 'Opencode',
          filePath: discoveredConfig.filePath,
          format: ConfigFormat.jsonc,
          originalContent: '{"permission":"maybe"}',
          rawSettings: const {'permission': 'maybe'},
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

        expect(find.text('Opencode permissions'), findsNothing);
        expect(
          find.text(
            'Opencode permission "permission" is not a supported value. '
            'Use the raw editor to review it.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Allowed directories or commands for this agent.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the Opencode card is read-only', (tester) async {
      final descriptor = ToolDescriptorRegistry.catalog.firstWhere(
        (item) => item.id == ToolId.opencode,
      );
      final discoveredConfig = DiscoveredConfig.fromPath(
        filePath: '${Directory.systemTemp.path}/.config/opencode/opencode.json',
        descriptor: descriptor,
        scope: ConfigLocationScope.user,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.jsonc,
        sourceLabel: 'Opencode',
        fromCatalog: true,
      );
      final config = ToolConfig(
        toolName: 'Opencode',
        filePath: discoveredConfig.filePath,
        format: ConfigFormat.jsonc,
        originalContent: '{"permission":{"bash":"allow"}}',
        rawSettings: const {
          'permission': {'bash': 'allow'},
        },
      );
      var saveCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              discoveredConfig: discoveredConfig,
              onSave: (config, {rawContent, allowRewrite}) async {
                saveCount++;
                return config;
              },
              resolvePath: (path) => path,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      expect(find.text('Opencode permissions'), findsOneWidget);
      expect(
        find.text('Allowed directories or commands for this agent.'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byTooltip(
          OpencodePermissionsHelp.toolPermission('bash').description,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          OpencodePermissionsHelp.toolPermission('bash').description,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(saveCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
