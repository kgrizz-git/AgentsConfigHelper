import 'package:agents_config_helper/parsers/config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigParseException', () {
    test('toString returns formatted message', () {
      const exception = ConfigParseException('test error');
      expect(exception.toString(), equals('ConfigParseException: test error'));
    });
  });
}
