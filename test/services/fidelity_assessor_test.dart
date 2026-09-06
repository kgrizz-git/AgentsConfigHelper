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
    test('raw-only corrupt TOML recovery editor returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.toml,
        filePath: '/x/broken.toml',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only corrupt JSON recovery editor returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.json,
        filePath: '/x/broken.json',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only corrupt YAML recovery editor returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.yaml,
        filePath: '/x/broken.yaml',
        rawOnly: true,
      );
      expect(result, isNull);
    });

    test('raw-only JSONC recovery editor returns no assessment', () {
      final result = assessor.assessOpening(
        format: ConfigFormat.jsonc,
        filePath: '/x/broken.jsonc',
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
}
