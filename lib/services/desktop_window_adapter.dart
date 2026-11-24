import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Geometry copied from the connected displays' usable work areas.
class DesktopDisplayWorkAreas {
  /// Creates work-area geometry with a primary display, when one exists.
  const new({
    required this.primary,
    required this.all,
  });

  /// The primary display's usable work area, or null when none was reported.
  final Rect? primary;

  /// Every connected display's usable work area.
  final List<Rect> all;
}

/// Reads display geometry without exposing native handles to callers.
abstract interface class DesktopDisplaySource {
  /// Copies the current work areas into plain Dart values.
  DesktopDisplayWorkAreas read();
}

/// Reads native display work areas and disposes their owned handles.
class NativeDesktopDisplaySource implements DesktopDisplaySource {
  /// Creates a source backed by nativeapi's display manager.
  const new();

  @override
  DesktopDisplayWorkAreas read() {
    Display? primary;
    List<Display> all;
    try {
      primary = DisplayManager.instance.getPrimary();
    } on Object {
      primary = null;
    }
    try {
      all = DisplayManager.instance.getAll();
    } on Object {
      all = const [];
    }
    try {
      final primaryArea = primary?.workArea.toRect();
      final areas = all
          .map((display) => display.workArea.toRect())
          .toList(growable: true);
      if (areas.isEmpty && primaryArea != null) areas.add(primaryArea);
      return DesktopDisplayWorkAreas(primary: primaryArea, all: areas);
    } finally {
      primary?.dispose();
      for (final display in all) {
        display.dispose();
      }
    }
  }
}

/// A window event the bounds coordinator needs to observe.
sealed class DesktopWindowEvent {
  const new();
}

/// The user moved the window.
final class DesktopWindowMoved extends DesktopWindowEvent {
  /// Creates a move event.
  const new();
}

/// The user resized the window.
final class DesktopWindowResized extends DesktopWindowEvent {
  /// Creates a resize event.
  const new();
}

/// The platform asked whether the window may close.
final class DesktopWindowCloseRequested extends DesktopWindowEvent {
  /// Creates a close-request event.
  const new();
}

/// The subset of native window operations used by startup and persistence.
abstract interface class DesktopWindow {
  /// Whether the window is maximized.
  bool get isMaximized;

  /// Whether the window is minimized.
  bool get isMinimized;

  /// Whether the window is full screen.
  bool get isFullScreen;

  /// Exits or enters full screen.
  set isFullScreen(bool value);

  /// The window's outer bounds in logical pixels.
  Rect get bounds;

  /// Moves and resizes the window in logical pixels.
  set bounds(Rect value);

  /// The platform minimum window size.
  Size get minimumSize;

  /// Sets the platform minimum window size.
  set minimumSize(Size value);

  /// Sets the window title.
  void setTitle(String value);

  /// Sets the window size without animation.
  void setSize(Size size);

  /// Centers the window on its current display.
  void center();

  /// Shows the window.
  void show();

  /// Gives the window focus.
  void focus();

  /// Leaves the maximized state.
  void unmaximize();

  /// Leaves the minimized state.
  void restore();

  /// Registers [listener] for window move, resize, and close-request events.
  void addListener(FutureOr<void> Function(DesktopWindowEvent) listener);
}

/// Adapts nativeapi's [Window] to the coordinator's narrow interface.
class NativeDesktopWindow implements DesktopWindow {
  /// Wraps [window], retaining its native handle for the app lifetime.
  new(this._window);

  final Window _window;

  @override
  bool get isMaximized => _window.isMaximized;

  @override
  bool get isMinimized => _window.isMinimized;

  @override
  bool get isFullScreen => _window.isFullScreen;

  @override
  set isFullScreen(bool value) => _window.isFullScreen = value;

  @override
  Rect get bounds => _window.bounds.toRect();

  @override
  set bounds(Rect value) => _window.bounds = value.toNative();

  @override
  Size get minimumSize => _window.minimumSize.toSize();

  @override
  set minimumSize(Size value) => _window.minimumSize = value.toNative();

  @override
  void setTitle(String value) => _window.title = value;

  @override
  void setSize(Size size) => _window.setSize(size.toNative(), false);

  @override
  void center() => _window.center();

  @override
  void show() => _window.show();

  @override
  void focus() => _window.focus();

  @override
  void unmaximize() => _window.unmaximize();

  @override
  void restore() => _window.restore();

  @override
  void addListener(FutureOr<void> Function(DesktopWindowEvent) listener) {
    _window.addListener((event) {
      switch (event) {
        case WindowMovedEvent():
          return listener(const DesktopWindowMoved());
        case WindowResizedEvent():
          return listener(const DesktopWindowResized());
        case WindowCloseRequestedEvent():
          return listener(const DesktopWindowCloseRequested());
        default:
          return null;
      }
    });
  }
}

/// Resolves the app's main window, including a hidden startup window.
abstract interface class DesktopWindowSource {
  /// Resolves the current window, or null when it cannot be found in time.
  Future<DesktopWindow?> resolve();
}

/// Resolves nativeapi's current window and waits briefly for creation.
class NativeDesktopWindowSource implements DesktopWindowSource {
  /// Creates a source backed by nativeapi's window manager.
  const new();

  /// The default bounded wait for a hidden startup window.
  static const defaultTimeout = Duration(seconds: 5);

  @override
  Future<DesktopWindow?> resolve() async {
    const timeout = defaultTimeout;
    final current = WindowManager.instance.getCurrent();
    if (current != null) return NativeDesktopWindow(current);

    final completer = Completer<DesktopWindow?>();
    final listener = WindowManager.instance.addListener((event) {
      if (event is WindowCreatedEvent && !completer.isCompleted) {
        final window = WindowManager.instance.get(event.windowId);
        if (window != null) completer.complete(NativeDesktopWindow(window));
      }
    });
    try {
      final afterRegistration = WindowManager.instance.getCurrent();
      if (afterRegistration != null && !completer.isCompleted) {
        completer.complete(NativeDesktopWindow(afterRegistration));
      }
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('Desktop window did not appear within $timeout.');
          return null;
        },
      );
    } finally {
      WindowManager.instance.removeListener(listener);
    }
  }
}
