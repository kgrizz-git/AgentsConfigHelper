import 'dart:io';

import 'package:agents_config_helper/services/macos_test_root_file_operations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'agents_config_helper/test_root_file_operations',
  );
  late Directory root;
  late List<MethodCall> calls;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('macos_test_root_bridge_');
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'fileExists':
              return true;
            case 'readText':
              return 'fixture content';
            case 'listFiles':
              return ['first.bak'];
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('maps in-root paths to relative native bridge arguments', () async {
    final operations = MacOSTestRootFileOperations(
      rootPath: root.path,
      platformIsMacOS: true,
    );
    final configPath = p.join(root.path, '.claude', 'settings.json');

    await operations.writeText(configPath, '{"rules": []}');
    expect(calls.single.method, 'writeText');
    expect(calls.single.arguments, {
      'rootPath': root.path,
      'relativePath': '.claude/settings.json',
      'text': '{"rules": []}',
    });

    expect(await operations.fileExists(configPath), isTrue);
    expect(await operations.readText(configPath), 'fixture content');
    expect(
      await operations.listFiles(p.join(root.path, 'application-support')),
      [p.join(root.path, 'application-support', 'first.bak')],
    );
  });

  test('rejects an outside path before invoking the native bridge', () async {
    final operations = MacOSTestRootFileOperations(
      rootPath: root.path,
      platformIsMacOS: true,
    );
    final outsidePath = p.join(root.parent.path, 'outside.json');

    await expectLater(
      operations.fileExists(outsidePath),
      throwsA(isA<FileSystemException>()),
    );
    expect(calls, isEmpty);
  });
}
