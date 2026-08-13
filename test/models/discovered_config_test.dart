import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveredConfig', () {
    test('supports value comparisons', () {
      const config1 = DiscoveredConfig(
        id: 'test-id',
        filePath: '/some/path/config.json',
        descriptor: null,
        scope: ConfigLocationScope.manual,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Unknown configuration',
      );

      const config2 = DiscoveredConfig(
        id: 'test-id',
        filePath: '/some/path/config.json',
        descriptor: null,
        scope: ConfigLocationScope.manual,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Unknown configuration',
      );

      expect(config1, equals(config2));
    });
  });
}
