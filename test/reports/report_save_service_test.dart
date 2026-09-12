import 'dart:io';

import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:agents_config_helper/reports/config_overview_report.dart';
import 'package:agents_config_helper/reports/report_save_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _fileSelectorChannel = MethodChannel(
  'plugins.flutter.io/file_selector',
);

void _mockSaveLocation(Future<dynamic> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fileSelectorChannel, handler);
}

void _clearSaveLocationMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_fileSelectorChannel, null);
}

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test(
      'provider dialog returns null when native dialog is cancelled',
      () async {
        _mockSaveLocation((call) async => null);
        try {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final dialog = container.read(saveFileDialogProvider);
          expect(await dialog('config-overview-report.md', 'md'), isNull);
        } finally {
          _clearSaveLocationMock();
        }
      },
    );

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

    test(
      'provider dialog forwards markdown args to the native channel',
      () async {
        const nativePath = '/tmp/ach-native-report.md';
        _mockSaveLocation((call) async {
          expect(call.method, 'getSavePath');
          final args = call.arguments as Map<dynamic, dynamic>;
          expect(args['suggestedName'], 'config-overview-report.md');
          final typeGroups = args['acceptedTypeGroups'] as List<dynamic>;
          expect(typeGroups, hasLength(1));
          final extensions =
              (typeGroups.first as Map<dynamic, dynamic>)['extensions']
                  as List<dynamic>;
          expect(extensions, ['md']);
          return nativePath;
        });
        try {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final dialog = container.read(saveFileDialogProvider);
          expect(
            await dialog('config-overview-report.md', 'md'),
            nativePath,
          );

          final service = ReportSaveService(saveFileDialog: dialog);
          expect(await service.saveMarkdown(const []), isTrue);
          expect(File(nativePath).existsSync(), isTrue);
        } finally {
          _clearSaveLocationMock();
          _deleteIfExists(nativePath);
        }
      },
    );

    test('provider dialog forwards html args to the native channel', () async {
      const nativePath = '/tmp/ach-native-report.html';
      _mockSaveLocation((call) async {
        expect(call.method, 'getSavePath');
        final args = call.arguments as Map<dynamic, dynamic>;
        expect(args['suggestedName'], 'config-overview-report.html');
        final typeGroups = args['acceptedTypeGroups'] as List<dynamic>;
        expect(typeGroups, hasLength(1));
        final extensions =
            (typeGroups.first as Map<dynamic, dynamic>)['extensions']
                as List<dynamic>;
        expect(extensions, ['html']);
        return nativePath;
      });
      try {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final dialog = container.read(saveFileDialogProvider);
        expect(
          await dialog('config-overview-report.html', 'html'),
          nativePath,
        );

        final service = ReportSaveService(saveFileDialog: dialog);
        expect(await service.saveHtml(const []), isTrue);
        expect(File(nativePath).existsSync(), isTrue);
      } finally {
        _clearSaveLocationMock();
        _deleteIfExists(nativePath);
      }
    });

    test('service returns false when provider dialog is cancelled', () async {
      _mockSaveLocation((call) async => null);
      try {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = ReportSaveService(
          saveFileDialog: container.read(saveFileDialogProvider),
        );
        expect(await service.saveHtml(const []), isFalse);
      } finally {
        _clearSaveLocationMock();
      }
    });
  });
}
