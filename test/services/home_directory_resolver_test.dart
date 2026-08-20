import 'package:agents_config_helper/services/home_directory_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('absoluteNormalizedPath', () {
    test('accepts absolute paths', () {
      final absolute = p.join(p.separator, 'tmp', 'copilot');
      expect(absoluteNormalizedPath(absolute), p.normalize(absolute));
    });

    test('rejects relative and empty values', () {
      expect(absoluteNormalizedPath(null), isNull);
      expect(absoluteNormalizedPath(''), isNull);
      expect(absoluteNormalizedPath('relative/copilot'), isNull);
      expect(absoluteNormalizedPath('./copilot'), isNull);
      expect(absoluteNormalizedPath('~/copilot'), isNull);
    });
  });
}
