import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YamlConfigParser serialize fidelity fixtures', () {
    late YamlConfigParser parser;
    const testPath = '/path/to/.config.yaml';
    const testTool = 'TestAgent';

    setUp(() {
      parser = YamlConfigParser();
    });

    test('fixture: comment adjacent to edited rawSettings key is '
        'preserved', () {
      const original = '''
# file-level header
model: default-model
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updated = config.copyWith(
        rawSettings: {'model': 'new-model'},
      );

      final outcome = parser.serializeWithOutcome(
        updated,
        originalContent: original,
      );

      // Header comment adjacent to the unedited region must survive.
      expect(outcome.content, contains('# file-level header'));
      // The edited key value changes.
      expect(outcome.content, contains('model: new-model'));
      // Unchanged keys adjacent to the edit survive.
      expect(outcome.content, contains('rules:'));
      expect(outcome.content, contains('- rule1'));
      expect(outcome.usedFallback, isFalse);
    });

    test('fixture: comment between a key and its block value is '
        'lost on in-place update', () {
      const original = '''
settings:
  # timeout configuration
  timeout: 30
  retries: 3
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updated = config.copyWith(
        rawSettings: {
          'settings': {'timeout': 60, 'retries': 5},
        },
      );

      final outcome = parser.serializeWithOutcome(
        updated,
        originalContent: original,
      );

      // Comment inside a map is not preserved by yaml_edit when the
      // parent key is updated in-place.
      expect(outcome.content, isNot(contains('# timeout configuration')));
      // Values are still updated correctly.
      expect(outcome.content, contains('timeout: 60'));
      expect(outcome.content, contains('retries: 5'));
      // Unchanged keys survive.
      expect(outcome.content, contains('rules:'));
      expect(outcome.content, contains('- rule1'));
      expect(outcome.usedFallback, isFalse);
    });

    test('fixture: anchor and alias cause yaml_edit to throw; '
        'serializer falls back without throwing', () {
      const original = '''
defaults: &defaults
  timeout: 30
service:
  <<: *defaults
  timeout: 60
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updated = config.copyWith(
        rawSettings: {
          'defaults': {'timeout': 45},
          'service': {'timeout': 90},
        },
      );

      // yaml_edit throws AssertionError on this shape; the serializer
      // now catches it and takes the fallback.
      final outcome = parser.serializeWithOutcome(
        updated,
        originalContent: original,
      );
      expect(outcome.usedFallback, isTrue);
      expect(outcome.content, contains('timeout: 45'));
      expect(outcome.content, contains('timeout: 90'));
    });

    test('fixture: block scalar adjacent to edit is rewritten as a '
        'double-quoted scalar', () {
      const original = '''
readme: |
  Line one
  Line two
rules:
  - rule1
model: default
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      // Edit an unrelated key to force a mixed update.
      final updated = config.copyWith(
        rawSettings: {'readme': 'Line one\nLine two', 'model': 'new-model'},
      );

      final output = parser.serialize(
        updated,
        originalContent: original,
      );

      // yaml_edit converts the block scalar to a double-quoted string.
      expect(output, contains(r'readme: "Line one\nLine two"'));
      expect(output, contains('model: new-model'));
      expect(output, contains('rules:'));
      expect(output, contains('- rule1'));
    });

    test('fixture: nested map in rawSettings is preserved', () {
      const original = '''
nested:
  deep:
    value: original
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updated = config.copyWith(
        rawSettings: {
          'nested': {
            'deep': {'value': 'updated'},
          },
        },
      );

      final output = parser.serialize(
        updated,
        originalContent: original,
      );

      expect(output, contains('nested:'));
      expect(output, contains('deep:'));
      expect(output, contains('value: updated'));
      expect(output, contains('rules:'));
      expect(output, contains('- rule1'));
    });

    test('fixture: unsupported list in rawSettings is updated and '
        'preserved', () {
      const original = '''
# config start
list_setting:
  - item1
  - item2
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      // Keep the list as-is via rawSettings so the serializer visits it.
      final updated = config.copyWith(
        rawSettings: {
          'list_setting': ['item1', 'item2', 'item3'],
        },
      );

      final output = parser.serialize(
        updated,
        originalContent: original,
      );

      expect(output, contains('# config start'));
      expect(output, contains('list_setting:'));
      expect(output, contains('- item1'));
      expect(output, contains('- item3'));
      expect(output, contains('rules:'));
      expect(output, contains('- rule1'));
    });

    test('fixture: alias target key edited causes yaml_edit to throw; '
        'serializer falls back without throwing', () {
      const original = '''
base: &base
  timeout: 30
override:
  <<: *base
  timeout: 60
rules:
  - rule1
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updated = config.copyWith(
        rawSettings: {
          'base': {'timeout': 45},
          'override': {'timeout': 90},
        },
      );

      // yaml_edit throws AssertionError on this shape; the serializer
      // now catches it and takes the fallback.
      final outcome = parser.serializeWithOutcome(
        updated,
        originalContent: original,
      );
      expect(outcome.usedFallback, isTrue);
      expect(outcome.content, contains('timeout: 45'));
      expect(outcome.content, contains('timeout: 90'));
    });
  });
}
