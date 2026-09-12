import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:agents_config_helper/reports/report_save_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportSaveService', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ach_save_test');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
    });

    test('saveMarkdown writes bytes to the dialog-selected path', () async {
      final dialogPath = '${tempDir.path}/report.md';
      final service = ReportSaveService(
        saveFileDialog: (_, _) async => dialogPath,
      );

      final entries = <ConfigOverviewEntry>[
        ConfigOverviewEntry(
          toolId: ToolId.claudeCode,
          displayName: 'Claude Code',
          filePath: '${tempDir.path}/settings.json',
          displayPath: 'settings.json',
          kind: OverviewKind.config,
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          secretBearing: false,
          missing: false,
        ),
      ];

      final ok = await service.saveMarkdown(entries);
      expect(ok, isTrue);
      expect(File(dialogPath).existsSync(), isTrue);
      expect(
        File(dialogPath).readAsStringSync(),
        contains('Config Overview Report'),
      );
    });

    test('saveHtml writes bytes to the dialog-selected path', () async {
      final dialogPath = '${tempDir.path}/report.html';
      final service = ReportSaveService(
        saveFileDialog: (_, _) async => dialogPath,
      );

      final entries = <ConfigOverviewEntry>[
        ConfigOverviewEntry(
          toolId: ToolId.claudeCode,
          displayName: 'Claude Code',
          filePath: '${tempDir.path}/settings.json',
          displayPath: 'settings.json',
          kind: OverviewKind.config,
          format: ConfigFormat.json,
          scope: ConfigLocationScope.user,
          secretBearing: false,
          missing: false,
        ),
      ];

      final ok = await service.saveHtml(entries);
      expect(ok, isTrue);
      expect(File(dialogPath).existsSync(), isTrue);
      expect(
        File(dialogPath).readAsStringSync(),
        contains('<html'),
      );
    });

    test('saveMarkdown returns false when dialog is cancelled', () async {
      final service = ReportSaveService(
        saveFileDialog: (_, _) async => null,
      );

      final entries = <ConfigOverviewEntry>[];
      final ok = await service.saveMarkdown(entries);
      expect(ok, isFalse);
    });

    test('saveHtml returns false when dialog is cancelled', () async {
      final service = ReportSaveService(
        saveFileDialog: (_, _) async => null,
      );

      final entries = <ConfigOverviewEntry>[];
      final ok = await service.saveHtml(entries);
      expect(ok, isFalse);
    });

    test('save throws when write fails', () async {
      final service = ReportSaveService(
        saveFileDialog: (_, _) async => '/invalid/path/report.md',
      );

      final entries = <ConfigOverviewEntry>[];
      expect(
        () => service.saveMarkdown(entries),
        throwsA(isA<Exception>()),
      );
    });
  });
}
