import 'dart:io';

import 'package:agents_config_helper/catalog/tool_descriptor_registry.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ToolDescriptorRegistry', () {
    test('contains exactly 12 user descriptors in order', () {
      expect(ToolDescriptorRegistry.catalog.length, 12);
      expect(ToolDescriptorRegistry.catalog[0].id, ToolId.claudeCode);
      expect(ToolDescriptorRegistry.catalog[1].id, ToolId.codex);
      expect(ToolDescriptorRegistry.catalog[2].id, ToolId.opencode);
      expect(ToolDescriptorRegistry.catalog[3].id, ToolId.paseo);
      expect(ToolDescriptorRegistry.catalog[4].id, ToolId.cursorIde);
      expect(ToolDescriptorRegistry.catalog[5].id, ToolId.cursor);
      expect(ToolDescriptorRegistry.catalog[6].id, ToolId.kiro);
      expect(ToolDescriptorRegistry.catalog[7].id, ToolId.devin);
      expect(ToolDescriptorRegistry.catalog[8].id, ToolId.antigravityIde);
      expect(ToolDescriptorRegistry.catalog[9].id, ToolId.antigravityApp);
      expect(ToolDescriptorRegistry.catalog[10].id, ToolId.antigravity);
      expect(ToolDescriptorRegistry.catalog[11].id, ToolId.agyAcp);
    });

    test('matches user target successfully', () {
      const homePath = 'home_test';
      final path = p.normalize(p.join(homePath, '.claude/settings.json'));

      final match = ToolDescriptorRegistry.matchPath(
        path,
        normalizedHomePath: homePath,
      );

      expect(match.descriptor?.id, ToolId.claudeCode);
      expect(match.scope, ConfigLocationScope.user);
      expect(match.format, ConfigFormat.json);
    });

    test('matches project target successfully', () {
      const projectRoot = 'home_test/project';
      final path = p.normalize(p.join(projectRoot, '.codex/config.toml'));

      final match = ToolDescriptorRegistry.matchPath(
        path,
        normalizedProjectRoots: [projectRoot],
      );

      expect(match.descriptor?.id, ToolId.codex);
      expect(match.scope, ConfigLocationScope.project);
      expect(match.format, ConfigFormat.toml);
    });

    test('falls back to manual unknown for unsupported JSON path', () {
      const path = 'home_test/some_manual_path.json';

      final match = ToolDescriptorRegistry.matchPath(path);

      expect(match.descriptor, isNull);
      expect(match.scope, ConfigLocationScope.manual);
      expect(match.format, ConfigFormat.json);
      expect(match.kind, ConfigSourceKind.structuredConfig);
      expect(match.sourceLabel, 'Unknown configuration');
    });

    test('manual .rules fallback is an instructionDocument', () {
      const path = '/root/.codex/rules/foo.rules';

      // No project roots provided, so it falls back to manual
      final match = ToolDescriptorRegistry.matchPath(path);

      expect(match.descriptor, isNull);
      expect(match.scope, ConfigLocationScope.manual);
      expect(match.format, ConfigFormat.text);
      expect(match.kind, ConfigSourceKind.instructionDocument);
      expect(match.sourceLabel, 'Unknown configuration');
    });

    test('manual .md fallback is an instructionDocument', () {
      const path = '/root/some/docs.md';

      final match = ToolDescriptorRegistry.matchPath(path);

      expect(match.descriptor, isNull);
      expect(match.scope, ConfigLocationScope.manual);
      expect(match.format, ConfigFormat.markdown);
      expect(match.kind, ConfigSourceKind.instructionDocument);
      expect(match.sourceLabel, 'Unknown configuration');
    });

    test('matches glob target successfully', () {
      const projectRoot = '/root';
      final path = p.normalize(p.join(projectRoot, '.cursor/rules/foo.mdc'));

      final match = ToolDescriptorRegistry.matchPath(
        path,
        normalizedProjectRoots: [projectRoot],
      );

      expect(match.descriptor?.id, ToolId.cursor);
      expect(match.scope, ConfigLocationScope.project);
      expect(match.format, ConfigFormat.text);
      expect(
        match.descriptor?.targets
            .firstWhere((t) => t.relativePath == '.cursor/rules/*.mdc')
            .kind,
        ConfigSourceKind.instructionDocument,
      );
    });

    test('does not match glob across path segment boundaries', () {
      const projectRoot = '/root';
      final pattern = p.normalize(p.join(projectRoot, '.cursor/rules/*.mdc'));

      expect(
        ToolDescriptorRegistry.isMatch(
          pattern,
          p.normalize(p.join(projectRoot, '.cursor/rules/archive/notes.mdc')),
        ),
        isFalse,
      );
    });

    test('matches glob within a single path segment', () {
      const projectRoot = '/root';
      final pattern = p.normalize(p.join(projectRoot, '.cursor/rules/*.mdc'));

      expect(
        ToolDescriptorRegistry.isMatch(
          pattern,
          p.normalize(p.join(projectRoot, '.cursor/rules/foo.mdc')),
        ),
        isTrue,
      );
    });

    test('matches Devin glob within a single path segment', () {
      const projectRoot = '/root';
      final pattern = p.normalize(p.join(projectRoot, '.devin/rules/*.md'));

      expect(
        ToolDescriptorRegistry.isMatch(
          pattern,
          p.normalize(p.join(projectRoot, '.devin/rules/feature.md')),
        ),
        isTrue,
      );
    });

    test('matches Codex glob within a single path segment', () {
      const projectRoot = '/root';
      final pattern = p.normalize(p.join(projectRoot, '.codex/rules/*.rules'));

      expect(
        ToolDescriptorRegistry.isMatch(
          pattern,
          p.normalize(p.join(projectRoot, '.codex/rules/linter.rules')),
        ),
        isTrue,
      );
    });

    test('nested glob path falls back to manual unknown', () {
      const projectRoot = '/root';
      final path = p.normalize(
        p.join(projectRoot, '.cursor/rules/archive/notes.mdc'),
      );

      final match = ToolDescriptorRegistry.matchPath(
        path,
        normalizedProjectRoots: [projectRoot],
      );

      expect(match.descriptor, isNull);
      expect(match.scope, ConfigLocationScope.manual);
      expect(match.format, ConfigFormat.text);
      expect(match.kind, ConfigSourceKind.instructionDocument);
      expect(match.sourceLabel, 'Unknown configuration');
    });

    test('throws ValidationException for unsupported extensions', () {
      const path = 'home_test/some_manual_path.bin';

      expect(
        () => ToolDescriptorRegistry.matchPath(path),
        throwsA(isA<ValidationException>()),
      );
    });

    test('display names are documented in supported-tools.md', () {
      final doc = File('docs/supported-tools.md').readAsStringSync();

      for (final descriptor in ToolDescriptorRegistry.catalog) {
        expect(
          doc.contains(descriptor.displayName),
          isTrue,
          reason:
              '${descriptor.displayName} is missing from '
              'docs/supported-tools.md',
        );
      }
    });
  });
}
