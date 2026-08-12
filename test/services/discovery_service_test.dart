import 'dart:io';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DiscoveryService', () {
    late Directory mockHome;
    late DiscoveryService discoveryService;

    setUp(() async {
      mockHome = await Directory.systemTemp.createTemp('discovery_test_');
      discoveryService = DiscoveryService(customHome: mockHome.path);
    });

    tearDown(() async {
      if (mockHome.existsSync()) {
        await mockHome.delete(recursive: true);
      }
    });

    test('discoverConfigs returns only files that exist', () async {
      // Create some mock config files in the temp home
      final claudeFile = File(
        p.join(mockHome.path, '.claude', 'settings.json'),
      );
      await claudeFile.create(recursive: true);

      final paseoFile = File(p.join(mockHome.path, '.paseo', 'config.json'));
      await paseoFile.create(recursive: true);

      final discovered = await discoveryService.discoverConfigs();

      expect(discovered.length, equals(2));
      expect(discovered, contains(claudeFile.path));
      expect(discovered, contains(paseoFile.path));
    });

    test('discoverConfigs returns empty list if no configs exist', () async {
      final discovered = await discoveryService.discoverConfigs();
      expect(discovered, isEmpty);
    });
  });
}
