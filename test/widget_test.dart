// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:agents_config_helper/main.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfigService extends ConfigService {
  _FakeConfigService(BackupService backupService)
    : super(backupService: backupService);

  @override
  Future<ToolConfig> loadConfig(String path) async {
    return ToolConfig(
      toolName: path.contains('cursor') ? 'Cursor' : 'Claude',
      filePath: path,
      format: ConfigFormat.json,
      rules: const ['original rule'],
    );
  }
}

void main() {
  testWidgets('MainShell renders sidebar and content area', (tester) async {
    final configService = ConfigService(
      backupService: BackupService(backupDirectory: Directory.systemTemp),
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      AgentsConfigHelperApp(configService: configService),
    );

    // Verify that our app shell renders.
    expect(find.text('Agents Config'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
  });

  testWidgets('confirms before discarding edits to load another config', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final configService = _FakeConfigService(
      BackupService(backupDirectory: Directory.systemTemp),
    );
    await tester.pumpWidget(
      MaterialApp(home: MainShell(configService: configService)),
    );

    await tester.tap(find.text('Claude Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Item').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'unsaved rule');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cursor'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('unsaved rule'), findsOneWidget);

    await tester.tap(find.text('Cursor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard & Load'));
    await tester.pumpAndSettle();
    expect(find.text('Cursor'), findsNWidgets(2));
  });
}
