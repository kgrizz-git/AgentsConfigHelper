import 'dart:async';
import 'dart:ui';

import 'package:agents_config_helper/services/desktop_window_adapter.dart';
import 'package:agents_config_helper/services/desktop_window_startup.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_window_fakes.dart';

void main() {
  group('DesktopWindowBoundsListener', () {
    DesktopWindowBoundsListener listener(
      FakeDesktopWindow window,
      List<Rect> saves,
    ) {
      return DesktopWindowBoundsListener(
        window: window,
        saveBounds: (bounds) async => saves.add(bounds),
        settleDelay: Duration.zero,
      );
    }

    test('debounces moves and saves the latest bounds', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow(
          rect: const Rect.fromLTWH(10, 20, 300, 200),
        );
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..endStartup();

        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async.elapse(const Duration(milliseconds: 399));
        expect(saves, isEmpty);
        async
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('re-arms the debounce on rapid moves', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..endStartup();

        window.rect = const Rect.fromLTWH(1, 1, 100, 100);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async.elapse(const Duration(milliseconds: 200));
        window.rect = const Rect.fromLTWH(2, 2, 200, 200);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async.elapse(const Duration(milliseconds: 399));
        expect(saves, isEmpty);
        async
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('suppresses geometry during the post-show settle', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = DesktopWindowBoundsListener(
          window: window,
          saveBounds: (bounds) async => saves.add(bounds),
          settleDelay: const Duration(milliseconds: 50),
        )..endStartup();

        window.rect = const Rect.fromLTWH(1, 1, 100, 100);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(saves, isEmpty);

        window.rect = const Rect.fromLTWH(2, 2, 200, 200);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('repeated closes await the same drain', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final pending = <Completer<void>>[];
        final boundsListener = DesktopWindowBoundsListener(
          window: window,
          saveBounds: (_) {
            final completer = Completer<void>();
            pending.add(completer);
            return completer.future;
          },
          settleDelay: Duration.zero,
        )..endStartup();

        window.rect = const Rect.fromLTWH(1, 1, 100, 100);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(pending, hasLength(1));

        var firstClosed = false;
        var secondClosed = false;
        final first = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        final second = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(first.then((_) => firstClosed = true));
        unawaited(second.then((_) => secondClosed = true));
        async.flushMicrotasks();
        expect(firstClosed, isFalse);
        expect(secondClosed, isFalse);

        pending[0].complete();
        async.flushMicrotasks();
        expect(firstClosed, isFalse);
        expect(secondClosed, isFalse);
        expect(pending, hasLength(2));

        pending[1].complete();
        async.flushMicrotasks();
        expect(firstClosed, isTrue);
        expect(secondClosed, isTrue);
        boundsListener.dispose();
      });
    });

    test('a stalled save does not block close forever', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final stalled = Completer<void>();
        final boundsListener = DesktopWindowBoundsListener(
          window: window,
          saveBounds: (_) => stalled.future,
          settleDelay: Duration.zero,
          closeTimeout: const Duration(milliseconds: 10),
        )..endStartup();

        window.rect = const Rect.fromLTWH(1, 1, 100, 100);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        var closed = false;
        final close = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(close.then((_) => closed = true));
        async.elapse(const Duration(milliseconds: 9));
        expect(closed, isFalse);
        async
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
        expect(closed, isTrue);

        stalled.complete();
        async.flushMicrotasks();
        boundsListener.dispose();
      });
    });

    test('suppresses geometry until startup completes', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..beginStartup();

        window.rect = const Rect.fromLTWH(1, 2, 300, 200);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(saves, isEmpty);

        window.rect = const Rect.fromLTWH(5, 6, 500, 400);
        boundsListener.endStartup();
        unawaited(boundsListener.onEvent(const DesktopWindowResized()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('suppresses geometry in maximized, minimized, and full screen', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..endStartup();

        for (final setState in <void Function()>[
          () => window.maximized = true,
          () => window.minimized = true,
          () => window.fullScreen = true,
        ]) {
          setState();
          unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
          async
            ..elapse(const Duration(milliseconds: 400))
            ..flushMicrotasks();
          expect(saves, isEmpty);
          window
            ..maximized = false
            ..minimized = false
            ..fullScreen = false;
        }
        boundsListener.dispose();
      });
    });

    test('close cancels the debounce, saves final bounds, and latches', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..endStartup();

        window.rect = const Rect.fromLTWH(1, 2, 300, 200);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async.elapse(const Duration(milliseconds: 100));
        window.rect = const Rect.fromLTWH(3, 4, 500, 400);
        var closed = false;
        final close = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(close.then((_) => closed = true));
        async.flushMicrotasks();

        expect(closed, isTrue);
        expect(saves, [window.rect]);

        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 500))
          ..flushMicrotasks();
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('close drains in-flight and queued saves in order', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final pending = <Completer<void>>[];
        final boundsListener = DesktopWindowBoundsListener(
          window: window,
          saveBounds: (bounds) {
            saves.add(bounds);
            final completer = Completer<void>();
            pending.add(completer);
            return completer.future;
          },
          settleDelay: Duration.zero,
        )..endStartup();

        window.rect = const Rect.fromLTWH(1, 1, 100, 100);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(pending, hasLength(1));

        window.rect = const Rect.fromLTWH(2, 2, 200, 200);
        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(pending, hasLength(1));

        const finalBounds = Rect.fromLTWH(3, 3, 300, 300);
        window.rect = finalBounds;
        var closed = false;
        final close = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(close.then((_) => closed = true));
        async.flushMicrotasks();
        expect(pending, hasLength(1));

        pending[0].complete();
        async.flushMicrotasks();
        expect(closed, isFalse);
        expect(pending, hasLength(2));
        expect(saves, [
          const Rect.fromLTWH(1, 1, 100, 100),
          const Rect.fromLTWH(2, 2, 200, 200),
        ]);

        pending[1].complete();
        async.flushMicrotasks();
        expect(pending, hasLength(3));
        expect(saves, [
          const Rect.fromLTWH(1, 1, 100, 100),
          const Rect.fromLTWH(2, 2, 200, 200),
          finalBounds,
        ]);

        pending[2].complete();
        async.flushMicrotasks();
        expect(closed, isTrue);
        boundsListener.dispose();
      });
    });

    test('close before startup completes still saves final bounds', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow();
        final saves = <Rect>[];
        final boundsListener = listener(window, saves)..beginStartup();

        window.rect = const Rect.fromLTWH(7, 8, 600, 500);
        var closed = false;
        final close = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(close.then((_) => closed = true));
        async.flushMicrotasks();

        expect(closed, isTrue);
        expect(saves, [window.rect]);
        boundsListener.dispose();
      });
    });

    test('save failures do not prevent the close', () {
      fakeAsync((async) {
        final window = FakeDesktopWindow(
          rect: const Rect.fromLTWH(9, 10, 700, 600),
        );
        final boundsListener = DesktopWindowBoundsListener(
          window: window,
          saveBounds: (_) async => throw StateError('disk full'),
        )..endStartup();

        unawaited(boundsListener.onEvent(const DesktopWindowMoved()));
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();

        var closed = false;
        final close = boundsListener.onEvent(
          const DesktopWindowCloseRequested(),
        );
        unawaited(close.then((_) => closed = true));
        async.flushMicrotasks();

        expect(closed, isTrue);
        boundsListener.dispose();
      });
    });
  });
}
