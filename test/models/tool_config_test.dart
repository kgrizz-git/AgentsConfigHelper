import 'package:agents_config_helper/models/tool_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolConfig', () {
    test('supports value equality', () {
      final config1 = ToolConfig(
        toolName: 'Claude',
        filePath: 'path',
        format: ConfigFormat.json,
        rules: const ['rule1'],
      );
      final config2 = ToolConfig(
        toolName: 'Claude',
        filePath: 'path',
        format: ConfigFormat.json,
        rules: const ['rule1'],
      );
      final config3 = ToolConfig(
        toolName: 'Cursor',
        filePath: 'path',
        format: ConfigFormat.json,
        rules: const ['rule1'],
      );

      expect(config1, equals(config2));
      expect(
        config1.props,
        equals([
          'Claude',
          'path',
          ConfigFormat.json,
          const ['rule1'],
          const <String>[],
          const <String, Object?>{},
          '',
        ]),
      );
      expect(config1, isNot(equals(config3)));
    });

    test('copyWith creates a new instance with updated values', () {
      final original = ToolConfig(
        toolName: 'Claude',
        filePath: 'path',
        format: ConfigFormat.json,
      );

      final updated = original.copyWith(
        toolName: 'Cursor',
        rules: ['new_rule'],
      );

      expect(updated.toolName, equals('Cursor'));
      expect(updated.rules, equals(['new_rule']));
      expect(updated.filePath, equals('path')); // unchanged
    });

    test('configs differing only in originalContent are not equal', () {
      final config1 = ToolConfig(
        toolName: 'Claude',
        filePath: 'path',
        format: ConfigFormat.json,
        rules: const ['rule1'],
        originalContent: '{"rules":["rule1"]}',
      );
      final config2 = ToolConfig(
        toolName: 'Claude',
        filePath: 'path',
        format: ConfigFormat.json,
        rules: const ['rule1'],
        originalContent: '{"rules":["rule1"],"extra":true}',
      );
      expect(config1, isNot(equals(config2)));
    });
  });
}
