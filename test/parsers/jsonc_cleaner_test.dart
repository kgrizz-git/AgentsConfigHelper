import 'package:agents_config_helper/parsers/jsonc_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsoncCleaner', () {
    test('removes single line comments', () {
      const input = '{"key": "value"} // a comment\n';
      const expected = '{"key": "value"}             \n';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes block comments', () {
      const input = '{"key": /* block */ "value"}';
      const expected = '{"key":             "value"}';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('ignores // inside strings', () {
      const input = '{"url": "https://example.com"}';
      expect(JsoncCleaner.clean(input), input);
    });

    test('ignores /* */ inside strings', () {
      const input = '{"regex": "/* pattern */"}';
      expect(JsoncCleaner.clean(input), input);
    });

    test('removes // inside /* */', () {
      const input = '/* comment // with line */';
      const expected = '                          ';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes /* inside //', () {
      const input = '// comment /* with block */\n';
      const expected = '                           \n';
      expect(JsoncCleaner.clean(input), expected);
    });

    test('removes trailing commas', () {
      const input = '{"a": 1, "b": 2,}';
      const expected = '{"a": 1, "b": 2 }';
      expect(JsoncCleaner.clean(input), expected);
    });
  });
}
