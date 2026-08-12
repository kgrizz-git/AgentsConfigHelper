import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonConfigParser', () {
    late JsonConfigParser parser;
    const testPath = '/path/to/.config.json';
    const testTool = 'TestAgent';

    setUp(() {
      parser = JsonConfigParser();
    });

    test('parses empty string to default config', () {
      final config = parser.parse('', filePath: testPath, toolName: testTool);
      expect(config.rules, isEmpty);
      expect(config.permissions, isEmpty);
      expect(config.rawSettings, isEmpty);
    });

    test('parses null root to default config', () {
      final config = parser.parse(
        'null',
        filePath: testPath,
        toolName: testTool,
      );
      expect(config.rules, isEmpty);
    });

    test('throws ConfigParseException on invalid JSON syntax', () {
      expect(
        () => parser.parse(
          '{ bad_json }',
          filePath: testPath,
          toolName: testTool,
        ),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('throws ConfigParseException on non-map root', () {
      expect(
        () => parser.parse(
          '["array_root"]',
          filePath: testPath,
          toolName: testTool,
        ),
        throwsA(isA<ConfigParseException>()),
      );
    });

    test('safely extracts rules and permissions', () {
      const jsonStr = '''
      {
        "rules": ["rule1", 123, "rule2"],
        "permissions": "not_a_list",
        "extra_key": true
      }
      ''';

      final config = parser.parse(
        jsonStr,
        filePath: testPath,
        toolName: testTool,
      );

      // Should extract strings and ignore the integer
      expect(config.rules, equals(['rule1', 'rule2']));

      // Should default to empty list because it's not a list
      expect(config.permissions, isEmpty);

      // rawSettings should contain everything
      expect(config.rawSettings['extra_key'], isTrue);
    });

    test('serializes ToolConfig correctly', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.json,
        rules: const ['always be polite'],
        rawSettings: const {'extra_key': 'value'},
      );

      final jsonOutput = parser.serialize(config);
      expect(jsonOutput, contains('"rules": ['));
      expect(jsonOutput, contains('"always be polite"'));
      expect(jsonOutput, contains('"extra_key": "value"'));

      // Should not contain permissions if empty
      expect(jsonOutput, isNot(contains('permissions')));
    });
  });
}
