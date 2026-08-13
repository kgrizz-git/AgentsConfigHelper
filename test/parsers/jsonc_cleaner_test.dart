import 'package:flutter_test/flutter_test.dart';
import 'package:agents_config_helper/parsers/jsonc_cleaner.dart';

void main() {
  group('JsoncCleaner', () {
    test('removes single line comments', () {
      final input = '{"key": "value"} // a comment\n';
      final expected = '{"key": "value"}             \n';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes block comments', () {
      final input = '{"key": /* block */ "value"}';
      final expected = '{"key":             "value"}';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('ignores // inside strings', () {
      final input = '{"url": "https://example.com"}';
      expect(JsoncCleaner.clean(input), input);
    });

    test('ignores /* */ inside strings', () {
      final input = '{"regex": "/* pattern */"}';
      expect(JsoncCleaner.clean(input), input);
    });

    test('removes // inside /* */', () {
      final input = '/* comment // with line */';
      final expected = '                          ';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes /* inside //', () {
      final input = '// comment /* with block */\n';
      final expected = '                           \n';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes trailing commas', () {
      final input = '{"a": 1, "b": 2,}';
      final expected = '{"a": 1, "b": 2 }';
      expect(JsoncCleaner.clean(input), expected);
    });
  });
}
