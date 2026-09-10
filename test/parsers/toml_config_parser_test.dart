import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toml/toml.dart';

void main() {
  group('TomlConfigParser', () {
    late TomlConfigParser parser;
    const testPath = '/path/to/.config.toml';
    const testTool = 'TestAgent';

    setUp(() {
      parser = TomlConfigParser();
    });

    test('parses empty string to default config', () {
      final config = parser.parse('', filePath: testPath, toolName: testTool);
      expect(config.rules, isEmpty);
      expect(config.rawSettings, isEmpty);
    });

    test('throws ConfigParseException on invalid TOML syntax', () {
      expect(
        () => parser.parse(
          'bad = = toml',
          filePath: testPath,
          toolName: testTool,
        ),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('ConfigParseException has line/column for invalid TOML', () {
      try {
        parser.parse(
          'rules = ["ok"\nbad = = toml',
          filePath: testPath,
          toolName: testTool,
        );
        fail('Expected ConfigParseException');
      } on ConfigParseException catch (e) {
        expect(e.line, isNotNull);
        expect(e.column, isNotNull);
        expect(e.line, greaterThan(0));
      }
    });

    test('safely extracts rules', () {
      const tomlStr = '''
rules = ["rule1", "rule2"]
[nested]
key = "value"
''';

      final config = parser.parse(
        tomlStr,
        filePath: testPath,
        toolName: testTool,
      );
      expect(config.rules, equals(['rule1', 'rule2']));

      final nested = config.rawSettings['nested'];
      expect(nested, isA<Map<String, Object?>>());
    });

    test('serializes ToolConfig correctly', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.toml,
        rules: const ['rule1'],
        rawSettings: const {'extra_key': 'value'},
      );

      final tomlOutput = parser.serialize(config);
      final parsed = TomlDocument.parse(tomlOutput).toMap();
      expect(parsed['extra_key'], equals('value'));
      expect(parsed['rules'], equals(['rule1']));
    });
    test('round-trip parse -> serialize -> parse', () {
      const originalToml = '''
extra_key = "value"
rules = ["rule1"]
''';
      final parsedConfig = parser.parse(
        originalToml,
        filePath: 'test.toml',
        toolName: 'test',
      );
      final serializedToml = parser.serialize(parsedConfig);
      final roundTrippedConfig = parser.parse(
        serializedToml,
        filePath: 'test.toml',
        toolName: 'test',
      );
      // Normalize originalContent before comparing since the serialization
      // reformats the raw text.
      expect(
        roundTrippedConfig,
        equals(parsedConfig.copyWith(originalContent: serializedToml)),
      );
    });

    test(
      'explicitly discards comments and reorders during serialization '
      '(known limitation)',
      () {
        const originalToml = '''
# This is a comment
rules = ["rule1"]
[nested]
key = "value"
''';
        final parsedConfig = parser.parse(
          originalToml,
          filePath: 'test.toml',
          toolName: 'test',
        );
        // Pass the original content to serialize, simulating a structured save
        final serializedToml = parser.serialize(
          parsedConfig,
          originalContent: originalToml,
        );

        // Assert that comments are lost (raw-text check).
        expect(serializedToml.contains('# This is a comment'), isFalse);

        // Assert TOML semantics, not the encoder's quote/format style, which
        // the caret version constraint permits changing across releases.
        final roundTripped = TomlDocument.parse(serializedToml).toMap();
        expect(roundTripped['rules'], equals(['rule1']));
        expect(roundTripped.containsKey('nested'), isTrue);
      },
    );

    test('serializeWithOutcome always reports usedFallback for TOML', () {
      const originalToml = '''
# comment
rules = ["rule1"]
''';
      final config = parser.parse(
        originalToml,
        filePath: 'test.toml',
        toolName: 'test',
      );
      final outcome = parser.serializeWithOutcome(
        config,
        originalContent: originalToml,
      );
      expect(outcome.usedFallback, isTrue);
    });

    test('preserves a map-shaped permissions table on serialize', () {
      const originalToml = '''
[permissions.project-edit.filesystem]
":minimal" = "read"
''';
      final config = parser.parse(
        originalToml,
        filePath: testPath,
        toolName: testTool,
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(
        (roundTripped['permissions']! as Map)['project-edit'],
        (config.rawSettings['permissions']! as Map)['project-edit'],
      );
    });

    test('preserves a scalar rules value on serialize', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.toml,
        originalContent: 'rules = "legacy"\n',
        rawSettings: const {'rules': 'legacy'},
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(roundTripped['rules'], 'legacy');
    });

    test('keeps an absent key absent with an empty list', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.toml,
        originalContent: 'model = "x"\n',
        rawSettings: const {'model': 'x'},
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(roundTripped.containsKey('permissions'), isFalse);
      expect(roundTripped.containsKey('rules'), isFalse);
    });

    test('writes user additions onto an absent key', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.toml,
        originalContent: 'model = "x"\n',
        rules: const ['rule1'],
        rawSettings: const {'model': 'x'},
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(roundTripped['rules'], ['rule1']);
    });

    test('removes a cleared list key', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.toml,
        originalContent: 'rules = ["rule1"]\n',
        rawSettings: const {
          'rules': ['rule1'],
        },
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(roundTripped.containsKey('rules'), isFalse);
    });

    test('preserves map tables for a manual-path-shaped TOML file', () {
      // The preservation rule lives in the shared parser, so manual paths
      // and any current or future TOML tool are covered the same way.
      const originalToml = '''
[permissions.profx.filesystem]
":minimal" = "read"
''';
      final config = parser.parse(
        originalToml,
        filePath: '/elsewhere/manual.toml',
        toolName: 'Manual',
      );

      final serialized = parser.serialize(config);
      final roundTripped = TomlDocument.parse(serialized).toMap();
      expect(
        (roundTripped['permissions']! as Map)['profx'],
        (config.rawSettings['permissions']! as Map)['profx'],
      );
    });
  });
}
