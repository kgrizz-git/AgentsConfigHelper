import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/widgets/config_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConfigService extends ConfigService {
  FakeConfigService(BackupService backupService)
    : super(backupService: backupService);

  final savedConfigs = <ToolConfig>[];

  @override
  Future<ToolConfig> saveConfig(ToolConfig config) async {
    savedConfigs.add(config);
    await Future<void>.delayed(Duration.zero);
    return config;
  }
}

void main() {
  group('ConfigEditor', () {
    testWidgets('renders config and calls save', (tester) async {
      final tempDir = Directory.systemTemp;
      final configPath = '${tempDir.path}/test_config.json';
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: configPath,
        format: ConfigFormat.json,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) => configService.saveConfig(c),
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      expect(find.text('rule1'), findsOneWidget);
      expect(find.text('perm1'), findsOneWidget);

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Save'));
      await tester.pump(); // Start async operation
      await tester.pumpAndSettle(); // Wait for snackbar

      expect(
        find.textContaining('Settings saved successfully.'),
        findsOneWidget,
      );
      expect(configService.savedConfigs.single.rules, contains('new rule'));
    });

    testWidgets('forwards edited raw content to onSave', (tester) async {
      final tempDir = Directory.systemTemp;
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      // Text format shows only the raw editor (no structured fields), so there
      // is exactly one TextField to drive.
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${tempDir.path}/notes.md',
        format: ConfigFormat.text,
        originalContent: 'original raw',
      );
      var sawRawArg = false;
      String? capturedRaw;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) {
                sawRawArg = true;
                capturedRaw = r;
                return configService.saveConfig(c);
              },
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'edited raw');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Save'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(sawRawArg, isTrue);
      expect(capturedRaw, 'edited raw');
    });

    testWidgets('passes null rawContent for a structured-only save', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp;
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${tempDir.path}/structured.json',
        format: ConfigFormat.json,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );
      String? capturedRaw = 'sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) {
                capturedRaw = r;
                return configService.saveConfig(c);
              },
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm & Save'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(capturedRaw, isNull);
    });

    testWidgets('diff viewer modal opens and can save', (tester) async {
      final tempDir = Directory.systemTemp;
      final configPath = '${tempDir.path}/test_config2.json';
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: configPath,
        format: ConfigFormat.json,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) => configService.saveConfig(c),
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Review Changes'), findsWidgets);
      expect(find.text('+ new rule'), findsOneWidget);

      await tester.tap(find.text('Confirm & Save'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Settings saved successfully.'),
        findsOneWidget,
      );
      expect(configService.savedConfigs.single.rules, contains('new rule'));
    });

    testWidgets('shows a removed duplicate in the review diff', (tester) async {
      final tempDir = Directory.systemTemp;
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${tempDir.path}/duplicate_rules.json',
        format: ConfigFormat.json,
        rules: const ['duplicate', 'duplicate'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) => configService.saveConfig(c),
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Remove').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(find.text('- duplicate'), findsOneWidget);
    });

    testWidgets(
      'shows TOML formatting warning when structured fields change',
      (tester) async {
        final tempDir = Directory.systemTemp;
        final configService = FakeConfigService(
          BackupService(backupDirectory: tempDir),
        );
        final config = ToolConfig(
          toolName: 'Test Tool',
          filePath: '${tempDir.path}/config.toml',
          format: ConfigFormat.toml,
          rules: const ['rule1'],
          permissions: const ['perm1'],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConfigEditor(
                config: config,
                onSave: (c, [r]) => configService.saveConfig(c),
                resolvePath: configService.resolvePath,
                onShowHistory: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Add Item').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), 'new rule');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review Changes'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Saving a TOML config with structured changes',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('does not show TOML warning for JSON configs', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp;
      final configService = FakeConfigService(
        BackupService(backupDirectory: tempDir),
      );
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${tempDir.path}/config.json',
        format: ConfigFormat.json,
        rules: const ['rule1'],
        permissions: const ['perm1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) => configService.saveConfig(c),
              resolvePath: configService.resolvePath,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Item').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'new rule');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review Changes'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Saving a TOML config with structured changes'),
        findsNothing,
      );
    });

    testWidgets('allows editing when permissions is explicitly null', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp;
      final config = ToolConfig(
        toolName: 'Test Tool',
        filePath: '${tempDir.path}/null_permissions.json',
        format: ConfigFormat.json,
        rawSettings: const {'permissions': null},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfigEditor(
              config: config,
              onSave: (c, [r]) async => c,
              resolvePath: (path) => path,
              onShowHistory: () {},
            ),
          ),
        ),
      );

      expect(
        find.text('Allowed directories or commands for this agent.'),
        findsOneWidget,
      );
    });
  });
}
