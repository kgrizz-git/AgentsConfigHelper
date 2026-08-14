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
      expect(roundTrippedConfig, equals(parsedConfig));
    });

    test(
      'explicitly discards comments and reorders during serialization (known limitation)',
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

        // Assert that comments are lost
        expect(serializedToml.contains('# This is a comment'), isFalse);

        // And the structure is reformatted
        expect(serializedToml, contains("rules = ['rule1']"));
        expect(serializedToml, contains('[nested]'));
      },
    );
  });
}
