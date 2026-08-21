import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/widgets/history_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
      String? restoredPath;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backupListProvider(config.filePath).overrideWith(
              (_) async => [File('/fake/backup/path.bak')],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HistoryModal(
                config: config,
                onRestore: (path) async {
                  restoredPath = path;
                  restoreCalled = true;
                },
              ),
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
      // Flush the async onRestore callback and the navigator pop.
      await tester.pumpAndSettle();

      expect(restoreCalled, isTrue);
      expect(restoredPath, '/fake/backup/path.bak');
    });

    testWidgets('shows empty message when no backups exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backupListProvider(config.filePath).overrideWith(
              (_) async => [],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HistoryModal(
                config: config,
                onRestore: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('No backups found for this file.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when provider fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            backupListProvider(config.filePath).overrideWith(
              (_) async => throw Exception('Disk error'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HistoryModal(
                config: config,
                onRestore: (_) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.textContaining('Disk error'), findsOneWidget);
    });
  });
}
