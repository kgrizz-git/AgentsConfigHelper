import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigParseException', () {
    test('toString returns formatted message', () {
      const exception = ConfigParseException('test error');
      expect(exception.toString(), equals('ConfigParseException: test error'));
    });

    test('toString includes position when both line and column present', () {
      const exception = ConfigParseException('bad syntax', line: 3, column: 7);
      expect(
        exception.toString(),
        equals('ConfigParseException: bad syntax at line 3, column 7'),
      );
    });

    test('toString omits position when only line is present', () {
      const exception = ConfigParseException('bad syntax', line: 3);
      expect(exception.toString(), equals('ConfigParseException: bad syntax'));
    });

    test('toString omits position when only column is present', () {
      const exception = ConfigParseException('bad syntax', column: 7);
      expect(exception.toString(), equals('ConfigParseException: bad syntax'));
    });
  });
}
