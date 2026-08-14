import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/widgets/history_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBackupService extends BackupService {
  FakeBackupService() : super(backupDirectory: Directory(''));

  @override
  Future<List<File>> listBackups(String sourceFilePath) async {
    return [File('/fake/backup/path.bak')];
  }
}

void main() {
  group('HistoryModal', () {
    late ToolConfig config;

    setUp(() {
      config = ToolConfig(
        toolName: 'test',
        filePath: '/fake/config.json',
        format: ConfigFormat.json,
        rawSettings: const {'key': 'value'},
      );
    });

    testWidgets('shows backups and can confirm restore', (tester) async {
      var restoreCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryModal(
              config: config,
              backupService: FakeBackupService(),
              onRestore: (path) async {
                expect(path, '/fake/backup/path.bak');
                restoreCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the restore button
      final restoreButton = find.text('Restore');
      expect(restoreButton, findsOneWidget);

      // Tap restore, which should open confirmation
      await tester.tap(restoreButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ensure confirmation dialog appears
      expect(find.text('Confirm Restore'), findsOneWidget);

      // Tap confirm
      final confirmButton = find.text('Confirm & Restore');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(restoreCalled, isTrue);
    });
  });
}
