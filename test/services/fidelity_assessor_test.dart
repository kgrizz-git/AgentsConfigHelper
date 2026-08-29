import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/services/fidelity_assessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assessor = FidelityAssessor();

  group('FidelityRisk', () {
    test('enum order is none, caution, warning', () {
      expect(FidelityRisk.values, [
        FidelityRisk.none,
        FidelityRisk.caution,
        FidelityRisk.warning,
      ]);
    });
  });

  group('SaveMechanism', () {
    test('enum values are directRaw and parserSerialization', () {
      expect(SaveMechanism.values, [
        SaveMechanism.directRaw,
        SaveMechanism.parserSerialization,
      ]);
    });
  });

  group('SaveKind', () {
    test('enum values cover the three write paths', () {
      expect(SaveKind.values, [
        SaveKind.saveConfig,
        SaveKind.saveRawDirect,
        SaveKind.saveRawStructuredMerge,
      ]);
    });
  });

  group('FidelityAssessment', () {
    test('is immutable and exposes fields', () {
      const a = FidelityAssessment(
        risk: FidelityRisk.warning,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'TOML',
      );
      expect(a.risk, FidelityRisk.warning);
      expect(a.mechanism, SaveMechanism.parserSerialization);
      expect(a.formatLabel, 'TOML');
    });

    test('hasNotice is false only for none', () {
      const none = FidelityAssessment(
        risk: FidelityRisk.none,
        mechanism: SaveMechanism.directRaw,
        formatLabel: 'text',
      );
      const caution = FidelityAssessment(
        risk: FidelityRisk.caution,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'JSON',
      );
      const warning = FidelityAssessment(
        risk: FidelityRisk.warning,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'TOML',
      );
      expect(none.hasNotice, isFalse);
      expect(caution.hasNotice, isTrue);
      expect(warning.hasNotice, isTrue);
    });

    test('identical const instances are equal via const canonicalization', () {
      // Two const instances with identical fields are identical.
      const a = FidelityAssessment(
        risk: FidelityRisk.caution,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'YAML',
      );
      const b = FidelityAssessment(
        risk: FidelityRisk.caution,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'YAML',
      );
      // Const canonicalization: identical const objects are the same instance.
      expect(identical(a, b), isTrue);
    });

    test('different instances are not identical', () {
      const a = FidelityAssessment(
        risk: FidelityRisk.caution,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'YAML',
      );
      const c = FidelityAssessment(
        risk: FidelityRisk.warning,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'TOML',
      );
      expect(identical(a, c), isFalse);
    });

    test('toString is informative', () {
      const a = FidelityAssessment(
        risk: FidelityRisk.warning,
        mechanism: SaveMechanism.parserSerialization,
        formatLabel: 'TOML',
      );
      expect(a.toString(), contains('warning'));
      expect(a.toString(), contains('parserSerialization'));
      expect(a.toString(), contains('TOML'));
    });
  });

  group('assessOpening — raw-only precedence', () {
    test('raw-only TOML returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only JSON returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only YAML returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only markdown returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.markdown,
        filePath: '/x/AGENTS.md',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only unknown returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.unknown,
        filePath: '/x/file.xyz',
        rawOnly: true,
      );
      expect(result, isNull);
    });
  });

  group('assessOpening — format capability mapping', () {
    test('TOML is warning / parserSerialization', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.toml,
        filePath: '/x/config.toml',
        rawOnly: false,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.warning);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'TOML');
    });

    test('YAML is caution / parserSerialization', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.yaml,
        filePath: '/x/config.yaml',
        rawOnly: false,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'YAML');
    });

    test('JSON is caution / parserSerialization', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/config.json',
        rawOnly: false,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'JSON');
    });

    test('JSONC is caution / parserSerialization', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.jsonc,
        filePath: '/x/config.jsonc',
        rawOnly: false,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.mechanism, SaveMechanism.parserSerialization);
      expect(result.formatLabel, 'JSONC');
    });

    test('.json file parsed as JSONC is labelled JSONC', () {
      // The parse result, not the filename, supplies JSONC syntax status.
      final result = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/settings.json',
        rawOnly: false,
        parsedAsJsonc: true,
      );
      expect(result, isNotNull);
      expect(result!.risk, FidelityRisk.caution);
      expect(result.formatLabel, 'JSONC');
    });

    test('strict .json remains labelled JSON', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/settings.json',
        rawOnly: false,
      );
      expect(result, isNotNull);
      expect(result!.formatLabel, 'JSON');
    });

    test('markdown returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.markdown,
        filePath: '/x/AGENTS.md',
        rawOnly: false,
      );
      expect(result, isNull);
    });

    test('text returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.text,
        filePath: '/x/notes.txt',
        rawOnly: false,
      );
      expect(result, isNull);
    });

    test('unknown returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.unknown,
        filePath: '/x/file.xyz',
        rawOnly: false,
      );
      expect(result, isNull);
    });
  });

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

    test('new file with no baseline: structured save still caution', () {
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
