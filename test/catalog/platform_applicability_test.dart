import 'package:agents_config_helper/catalog/platform_applicability.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('targetAppliesToPlatform', () {
    test('any applies on every host', () {
      for (final host in ConfigPlatform.values) {
        expect(
          targetAppliesToPlatform(ConfigPlatform.any, host),
          isTrue,
          reason: 'any should apply on ${host.name}',
        );
      }
    });

    test('posix applies to macOS and Linux only', () {
      expect(
        targetAppliesToPlatform(ConfigPlatform.posix, ConfigPlatform.macOS),
        isTrue,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.posix, ConfigPlatform.linux),
        isTrue,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.posix, ConfigPlatform.windows),
        isFalse,
      );
    });

    test('specific platforms match only their host', () {
      expect(
        targetAppliesToPlatform(ConfigPlatform.macOS, ConfigPlatform.macOS),
        isTrue,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.macOS, ConfigPlatform.linux),
        isFalse,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.linux, ConfigPlatform.linux),
        isTrue,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.windows, ConfigPlatform.windows),
        isTrue,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.windows, ConfigPlatform.macOS),
        isFalse,
      );
    });

    test('unknown host keeps platform-specific targets hidden', () {
      expect(
        targetAppliesToPlatform(ConfigPlatform.macOS, ConfigPlatform.any),
        isFalse,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.windows, ConfigPlatform.any),
        isFalse,
      );
      expect(
        targetAppliesToPlatform(ConfigPlatform.posix, ConfigPlatform.any),
        isFalse,
      );
    });
  });

  group('platformLabel', () {
    test('labels every platform', () {
      expect(platformLabel(ConfigPlatform.any), 'any OS');
      expect(platformLabel(ConfigPlatform.macOS), 'macOS');
      expect(platformLabel(ConfigPlatform.linux), 'Linux');
      expect(platformLabel(ConfigPlatform.windows), 'Windows');
      expect(platformLabel(ConfigPlatform.posix), 'macOS/Linux');
    });
  });
}
