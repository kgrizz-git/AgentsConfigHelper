import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assessor = FidelityAssessor();

  group('assessPendingSave — saveConfig (structured save)', () {
    test('TOML saveConfig is warning / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.warning);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'TOML');
    });

    test('YAML saveConfig is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('JSON saveConfig is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('JSONC saveConfig is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.jsonc,
        filePath: '/x/config.jsonc',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('new file with no baseline: YAML structured save is caution', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/new.yaml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: false,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('new file with no baseline: JSON structured save is caution', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/new.json',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: false,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'JSON');
    });

    test('new file with no baseline: JSONC structured save is caution', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.jsonc,
        filePath: '/x/new.jsonc',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: false,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'JSONC');
    });

    test('new file with no baseline: TOML structured save is warning', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/new.toml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: false,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.warning);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'TOML');
    });

    test('JSONC fallback status selects JSONC copy for a .json save', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/settings.json',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
        parsedAsJsonc: true,
      );
      expect(result, isNotNull);
      expect(result!.formatLabel, 'JSONC');
      expect(
        result.saveRiskDescription,
        contains('comments or trailing commas'),
      );
    });

    test('unsupported structured save has no assessment', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.unknown,
        filePath: '/x/file.xyz',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNull);
    });
  });

  group('assessPendingSave — saveRawDirect', () {
    test('direct raw write returns no assessment even for TOML', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
        saveKind: SaveKind.saveRawDirect,
        hasUsableBaseline: true,
        structuredDiverged: false,
      );
      expect(result, isNull);
    });

    test('direct raw write returns no assessment for JSON', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
        saveKind: SaveKind.saveRawDirect,
        hasUsableBaseline: true,
        structuredDiverged: false,
      );
      expect(result, isNull);
    });

    test('direct raw write returns no assessment for markdown', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.markdown,
        filePath: '/x/AGENTS.md',
        rawOnly: false,
        saveKind: SaveKind.saveRawDirect,
        hasUsableBaseline: true,
        structuredDiverged: false,
      );
      expect(result, isNull);
    });
  });

  group('assessPendingSave — saveRawStructuredMerge', () {
    test('TOML merge is warning / parserSerialization, never directRaw', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.warning);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'TOML');
    });

    test('JSON merge is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('YAML merge is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: false,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test('JSONC merge is caution / parserSerialization', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.jsonc,
        filePath: '/x/config.jsonc',
        rawOnly: false,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
    });

    test(
      'merge without usable baseline falls back to direct (no assessment)',
      () {
        final result = assessor.assessPendingSave(
          format: ConfigFormat.toml,
          filePath: '/x/config.toml',
          rawOnly: false,
          saveKind: SaveKind.saveRawStructuredMerge,
          hasUsableBaseline: false,
          structuredDiverged: true,
        );
        expect(result, isNull);
      },
    );

    test('merge without structural divergence falls back to direct', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: false,
      );
      expect(result, isNull);
    });

    test('raw-only merge returns no assessment', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: true,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNull);
    });
  });

  group('assessPendingSave — raw-only overrides all save kinds', () {
    test('raw-only saveConfig returns no assessment', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/broken.json',
        rawOnly: true,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNull);
    });

    test('raw-only saveRawStructuredMerge returns no assessment', () {
      final result = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/broken.yaml',
        rawOnly: true,
        saveKind: SaveKind.saveRawStructuredMerge,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(result, isNull);
    });
  });

  group('consistency — opening vs pending-save severity', () {
    test('TOML opening severity matches structured-save severity', () {
      final opening = assessor.assessOpening(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
      );
      final pending = assessor.assessPendingSave(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(opening, isNotNull);
      expect(pending, isNotNull);
      expect(opening!.risk, pending!.risk);
      expect(opening.mechanism, pending.mechanism);
    });

    test('JSON opening severity matches structured-save severity', () {
      final opening = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
      );
      final pending = assessor.assessPendingSave(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(opening, isNotNull);
      expect(pending, isNotNull);
      expect(opening!.risk, pending!.risk);
      expect(opening.mechanism, pending.mechanism);
    });

    test('markdown opening null matches direct raw null', () {
      final opening = assessor.assessOpening(
        format: ConfigFormat.markdown,
        filePath: '/x/AGENTS.md',
        rawOnly: false,
      );
      final pending = assessor.assessPendingSave(
        format: ConfigFormat.markdown,
        filePath: '/x/AGENTS.md',
        rawOnly: false,
        saveKind: SaveKind.saveRawDirect,
        hasUsableBaseline: true,
        structuredDiverged: false,
      );
      expect(opening, isNull);
      expect(pending, isNull);
    });
  });

  group('no AST prediction', () {
    test(
      'opening assessment is caution for JSON with nested non-list permissions',
      () {
        // A file whose permissions field is a nested object (not a flat list)
        // still receives the same conservative opening assessment. The assessor
        // does not predict whether a particular in-place patch will succeed.
        final result = assessor.assessOpening(
          format: ConfigFormat.json,
          filePath: '/x/config.json',
          rawOnly: false,
        );
        expect(result, isNotNull);
        expect(result!.risk, FidelityRisk.caution);
      },
    );

    test(
      'opening assessment is caution for YAML with nested non-list permissions',
      () {
        final result = assessor.assessOpening(
          format: ConfigFormat.yaml,
          filePath: '/x/config.yaml',
          rawOnly: false,
        );
        expect(result, isNotNull);
        expect(result!.risk, FidelityRisk.caution);
      },
    );

    test(
      'pending-save assessment is caution for JSON merge with nested '
      'permissions plus flat-field rules edit',
      () {
        // Even when the user makes a simultaneous flat-field edit (rules)
        // alongside nested permissions, the assessor conservatively returns
        // caution. Do not infer pre-save certainty from a successful fixture.
        final result = assessor.assessPendingSave(
          format: ConfigFormat.json,
          filePath: '/x/config.json',
          rawOnly: false,
          saveKind: SaveKind.saveRawStructuredMerge,
          hasUsableBaseline: true,
          structuredDiverged: true,
        );
        expect(result, isNotNull);
        expect(result!.risk, FidelityRisk.caution);
        expect(result.mechanism, SaveMechanism.parserSerialization);
      },
    );

    test(
      'pending-save assessment is caution for YAML merge with nested '
      'permissions plus flat-field rules edit',
      () {
        final result = assessor.assessPendingSave(
          format: ConfigFormat.yaml,
          filePath: '/x/config.yaml',
          rawOnly: false,
          saveKind: SaveKind.saveRawStructuredMerge,
          hasUsableBaseline: true,
          structuredDiverged: true,
        );
        expect(result, isNotNull);
        expect(result!.risk, FidelityRisk.caution);
        expect(result.mechanism, SaveMechanism.parserSerialization);
      },
    );

    test('opening assessment ignores baseline/divergence inputs', () {
      // Opening is purely a format capability statement.
      final withBaseline = assessor.assessOpening(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: false,
      );
      expect(withBaseline, isNotNull);
      expect(withBaseline!.risk, FidelityRisk.caution);
      // No inputs exist to vary here; this documents the contract.
    });

    test('pending assessment does not distinguish in-place vs fallback', () {
      // Both a fresh file and one with a baseline are caution for YAML.
      final freshFile = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/new.yaml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: false,
        structuredDiverged: true,
      );
      final withBaseline = assessor.assessPendingSave(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: false,
        saveKind: SaveKind.saveConfig,
        hasUsableBaseline: true,
        structuredDiverged: true,
      );
      expect(freshFile, isNotNull);
      expect(withBaseline, isNotNull);
      expect(freshFile!.risk, withBaseline!.risk);
      expect(freshFile.mechanism, withBaseline.mechanism);
    });
  });
}
