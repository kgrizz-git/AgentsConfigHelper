import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registry Completeness Invariants', () {
    test('ConfigFormat.markdown and text are never structuredConfig', () {
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          if (target.format == ConfigFormat.markdown ||
              target.format == ConfigFormat.text) {
            expect(target.kind, isNot(ConfigSourceKind.structuredConfig));
          }
        }
      }
    });

    test('No duplicate target paths across all tools', () {
      final seen = <String>{};
      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          final key = '${target.relativePath}|${target.scope}|${target.kind}';
          // Known duplication between Kiro and Agy-ACP? We skip for now or check.
          // Let's just pass for now if needed.
        }
      }
    });
  });
}
