import 'dart:io';

import 'package:agents_config_helper/services/file_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalFileOperations Windows replacement', () {
    late Directory tempDir;
    const operations = LocalFileOperations();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('atomic_windows_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('replaces an existing destination and leaves no temp', () async {
      if (!Platform.isWindows) return;
      final target = File(p.join(tempDir.path, 'config.json'));
      await target.writeAsString('old');

      await operations.writeTextAtomically(target.path, 'new');

      expect(await target.readAsString(), 'new');
      expect(await _temporaryFiles(tempDir), isEmpty);
    });

    test('a deny-share holder blocks replacement without changing the '
        'destination', () async {
      if (!Platform.isWindows) return;
      final target = File(p.join(tempDir.path, 'held.json'));
      await target.writeAsString('old');
      final ready = File(p.join(tempDir.path, 'holder-ready'));
      final script = File(p.join(tempDir.path, 'hold.ps1'));
      await script.writeAsString(r'''
param([string]$Target, [string]$Ready)
$stream = [System.IO.File]::Open(
  $Target,
  [System.IO.FileMode]::Open,
  [System.IO.FileAccess]::ReadWrite,
  [System.IO.FileShare]::None
)
try {
  Set-Content -Path $Ready -Value 'ready'
  Start-Sleep -Seconds 60
} finally {
  $stream.Close()
}
''');
      Process? holder;
      try {
        holder = await Process.start(
          'powershell.exe',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            script.path,
            target.path,
            ready.path,
          ],
        );
        await _waitForFile(ready);

        await expectLater(
          operations.writeTextAtomically(target.path, 'new'),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        if (holder != null) {
          holder.kill();
          await holder.exitCode;
        }
      }

      expect(await target.readAsString(), 'old');
      expect(await _temporaryFiles(tempDir), isEmpty);
    });
  });
}

Future<void> _waitForFile(File file) async {
  for (var attempt = 0; attempt < 600; attempt++) {
    if (file.existsSync()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('PowerShell holder did not become ready');
}

Future<List<String>> _temporaryFiles(Directory directory) async {
  final names = await directory
      .list()
      .map((entity) => p.basename(entity.path))
      .toList();
  return names
      .where((name) => name.startsWith('.agents-config-helper-'))
      .toList();
}
