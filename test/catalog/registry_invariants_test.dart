// Test cases use long strings that should not be split.
// ignore_for_file: lines_longer_than_80_chars
import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registry Completeness Invariants', () {
    test('every ToolId is represented in the catalog', () {
      final catalogToolIds = ToolDescriptorRegistry.catalog
          .map((d) => d.id)
          .toSet();
      for (final id in ToolId.values) {
        expect(
          catalogToolIds.contains(id),
          isTrue,
          reason:
              'ToolId.${id.name} is missing from ToolDescriptorRegistry.catalog',
        );
      }
    });

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

    test('no duplicate (relativePath, scope, kind) targets', () {
      final seen = <String, ToolId>{};
      final allowedDuplicates = {
        'CLAUDE.md|ConfigLocationScope.project|ConfigSourceKind.instructionDocument',
        'GEMINI.md|ConfigLocationScope.project|ConfigSourceKind.instructionDocument',
      };

      for (final descriptor in ToolDescriptorRegistry.catalog) {
        for (final target in descriptor.targets) {
          final key = '${target.relativePath}|${target.scope}|${target.kind}';
          if (allowedDuplicates.contains(key)) continue;

          if (seen.containsKey(key)) {
            fail(
              'Duplicate target found: $key claimed '
              'by both ${seen[key]} and ${descriptor.id}',
            );
          }
          seen[key] = descriptor.id;
        }
      }
    });
  });
}
