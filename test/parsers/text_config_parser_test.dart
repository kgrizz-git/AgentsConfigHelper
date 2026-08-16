import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/text_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextConfigParser', () {
    late TextConfigParser parser;

    setUp(() {
      parser = TextConfigParser();
    });

    test('parse handles markdown files correctly', () {
      const content = '# Instruction Document\n\nSome text';
      final config = parser.parse(
        content,
        filePath: '/project/AGENTS.md',
        toolName: 'Claude Code',
      );

      expect(config.format, ConfigFormat.markdown);
      expect(config.toolName, 'Claude Code');
      expect(config.filePath, '/project/AGENTS.md');
      expect(config.originalContent, content);
      expect(config.rules, isEmpty);
      expect(config.permissions, isEmpty);
      expect(config.rawSettings, isEmpty);
    });

    test('parse handles generic text files correctly', () {
      const content = 'Some random plain text rules.';
      final config = parser.parse(
        content,
        filePath: '/project/.cursorrules',
        toolName: 'Cursor',
      );

      expect(config.format, ConfigFormat.text);
      expect(config.toolName, 'Cursor');
      expect(config.filePath, '/project/.cursorrules');
      expect(config.originalContent, content);
      expect(config.rules, isEmpty);
      expect(config.permissions, isEmpty);
      expect(config.rawSettings, isEmpty);
    });

    test('parse handles .mdc files correctly', () {
      const content = '''
---
description: Test
---
Some random plain text rules.''';
      final config = parser.parse(
        content,
        filePath: '/project/.cursor/rules/test.mdc',
        toolName: 'Cursor',
      );

      expect(config.format, ConfigFormat.markdown);
      expect(config.toolName, 'Cursor');
      expect(config.filePath, '/project/.cursor/rules/test.mdc');
      expect(config.originalContent, content);
    });

    test('serialize simply returns original content', () {
      const original = 'original text';
      final config = ToolConfig(
        toolName: 'Test',
        filePath: '/test.md',
        format: ConfigFormat.markdown,
        originalContent: original,
      );

      expect(parser.serialize(config), original);
    });

    test('serialize honors the originalContent argument when provided', () {
      const original = 'original text';
      final config = ToolConfig(
        toolName: 'Test',
        filePath: '/test.md',
        format: ConfigFormat.markdown,
        originalContent: original,
      );

      expect(
        parser.serialize(config, originalContent: 'some overridden text'),
        'some overridden text',
      );
    });

    test('parse detects markdown format for uppercase extensions', () {
      final config = parser.parse(
        'Some text',
        filePath: '/path/to/README.MD',
        toolName: 'Claude Code',
      );

      expect(config.format, ConfigFormat.markdown);
    });
  });
}
