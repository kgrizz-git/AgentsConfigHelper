import 'package:agents_config_helper/services/desktop_window_configuration.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopWindowConfiguration.forVisibleSize', () {
    test('uses 75 percent of a normal display', () {
      final configuration = DesktopWindowConfiguration.forVisibleSize(
        const Size(1920, 1080),
      );

      expect(configuration.size, const Size(1440, 810));
      expect(
        configuration.minimumSize,
        DesktopWindowConfiguration.preferredMinimumSize,
      );
    });

    test('keeps the initial window at least usable on a small display', () {
      final configuration = DesktopWindowConfiguration.forVisibleSize(
        const Size(1024, 768),
      );

      expect(configuration.size, const Size(800, 600));
      expect(
        configuration.minimumSize,
        DesktopWindowConfiguration.preferredMinimumSize,
      );
    });

    test('does not request dimensions outside a very small display', () {
      final configuration = DesktopWindowConfiguration.forVisibleSize(
        const Size(640, 480),
      );

      expect(configuration.size, const Size(640, 480));
      expect(configuration.minimumSize, const Size(640, 480));
    });

    test('falls back when the platform reports no usable display size', () {
      final configuration = DesktopWindowConfiguration.forVisibleSize(null);

      expect(configuration.size, DesktopWindowConfiguration.fallbackSize);
      expect(
        configuration.minimumSize,
        DesktopWindowConfiguration.preferredMinimumSize,
      );
    });
  });
}
