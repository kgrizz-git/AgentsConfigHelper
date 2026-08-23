import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Calculates initial desktop window dimensions from usable display space.
class DesktopWindowConfiguration {
  /// Creates a desktop window configuration.
  const DesktopWindowConfiguration({
    required this.size,
    required this.minimumSize,
  });

  /// Builds an adaptive layout from the display's usable, rather than full,
  /// size.
  factory DesktopWindowConfiguration.forVisibleSize(Size? visibleSize) {
    if (visibleSize == null ||
        !visibleSize.width.isFinite ||
        !visibleSize.height.isFinite ||
        visibleSize.width <= 0 ||
        visibleSize.height <= 0) {
      return const DesktopWindowConfiguration(
        size: fallbackSize,
        minimumSize: preferredMinimumSize,
      );
    }

    final minimumSize = Size(
      math.min(preferredMinimumSize.width, visibleSize.width),
      math.min(preferredMinimumSize.height, visibleSize.height),
    );
    return DesktopWindowConfiguration(
      size: Size(
        math.max(visibleSize.width * visibleScreenFraction, minimumSize.width),
        math.max(
          visibleSize.height * visibleScreenFraction,
          minimumSize.height,
        ),
      ),
      minimumSize: minimumSize,
    );
  }

  /// The fraction of the usable display used for a first launch.
  static const visibleScreenFraction = 0.75;

  /// A fallback used only when the platform cannot report display dimensions.
  static const fallbackSize = Size(1200, 800);

  /// The largest usable minimum that preserves a fully visible window.
  static const preferredMinimumSize = Size(800, 600);

  /// The initial window size in logical pixels.
  final Size size;

  /// The native minimum window size in logical pixels.
  final Size minimumSize;
}
