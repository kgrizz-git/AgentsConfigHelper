import 'dart:convert';
import 'dart:io';

import 'package:agents_config_helper/services/discovery_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late DiscoveryPreferencesStore store;
  late File preferencesFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'discovery_preferences_store_test_',
    );
    store = DiscoveryPreferencesStore(
      getDirectory: () async => tempDir,
      fileName: 'test_prefs.json',
    );
    preferencesFile = File(p.join(tempDir.path, 'test_prefs.json'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'load() returns default empty preferences when file is missing',
    () async {
      final result = await store.load();
      expect(result.preferences.version, 1);
      expect(result.preferences.manualFilePaths, isEmpty);
      expect(result.preferences.projectRoots, isEmpty);
      expect(result.warnings, isEmpty);
    },
  );

  test('load() warns and recovers from invalid JSON', () async {
    await preferencesFile.writeAsString('this is not json');

    final result = await store.load();
    expect(result.preferences.manualFilePaths, isEmpty);
    expect(result.warnings, contains(contains('invalid JSON')));
  });

  test('load() warns and recovers if top-level is not an object', () async {
    await preferencesFile.writeAsString('["not", "an", "object"]');

    final result = await store.load();
    expect(result.preferences.manualFilePaths, isEmpty);
    expect(result.warnings, contains(contains('must contain a JSON object')));
  });

  test(
    'load() extracts what it can from malformed JSON and warns about '
    'wrong types',
    () async {
      await preferencesFile.writeAsString(
        jsonEncode({
          'version': 'two', // string instead of int
          'manualFilePaths': [
            '/valid/path',
            42,
            '/another/path',
          ], // contains int
          'projectRoots': 'not a list', // string instead of list
        }),
      );

      final result = await store.load();
      expect(result.preferences.version, 1); // fallback
      expect(result.preferences.manualFilePaths, [
        '/valid/path',
        '/another/path',
      ]); // extracted strings
      expect(result.preferences.projectRoots, isEmpty); // failed to parse

      expect(
        result.warnings,
        contains(contains("'version' is not an integer")),
      );
      expect(
        result.warnings,
        contains(contains('contains non-string elements')),
      );
      expect(
        result.warnings,
        contains(contains("'projectRoots' is not a list")),
      );
    },
  );

  test('load() deduplicates and normalizes entries', () async {
    final pathA = p.join(tempDir.path, 'path', 'A');
    final pathB = p.join(tempDir.path, 'path', 'B');
    final rootC = p.join(tempDir.path, 'proj', 'C');

    await preferencesFile.writeAsString(
      jsonEncode({
        'version': 1,
        'manualFilePaths': [pathA, ' $pathA ', ' ', pathB],
        'projectRoots': [rootC, rootC],
      }),
    );

    final result = await store.load();
    expect(result.preferences.manualFilePaths, [pathA, pathB]);
    expect(result.preferences.projectRoots, [rootC]);

    expect(
      result.warnings,
      contains(contains('Removed duplicate or empty paths')),
    );
  });

  test(
    'addManualPath() creates file with deduplication and normalization',
    () async {
      await store.addManualPath('/path/one');
      await store.addManualPath(' /path/one ');
      await store.addManualPath('/path/two');

      final result = await store.load();
      expect(result.preferences.manualFilePaths, ['/path/one', '/path/two']);
      expect(result.warnings, isEmpty);

      // Check file contents
      final content = await preferencesFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['manualFilePaths'], ['/path/one', '/path/two']);
    },
  );

  test('removeManualPath() removes the specified path only', () async {
    await store.addManualPath('/path/one');
    await store.addManualPath('/path/two');

    await store.removeManualPath(' /path/one ');

    final result = await store.load();
    expect(result.preferences.manualFilePaths, ['/path/two']);
  });

  test('addProjectRoot() creates file with deduplication', () async {
    await store.addProjectRoot('/root/one');
    await store.addProjectRoot('/root/one');

    final result = await store.load();
    expect(result.preferences.projectRoots, ['/root/one']);
  });

  test('removeProjectRoot() removes the specified root', () async {
    await store.addProjectRoot('/root/A');
    await store.addProjectRoot('/root/B');

    await store.removeProjectRoot('/root/A');

    final result = await store.load();
    expect(result.preferences.projectRoots, ['/root/B']);
  });

  test(
    'writes leave only the preferences file behind (atomic temp+rename)',
    () async {
      await store.addManualPath('/path/atomic');

      expect(preferencesFile.existsSync(), isTrue);
      // The temp file used for the atomic rename must not linger.
      final fileNames = tempDir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(fileNames, ['test_prefs.json']);

      final content = await preferencesFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json['manualFilePaths'], ['/path/atomic']);
    },
  );
}
