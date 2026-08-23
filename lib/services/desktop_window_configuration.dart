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

  /// Returns saved [bounds] clamped to a currently usable display, or null
  /// when no connected display can show it.
  static Rect? restoredBounds(
    Rect? bounds,
    Iterable<Rect> visibleDisplays,
  ) {
    if (bounds == null ||
        !bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.width.isFinite ||
        !bounds.height.isFinite ||
        bounds.width <= 0 ||
        bounds.height <= 0) {
      return null;
    }

    for (final display in visibleDisplays) {
      if (!display.width.isFinite ||
          !display.height.isFinite ||
          display.width <= 0 ||
          display.height <= 0 ||
          !bounds.overlaps(display)) {
        continue;
      }
      final width = math.min(bounds.width, display.width);
      final height = math.min(bounds.height, display.height);
      final left = bounds.left.clamp(display.left, display.right - width);
      final top = bounds.top.clamp(display.top, display.bottom - height);
      return Rect.fromLTWH(left, top, width, height);
    }
    return null;
  }
}
