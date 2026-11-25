import 'dart:async';
import 'dart:ui';

import 'package:agents_config_helper/services/desktop_window_adapter.dart';
import 'package:agents_config_helper/services/desktop_window_configuration.dart';
import 'package:agents_config_helper/services/desktop_window_startup.dart';
import 'package:flutter_test/flutter_test.dart';

import 'desktop_window_fakes.dart';

void main() {
  group('DesktopWindowStartup', () {
    DesktopWindowStartup startup({
      required FakeDesktopWindow window,
      required DesktopDisplayWorkAreas areas,
      Rect? savedBounds,
    }) {
      return DesktopWindowStartup(
        displays: FakeDisplaySource(areas),
        windows: FakeWindowSource(window),
        loadBounds: () async => savedBounds,
        saveBounds: (_) async {},
      );
    }

    test(
      'uses fallback geometry when the primary display is missing',
      () async {
        final window = FakeDesktopWindow();
        await startup(
          window: window,
          areas: const DesktopDisplayWorkAreas(primary: null, all: []),
        ).configure();

        expect(window.lastSize, DesktopWindowConfiguration.fallbackSize);
        expect(window.minimum, DesktopWindowConfiguration.preferredMinimumSize);
        expect(window.titleValue, 'Agents Config Helper');
        expect(
          window.calls,
          containsAllInOrder([
            'size',
            'minimum',
            'center',
            'title',
            'listener',
            'show',
            'focus',
          ]),
        );
      },
    );

    test('restores and clamps saved bounds without centering', () async {
      final window = FakeDesktopWindow();
      const workArea = Rect.fromLTWH(0, 0, 1000, 800);
      await startup(
        window: window,
        areas: const DesktopDisplayWorkAreas(
          primary: workArea,
          all: [workArea],
        ),
        savedBounds: const Rect.fromLTWH(900, 700, 400, 300),
      ).configure();

      expect(window.rect, const Rect.fromLTWH(600, 500, 400, 300));
      expect(window.calls, contains('bounds'));
      expect(window.calls, isNot(contains('center')));
    });

    test('resets full screen, maximized, and minimized state first', () async {
      final window = FakeDesktopWindow()
        ..fullScreen = true
        ..maximized = true
        ..minimized = true;
      const workArea = Rect.fromLTWH(0, 0, 1200, 900);
      await startup(
        window: window,
        areas: const DesktopDisplayWorkAreas(
          primary: workArea,
          all: [workArea],
        ),
      ).configure();

      expect(window.fullScreen, isFalse);
      expect(window.maximized, isFalse);
      expect(window.minimized, isFalse);
      expect(
        window.calls,
        containsAllInOrder([
          'fullscreen:false',
          'unmaximize',
          'restore',
          'size',
        ]),
      );
    });

    test('waits for a deferred window before applying geometry', () async {
      final window = FakeDesktopWindow();
      final completer = Completer<DesktopWindow?>();
      final coordinator = DesktopWindowStartup(
        displays: FakeDisplaySource(
          const DesktopDisplayWorkAreas(primary: null, all: []),
        ),
        windows: DeferredWindowSource(completer.future),
        loadBounds: () async => null,
        saveBounds: (_) async {},
      );

      final configured = coordinator.configure();
      await Future<void>.delayed(Duration.zero);
      expect(window.calls, isEmpty);

      completer.complete(window);
      await configured;
      expect(window.calls, contains('show'));
    });

    test('fits the minimum size to a smaller restored display', () async {
      final window = FakeDesktopWindow();
      const primary = Rect.fromLTWH(0, 0, 1000, 800);
      const secondary = Rect.fromLTWH(1000, 0, 640, 480);
      await startup(
        window: window,
        areas: const DesktopDisplayWorkAreas(
          primary: primary,
          all: [primary, secondary],
        ),
        savedBounds: const Rect.fromLTWH(1100, 100, 500, 400),
      ).configure();

      expect(window.rect, const Rect.fromLTWH(1100, 80, 500, 400));
      expect(window.minimum, const Size(500, 400));
    });

    test('still shows the window when geometry setup fails', () async {
      final window = FakeDesktopWindow()
        ..setSizeError = StateError('geometry failed');

      await startup(
        window: window,
        areas: const DesktopDisplayWorkAreas(primary: null, all: []),
      ).configure();

      expect(window.calls, contains('listener'));
      expect(window.calls, containsAllInOrder(['show', 'focus']));
    });

    test('does nothing when the window cannot be resolved', () async {
      final window = FakeDesktopWindow();
      final coordinator = DesktopWindowStartup(
        displays: FakeDisplaySource(
          const DesktopDisplayWorkAreas(primary: null, all: []),
        ),
        windows: FakeWindowSource(null),
        loadBounds: () async => null,
        saveBounds: (_) async {},
      );

      await coordinator.configure();

      expect(window.calls, isEmpty);
    });
  });
}
