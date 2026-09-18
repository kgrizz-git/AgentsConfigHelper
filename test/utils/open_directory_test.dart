import 'dart:io';

import 'package:agents_config_helper/utils/open_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('revealFile', () {
    late Directory tempDir;
    late File file;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ach reveal file test');
      file = File('${tempDir.path}/settings.json')..writeAsStringSync('{}');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('selects a file in Finder on macOS', () async {
      final invocation = await _revealAndCapture(file, 'macos');

      expect(invocation.command, 'open');
      expect(invocation.arguments, ['-R', file.path]);
    });

    test('selects a file in Explorer on Windows', () async {
      final invocation = await _revealAndCapture(file, 'windows');

      expect(invocation.command, 'explorer');
      expect(invocation.arguments, ['/select,', file.path]);
    });

    test('opens the parent directory on Linux', () async {
      final invocation = await _revealAndCapture(file, 'linux');

      expect(invocation.command, 'xdg-open');
      expect(invocation.arguments, [tempDir.path]);
    });

    test('does not launch a missing file', () async {
      var wasCalled = false;

      final revealed = await revealFile(
        File('${tempDir.path}/missing.json'),
        operatingSystem: 'macos',
        runProcess: (_, _) async {
          wasCalled = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      expect(revealed, isFalse);
      expect(wasCalled, isFalse);
    });

    test('reports a launcher failure', () async {
      final revealed = await revealFile(
        file,
        operatingSystem: 'macos',
        runProcess: (_, _) async => ProcessResult(0, 1, '', 'failed'),
      );

      expect(revealed, isFalse);
    });

    test('reports a launcher exception', () async {
      final revealed = await revealFile(
        file,
        operatingSystem: 'macos',
        runProcess: (_, _) => throw const ProcessException('open', []),
      );

      expect(revealed, isFalse);
    });
  });
}

Future<_Invocation> _revealAndCapture(File file, String operatingSystem) async {
  late _Invocation invocation;
  final revealed = await revealFile(
    file,
    operatingSystem: operatingSystem,
    runProcess: (command, arguments) async {
      invocation = _Invocation(command, arguments);
      return ProcessResult(0, 0, '', '');
    },
  );

  expect(revealed, isTrue);
  return invocation;
}

class _Invocation {
  const new(this.command, this.arguments);

  final String command;
  final List<String> arguments;
}
