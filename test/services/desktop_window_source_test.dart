import 'dart:async';

import 'package:agents_config_helper/services/desktop_window_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

class _FakeWindowManager implements NativeWindowManager {
  Window? current;
  Window? resolved;
  FutureOr<void> Function(WindowEvent)? listener;
  bool removed = false;
  int addCalls = 0;

  @override
  Window? getCurrent() => current;

  @override
  Window? get(WindowId id) => resolved;

  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) {
    listener = callback;
    addCalls++;
    return 1;
  }

  @override
  bool removeListener(ListenerId listenerId) {
    removed = true;
    return true;
  }
}

void main() {
  group('NativeDesktopWindowSource', () {
    test('returns the current window without adding a listener', () async {
      final manager = _FakeWindowManager()..current = Window.borrowed(1);
      final source = NativeDesktopWindowSource(manager: manager);

      final window = await source.resolve();

      expect(window, isA<NativeDesktopWindow>());
      expect(manager.addCalls, isZero);
      expect(manager.removed, isFalse);
    });

    test('resolves a window created after registration and removes the '
        'listener', () async {
      final manager = _FakeWindowManager()..resolved = Window.borrowed(2);
      final source = NativeDesktopWindowSource(manager: manager);

      final pending = source.resolve();
      await Future<void>.delayed(Duration.zero);
      expect(manager.addCalls, 1);

      await Future.sync(
        () => manager.listener!(
          const WindowCreatedEvent(windowId: 7),
        ),
      );
      final window = await pending;

      expect(window, isA<NativeDesktopWindow>());
      expect(manager.removed, isTrue);
    });

    test('rechecks the current window after registration', () async {
      final manager = _LateWindowManager();
      final source = NativeDesktopWindowSource(manager: manager);

      final window = await source.resolve();

      expect(window, isA<NativeDesktopWindow>());
      expect(manager.addCalls, 1);
      expect(manager.removed, isTrue);
    });

    test('times out and removes the listener when no window appears', () async {
      final manager = _FakeWindowManager();
      final source = NativeDesktopWindowSource(
        manager: manager,
        timeout: const Duration(milliseconds: 5),
      );

      final window = await source.resolve();

      expect(window, isNull);
      expect(manager.removed, isTrue);
    });
  });
}

class _LateWindowManager extends _FakeWindowManager {
  @override
  ListenerId addListener(FutureOr<void> Function(WindowEvent) callback) {
    current = Window.borrowed(3);
    return super.addListener(callback);
  }
}
