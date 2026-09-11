import 'dart:io';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/discovery_result.dart';
import 'package:agents_config_helper/screens/main_shell.dart';
import 'package:agents_config_helper/services/backup_service.dart';
import 'package:agents_config_helper/services/config_service.dart';
import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:agents_config_helper/state/providers.dart';
import 'package:agents_config_helper/theme/app_colors.dart';
import 'package:agents_config_helper/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyDiscoveryService extends DiscoveryService {
  @override
  Future<DiscoveryResult> discoverConfigs(DiscoveryRequest request) async {
    return const DiscoveryResult(items: []);
  }
}

class _PrefsStore implements IDiscoveryPreferencesStore {
  _PrefsStore({this.throwOnAdd = false});

  final bool throwOnAdd;

  @override
  Future<DiscoveryPreferencesResult> load() async {
    return const DiscoveryPreferencesResult(
      preferences: DiscoveryPreferences(),
    );
  }

  @override
  Future<void> addManualPath(String path) async {
    if (throwOnAdd) throw Exception('Disk error');
  }

  @override
  Future<void> removeManualPath(String path) async {}
  @override
  Future<void> addProjectRoot(String path) async {}
  @override
  Future<void> removeProjectRoot(String path) async {}
  @override
  Future<void> enableTomlStructuredSave() async {}
  @override
  Future<void> disableTomlStructuredSave() async {}
}

Future<void> _pumpShell(
  WidgetTester tester, {
  DiscoveryService? discovery,
  IDiscoveryPreferencesStore? store,
}) async {
  final configService = ConfigService(
    backupService: BackupService(backupDirectory: Directory.systemTemp),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        configServiceProvider.overrideWithValue(configService),
        discoveryServiceProvider.overrideWithValue(
          discovery ?? _EmptyDiscoveryService(),
        ),
        discoveryPreferencesStoreProvider.overrideWithValue(
          store ?? _PrefsStore(),
        ),
      ],
      child: const MaterialApp(home: MainShell()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty discovery shows a styled empty state', (tester) async {
    await _pumpShell(tester);

    final empty = find.text('No configurations found.');
    expect(empty, findsOneWidget);
    expect(tester.widget<Text>(empty).style, AppTextStyles.uiSecondary);
  });

  testWidgets('failed manual path shows an error snackbar', (tester) async {
    await _pumpShell(tester, store: _PrefsStore(throwOnAdd: true));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Manual Config Path'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '/bad/path');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final snackbar = find.byType(SnackBar);
    expect(snackbar, findsOneWidget);
    expect(tester.widget<SnackBar>(snackbar).backgroundColor, AppColors.error);
  });
}
