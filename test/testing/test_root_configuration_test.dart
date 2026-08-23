import 'dart:io';

import 'package:agents_config_helper/testing/test_root_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('test_root_configuration_');
    await File(
      p.join(root.path, testRootMarkerFileName),
    ).writeAsString(testRootMarkerContents);
  });

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('returns null when test-root mode is not requested', () async {
    expect(await TestRootConfiguration.fromArguments(const []), isNull);
  });

  test('accepts a marked absolute directory on macOS', () async {
    final configuration = await TestRootConfiguration.fromArguments([
      '--test-root=${root.path}',
    ]);

    if (Platform.isMacOS) {
      expect(configuration?.rootPath, root.resolveSymbolicLinksSync());
    } else {
      expect(configuration, isNull);
    }
  }, skip: !Platform.isMacOS);

  test('rejects missing values, duplicates, and relative paths', () async {
    expect(
      () => TestRootConfiguration.fromArguments(const ['--test-root=']),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => TestRootConfiguration.fromArguments([
        '--test-root=${root.path}',
        '--test-root=${root.path}',
      ]),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => TestRootConfiguration.fromArguments(const ['--test-root=relative']),
      throwsA(isA<ArgumentError>()),
    );
  }, skip: !Platform.isMacOS);

  test('rejects an unmarked directory', () async {
    final unmarked = await Directory.systemTemp.createTemp(
      'unmarked_test_root_',
    );
    addTearDown(() => unmarked.delete(recursive: true));

    expect(
      () => TestRootConfiguration.fromArguments([
        '--test-root=${unmarked.path}',
      ]),
      throwsA(isA<ArgumentError>()),
    );
  }, skip: !Platform.isMacOS);

  test('rejects a root with an unexpected marker value', () async {
    await File(
      p.join(root.path, testRootMarkerFileName),
    ).writeAsString('not a staging root');

    expect(
      () => TestRootConfiguration.fromArguments([
        '--test-root=${root.path}',
      ]),
      throwsA(isA<ArgumentError>()),
    );
  }, skip: !Platform.isMacOS);

  test('rejects a symbolic-link root', () async {
    final linkedRoot = Directory(
      p.join(root.parent.path, 'linked_test_root_${root.path.hashCode}'),
    );
    await Link(linkedRoot.path).create(root.path);
    addTearDown(() => Link(linkedRoot.path).delete());

    expect(
      () => TestRootConfiguration.fromArguments([
        '--test-root=${linkedRoot.path}',
      ]),
      throwsA(isA<ArgumentError>()),
    );
  }, skip: !Platform.isMacOS);
}
