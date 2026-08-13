// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:agents_config_helper/main.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Claude Code'), findsWidgets);
  });
}
