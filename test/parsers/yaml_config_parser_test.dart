import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YamlConfigParser', () {
    late YamlConfigParser parser;
    const testPath = '/path/to/.config.yaml';
    const testTool = 'TestAgent';

    setUp(() {
      parser = YamlConfigParser();
    });

    test('parses empty string to default config', () {
      final config = parser.parse('', filePath: testPath, toolName: testTool);
      expect(config.rules, isEmpty);
      expect(config.rawSettings, isEmpty);
    });

    test('throws ConfigParseException on invalid YAML syntax', () {
      expect(
        () => parser.parse('[}', filePath: testPath, toolName: testTool),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('throws ConfigParseException on non-map root', () {
      expect(
        () => parser.parse(
          '- array_root',
          filePath: testPath,
          toolName: testTool,
        ),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('ConfigParseException has line/column for invalid YAML', () {
      try {
        parser.parse(
          'rules:\n  - item\n  invalid: [}',
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

    test('safely extracts rules and converts Yaml structures deeply', () {
      const yamlStr = '''
rules:
  - rule1
  - rule2
nested:
  key: value
''';

      final config = parser.parse(
        yamlStr,
        filePath: testPath,
        toolName: testTool,
      );
      expect(config.rules, equals(['rule1', 'rule2']));

      final nested = config.rawSettings['nested'];
      expect(nested, isA<Map<String, Object?>>());
      expect((nested as Map<String, Object?>?)?['key'], equals('value'));
    });

    test('serializes ToolConfig correctly while preserving comments', () {
      const original = '''
# Main config
extra_key: value
rules:
  - always be polite # important rule
''';

      final config = parser.parse(
        original,
        filePath: testPath,
        toolName: testTool,
      );

      final updatedConfig = config.copyWith(
        rules: ['always be polite', 'new rule'],
        permissions: ['read'],
      );

      final yamlOutput = parser.serialize(
        updatedConfig,
        originalContent: original,
      );

      // Should preserve comments
      expect(yamlOutput, contains('# Main config'));
      expect(yamlOutput, contains('extra_key: value'));
      expect(yamlOutput, contains('- new rule'));
      expect(yamlOutput, contains('permissions:'));
      expect(yamlOutput, contains('- read'));
    });

    test('serializes from scratch if original is empty', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.yaml,
        rules: const ['rule1'],
        rawSettings: const {'key': 'value'},
      );

      final output = parser.serialize(config);
      expect(output, contains('key: value'));
      expect(output, contains('rules:'));
      expect(output, contains('- rule1'));
    });
    test('round-trip parse -> serialize -> parse preserves comments', () {
      const originalYaml = '''
# Main config
rules:
  - rule1 # inline comment
extra_key: value
''';
      final parsedConfig = parser.parse(
        originalYaml,
        filePath: 'test.yaml',
        toolName: 'test',
      );
      final serializedYaml = parser.serialize(
        parsedConfig,
        originalContent: originalYaml,
      );
      expect(serializedYaml, contains('# Main config'));
      expect(serializedYaml, contains('# inline comment'));

      final roundTrippedConfig = parser.parse(
        serializedYaml,
        filePath: 'test.yaml',
        toolName: 'test',
      );
      expect(roundTrippedConfig, equals(parsedConfig));
    });
  });
}
