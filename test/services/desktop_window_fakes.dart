import 'dart:async';
import 'dart:ui';

import 'package:agents_config_helper/services/desktop_window_adapter.dart';

/// A mutable in-memory window for startup and persistence tests.
class FakeDesktopWindow implements DesktopWindow {
  new({
    this.rect = const Rect.fromLTWH(0, 0, 800, 600),
  });

  Rect rect;
  Size minimum = Size.zero;
  Size? lastSize;
  bool maximized = false;
  bool minimized = false;
  bool fullScreen = false;
  String? titleValue;
  final calls = <String>[];
  FutureOr<void> Function(DesktopWindowEvent)? listener;

  @override
  bool get isMaximized => maximized;

  @override
  bool get isMinimized => minimized;

  @override
  bool get isFullScreen => fullScreen;

  @override
  set isFullScreen(bool value) {
    fullScreen = value;
    calls.add('fullscreen:$value');
  }

  @override
  Rect get bounds => rect;

  @override
  set bounds(Rect value) {
    rect = value;
    calls.add('bounds');
  }

  @override
  Size get minimumSize => minimum;

  @override
  set minimumSize(Size value) {
    minimum = value;
    calls.add('minimum');
  }

  @override
  void setTitle(String value) {
    titleValue = value;
    calls.add('title');
  }

  @override
  void setSize(Size size) {
    lastSize = size;
    calls.add('size');
  }

  @override
  void center() => calls.add('center');

  @override
  void show() => calls.add('show');

  @override
  void focus() => calls.add('focus');

  @override
  void unmaximize() {
    maximized = false;
    calls.add('unmaximize');
  }

  @override
  void restore() {
    minimized = false;
    calls.add('restore');
  }

  @override
  void addListener(FutureOr<void> Function(DesktopWindowEvent) listener) {
    this.listener = listener;
    calls.add('listener');
  }
}

/// Returns fixed display geometry.
class FakeDisplaySource implements DesktopDisplaySource {
  new(this.areas);

  final DesktopDisplayWorkAreas areas;

  @override
  DesktopDisplayWorkAreas read() => areas;
}

/// Returns a fixed window, or null when resolution should fail.
class FakeWindowSource implements DesktopWindowSource {
  new(this.window);

  final DesktopWindow? window;

  @override
  Future<DesktopWindow?> resolve() async => window;
}

/// Defers window resolution until its future completes.
class DeferredWindowSource implements DesktopWindowSource {
  new(this.future);

  final Future<DesktopWindow?> future;

  @override
  Future<DesktopWindow?> resolve() => future;
}
