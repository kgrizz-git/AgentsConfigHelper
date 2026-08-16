import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DiscoveredConfig', () {
    DiscoveredConfig buildConfig({String filePath = '/some/path/config.json'}) {
      return DiscoveredConfig(
        id: 'test-id',
        filePath: filePath,
        descriptor: null,
        scope: ConfigLocationScope.manual,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Unknown configuration',
      );
    }

    test('supports value comparisons', () {
      final config1 = buildConfig();
      final config2 = buildConfig();

      // Non-const instances so equality is exercised through props rather
      // than identical-instance shortcuts.
      expect(identical(config1, config2), isFalse);
      expect(config1, equals(config2));
    });

    test('inequality reflects a different file path', () {
      final config1 = buildConfig();
      final config3 = buildConfig(filePath: '/some/other/config.json');

      expect(config1, isNot(equals(config3)));
    });

    test('fromPath derives id and normalizes the file path', () {
      final config = DiscoveredConfig.fromPath(
        filePath: '/some/path/../config.json/',
        scope: ConfigLocationScope.project,
        kind: ConfigSourceKind.structuredConfig,
        format: ConfigFormat.json,
        sourceLabel: 'Claude Code',
      );

      final normalized = p.normalize('/some/path/../config.json/');
      expect(
        config.id,
        '${ConfigSourceKind.structuredConfig.name}:$normalized',
      );
      expect(config.filePath, normalized);
      expect(config.filePath, isNot(contains('..')));
      expect(config.scope, ConfigLocationScope.project);
    });
  });
}
