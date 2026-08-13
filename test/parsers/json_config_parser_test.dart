import 'dart:convert';

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

    test('serializes ToolConfig with permissions correctly', () {
      final config = ToolConfig(
        toolName: testTool,
        filePath: testPath,
        format: ConfigFormat.json,
        permissions: const ['read_files'],
        rawSettings: const {'extra_key': 'value'},
      );

      final jsonOutput = parser.serialize(config);
      expect(jsonOutput, contains('"permissions": ['));
      expect(jsonOutput, contains('"read_files"'));
      expect(jsonOutput, isNot(contains('"rules"')));
    });
    test('round-trip parse -> serialize -> parse', () {
      const originalJson = '''
{
  "rules": [
    "rule1"
  ],
  "permissions": [
    "perm1"
  ],
  "extra_key": "value"
}''';
      final parsedConfig = parser.parse(
        originalJson,
        filePath: 'test.json',
        toolName: 'test',
      );
      final serializedJson = parser.serialize(parsedConfig);
      final roundTrippedConfig = parser.parse(
        serializedJson,
        filePath: 'test.json',
        toolName: 'test',
      );
      expect(roundTrippedConfig, equals(parsedConfig));
    });

    test(
      'parses JSONC with comments, trailing commas, and string literals',
      () {
        const input = '''
{
  // A line comment
  "schema": "https://opencode.ai/config.json", /* block */
  "rules": ["a", "b",], // Trailing comma in array
  "permissions": [
    "read",
  ],
}
''';
        final config = parser.parse(
          input,
          filePath: 'opencode.json',
          toolName: 'Opencode',
        );

        expect(config.rules, ['a', 'b']);
        expect(config.permissions, ['read']);
        expect(config.rawSettings['schema'], 'https://opencode.ai/config.json');
      },
    );

    test('serializes and preserves JSONC comments and trailing commas', () {
      const original = '''
{
  // A line comment
  "schema": "https://opencode.ai/config.json", /* block */
  "rules": ["a"], // Rule array
  "permissions": [
    "read",
  ],
}
''';
      final config = parser.parse(
        original,
        filePath: 'test.json',
        toolName: 'Test',
      );

      // Mutate
      final mutated = config.copyWith(
        rules: ['a', 'c'],
        permissions: const [],
      );

      final serialized = parser.serialize(mutated, originalContent: original);

      // Expected to preserve comments and layout as much as possible
      expect(serialized, contains('// A line comment'));
      expect(serialized, contains('https://opencode.ai/config.json'));
      expect(serialized, contains('/* block */'));
      expect(serialized, contains('"rules": ["a","c"]'));
      expect(serialized, contains('// Rule array'));

      // Parse it back to verify it's still valid
      final roundTrip = parser.parse(
        serialized,
        filePath: 'test.json',
        toolName: 'Test',
      );
      expect(roundTrip.rules, ['a', 'c']);
      expect(roundTrip.permissions, <String>[]);
    });

    test('handles missing fields gracefully on serialize', () {
      const original = '''
{
  "schema": "https://opencode.ai"
}
''';
      final config = parser.parse(
        original,
        filePath: 'test.json',
        toolName: 'Test',
      );
      final mutated = config.copyWith(rules: ['new']);
      final serialized = parser.serialize(mutated, originalContent: original);

      expect(serialized, contains('"rules": ["new"]'));
    });

    test('preserves nested permissions when serializing unrelated edits', () {
      const original = '''
{
  "rules": ["old"],
  "permissions": {"allow": ["Bash"], "deny": ["rm -rf"]}
}
''';
      final config = parser.parse(
        original,
        filePath: 'test.json',
        toolName: 'Test',
      );

      final serialized = parser.serialize(
        config.copyWith(rules: ['new']),
        originalContent: original,
      );
      final decoded = jsonDecode(serialized) as Map<String, dynamic>;

      expect(decoded['rules'], ['new']);
      expect(decoded['permissions'], {
        'allow': ['Bash'],
        'deny': ['rm -rf'],
      });
    });

    test('deletes JSONC properties with comments before their commas', () {
      const originals = <String>[
        '''
{"rules": [] /* note */, "other": true}''',
        '''
{"rules": [] // note
, "other": true}''',
      ];

      for (final original in originals) {
        final config = parser.parse(
          original,
          filePath: 'test.jsonc',
          toolName: 'Test',
        );
        final serialized = parser.serialize(
          config,
          originalContent: original,
        );
        final reparsed = parser.parse(
          serialized,
          filePath: 'test.jsonc',
          toolName: 'Test',
        );

        expect(reparsed.rawSettings['other'], isTrue);
        expect(reparsed.rawSettings.containsKey('rules'), isFalse);
      }
    });
  });
}
