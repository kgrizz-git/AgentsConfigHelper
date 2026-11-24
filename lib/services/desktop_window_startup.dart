import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:agents_config_helper/services/desktop_window_adapter.dart';
import 'package:agents_config_helper/services/desktop_window_bounds_store.dart';
import 'package:agents_config_helper/services/desktop_window_configuration.dart';
import 'package:flutter/foundation.dart';

/// Applies the native window's startup geometry and persists usable bounds.
class DesktopWindowStartup {
  /// Creates a startup coordinator with injectable native adapters.
  const new({
    required this.displays,
    required this.windows,
    required this.loadBounds,
    required this.saveBounds,
    this.startupGrace = const Duration(seconds: 3),
    this.saveDelay = const Duration(milliseconds: 400),
  });

  /// Reads the connected displays' usable work areas.
  final DesktopDisplaySource displays;

  /// Resolves the app's main window, including a hidden startup window.
  final DesktopWindowSource windows;

  /// Loads the last persisted window bounds.
  final Future<Rect?> Function() loadBounds;

  /// Persists a bounds snapshot.
  final Future<void> Function(Rect bounds) saveBounds;

  /// How long a hidden startup may suppress geometry persistence.
  final Duration startupGrace;

  /// How long move or resize activity is debounced before saving.
  final Duration saveDelay;

  /// Resolves the window, applies startup geometry, and registers persistence.
  ///
  /// The window stays hidden until the final geometry and listener are in
  /// place. An unresolved window is logged loudly; the caller must not treat
  /// that as a configured window.
  Future<void> configure() async {
    final workAreas = displays.read();
    final configuration = DesktopWindowConfiguration.forVisibleSize(
      workAreas.primary?.size,
    );
    final restored = DesktopWindowConfiguration.restoredBounds(
      await loadBounds(),
      workAreas.all,
    );
    final window = await windows.resolve();
    if (window == null) {
      debugPrint(
        'Desktop window unavailable after startup retry; geometry and bounds '
        'persistence were not applied.',
      );
      return;
    }

    final listener = DesktopWindowBoundsListener(
      window: window,
      saveBounds: saveBounds,
      saveDelay: saveDelay,
      startupGrace: startupGrace,
    );

    final minimum = restored == null
        ? configuration.minimumSize
        : Size(
            math.min(configuration.minimumSize.width, restored.width),
            math.min(configuration.minimumSize.height, restored.height),
          );
    try {
      if (window.isFullScreen) window.isFullScreen = false;
      if (window.isMaximized) window.unmaximize();
      if (window.isMinimized) window.restore();
      window
        ..setSize(configuration.size)
        ..minimumSize = minimum;
      if (restored != null) {
        window.bounds = restored;
      } else {
        window.center();
      }
      window.setTitle('Agents Config Helper');
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Desktop window geometry setup failed; showing default geometry: '
        '$error\n$stackTrace',
      );
    }
    try {
      window.addListener(listener.onEvent);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Desktop window listener registration failed: $error\n$stackTrace',
      );
    }
    listener.beginStartup();
    try {
      window
        ..show()
        ..focus();
    } on Object catch (error, stackTrace) {
      debugPrint('Desktop window show failed: $error\n$stackTrace');
    } finally {
      listener.endStartup();
    }
  }
}

/// Serializes bounds writes and drains the queue before a window closes.
class DesktopWindowBoundsListener {
  /// Creates a listener for [window] backed by [saveBounds].
  new({
    required this.window,
    required this.saveBounds,
    this.saveDelay = const Duration(milliseconds: 400),
    this.startupGrace = const Duration(seconds: 3),
    this.settleDelay = const Duration(milliseconds: 250),
    this.closeTimeout = const Duration(seconds: 5),
  });

  /// The window whose move, resize, and close events are observed.
  final DesktopWindow window;

  /// Receives debounced and final bounds writes.
  final Future<void> Function(Rect bounds) saveBounds;

  /// How long move or resize activity is debounced before saving.
  final Duration saveDelay;

  /// How long a hidden startup may suppress geometry persistence.
  final Duration startupGrace;

  /// How long geometry stays suppressed after `show()` so late startup events
  /// cannot overwrite restored placement.
  final Duration settleDelay;

  /// The maximum time a close waits for the bounds chain before proceeding.
  final Duration closeTimeout;

  Timer? _saveTimer;
  Timer? _startupTimer;
  Timer? _settleTimer;
  Future<void> _chain = Future<void>.value();
  Future<void>? _closeDrain;
  bool _startupComplete = false;
  bool _closing = false;
  bool _disposed = false;

  /// Starts the bounded grace period for geometry events during startup.
  void beginStartup() {
    _startupComplete = false;
    _startupTimer?.cancel();
    _startupTimer = Timer(startupGrace, () {
      _startupTimer = null;
      _startupComplete = true;
    });
  }

  /// Starts the post-show settle period or enables geometry immediately.
  void endStartup() {
    _startupTimer?.cancel();
    _startupTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    if (settleDelay <= Duration.zero) {
      _startupComplete = true;
      return;
    }
    _settleTimer = Timer(settleDelay, () {
      _settleTimer = null;
      _startupComplete = true;
    });
  }

  /// Handles a window event. Close requests wait for the write chain to drain.
  Future<void> onEvent(DesktopWindowEvent event) async {
    if (_disposed) return;
    switch (event) {
      case DesktopWindowMoved():
      case DesktopWindowResized():
        if (!_startupComplete || _closing) return;
        _scheduleSave();
      case DesktopWindowCloseRequested():
        await _handleClose();
    }
  }

  /// Stops timers. Persisted bytes are unaffected.
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    _startupTimer?.cancel();
    _startupTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () {
      _saveTimer = null;
      _enqueueSnapshot();
    });
  }

  void _enqueueSnapshot() {
    if (_closing) return;
    final bounds = _snapshot();
    if (bounds != null) _enqueue(bounds);
  }

  Rect? _snapshot() {
    try {
      if (window.isMaximized || window.isMinimized || window.isFullScreen) {
        return null;
      }
      final bounds = window.bounds;
      return DesktopWindowBoundsStore.isValid(bounds) ? bounds : null;
    } on Object {
      return null;
    }
  }

  void _enqueue(Rect bounds) {
    _chain = _chain.then((_) => saveBounds(bounds)).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Desktop window bounds save failed: $error\n$stackTrace');
    });
  }

  Future<void> _handleClose() {
    final pending = _closeDrain;
    if (pending != null) return pending;
    final drain = _beginClose();
    _closeDrain = drain;
    return drain;
  }

  Future<void> _beginClose() async {
    _closing = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    _startupTimer?.cancel();
    _startupTimer = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    final bounds = _snapshot();
    if (bounds != null) _enqueue(bounds);
    try {
      await _chain.timeout(
        closeTimeout,
        onTimeout: () {
          debugPrint(
            'Desktop window close save exceeded $closeTimeout; '
            'continuing close.',
          );
        },
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Desktop window close save failed: $error\n$stackTrace');
    }
  }
}
