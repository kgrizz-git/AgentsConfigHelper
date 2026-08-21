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

  group('ignoredNonAbsolutePathMessage', () {
    test('uses a shared wording template for all source labels', () {
      expect(
        ignoredNonAbsolutePathMessage(
          sourceLabel: 'COPILOT_HOME',
          raw: '~/copilot',
        ),
        'Ignoring COPILOT_HOME because it is not an absolute path '
        '(got "~/copilot").',
      );
      expect(
        ignoredNonAbsolutePathMessage(
          sourceLabel: 'normalizedCopilotHomePath',
          raw: 'relative-home',
        ),
        'Ignoring normalizedCopilotHomePath because it is not an absolute '
        'path (got "relative-home").',
      );
    });
  });
}
