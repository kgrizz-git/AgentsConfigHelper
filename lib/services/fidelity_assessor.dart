import 'package:agents_config_helper/models/tool_config.dart';

/// Display severity for a formatting-fidelity notice.
///
/// The widget layer maps this to icon/colour; the assessor owns the policy so
/// the widget never translates a large enum back into user-facing concepts.
enum FidelityRisk { none, caution, warning }

/// The save path a later write is expected to take.
///
/// [directRaw] means the validated raw text is written unchanged.
/// [parserSerialization] means the parser's `serialize` runs, which may
/// rebuild the document and discard comments/formatting.
enum SaveMechanism { directRaw, parserSerialization }

/// Which kind of save the editor intends to perform.
enum SaveKind {
  /// `saveConfig`: structured serialization through the parser.
  saveConfig,

  /// `saveRawConfig` with no independently dirty structured values.
  saveRawDirect,

  /// `saveRawConfig` with independently dirty structured values.
  saveRawStructuredMerge,
}

/// Immutable, pure-Dart description of opening and pending-save risk.
///
/// Produced by [FidelityAssessor]; the widget only renders its result.
class FidelityAssessment {
  const FidelityAssessment({
    required this.risk,
    required this.mechanism,
    required this.formatLabel,
  });

  /// Display severity. `none` means no notice should be shown.
  final FidelityRisk risk;

  /// The save mechanism this assessment describes.
  final SaveMechanism mechanism;

  /// Human-readable format name for the notice body (e.g. "TOML", "JSONC").
  final String formatLabel;

  /// Convenience: a notice is only rendered when risk is not none.
  bool get hasNotice => risk != FidelityRisk.none;

  /// Concise, user-facing title shared by the opening and review notices.
  String get title {
    if (risk == FidelityRisk.warning && formatLabel == 'TOML') {
      return 'Structured save will reconstruct this TOML file';
    }
    return 'Formatting may change on structured save';
  }

  /// The format-specific risk statement shared by the opening and review
  /// notices. It describes a potential serializer path, never a guarantee.
  String get saveRiskDescription {
    if (risk == FidelityRisk.warning && formatLabel == 'TOML') {
      return 'A structured save rebuilds this TOML file. Existing comments '
          'will be discarded; whitespace, ordering, and layout can change.';
    }
    if (formatLabel == 'JSONC') {
      return 'A structured save of this JSONC file can fall back to rebuilding '
          'the document, which can change formatting and discard comments or '
          'trailing commas.';
    }
    return 'A structured save of this $formatLabel file can fall back to '
        'rebuilding the document, which can change formatting.';
  }

  @override
  String toString() =>
      'FidelityAssessment(risk: $risk, mechanism: $mechanism, '
      'formatLabel: $formatLabel)';
}

/// Pure entry point for formatting-fidelity classification.
///
/// No I/O, no AST inspection, no prediction of in-place patch success. The
/// opening assessment is a conservative capability statement for the file's
/// format; the pending-save assessment distinguishes the three write paths.
class FidelityAssessor {
  const FidelityAssessor();

  /// Opening-assessment input: the discovered format plus whether the editor
  /// is raw-only (e.g. a corrupt-file recovery editor).
  ///
  /// [rawOnly] takes precedence: a recovery editor for corrupt TOML or JSON
  /// returns no assessment even though its discovered format is structured.
  FidelityAssessment? assessOpening({
    required ConfigFormat format,
    required String filePath,
    required bool rawOnly,
    bool parsedAsJsonc = false,
  }) {
    if (rawOnly) return null;

    return _openingForFormat(format, filePath, parsedAsJsonc);
  }

  /// Pending-save assessment.
  ///
  /// [rawOnly] again forces no assessment. [saveKind] selects the write path.
  /// [hasUsableBaseline] reports whether the parser has original source to
  /// attempt an in-place update; [structuredDiverged] reports whether the
  /// structured values (rules/permissions/rawSettings) differ from that
  /// baseline. When both are true on a raw save, the merge path runs the
  /// parser over the raw text — that is `parserSerialization`, never
  /// `directRaw`.
  FidelityAssessment? assessPendingSave({
    required ConfigFormat format,
    required String filePath,
    required bool rawOnly,
    required SaveKind saveKind,
    required bool hasUsableBaseline,
    required bool structuredDiverged,
    bool parsedAsJsonc = false,
  }) {
    if (rawOnly) return null;

    switch (saveKind) {
      case SaveKind.saveConfig:
        return _assessStructuredSave(format, filePath, parsedAsJsonc);
      case SaveKind.saveRawDirect:
        return null;
      case SaveKind.saveRawStructuredMerge:
        if (!hasUsableBaseline || !structuredDiverged) {
          // Not actually a merge; treat as a direct raw write.
          return null;
        }
        return _assessStructuredMerge(format, filePath, parsedAsJsonc);
    }
  }

  static FidelityAssessment? _openingForFormat(
    ConfigFormat format,
    String filePath,
    bool parsedAsJsonc,
  ) {
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
        return FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: _jsonLabel(filePath, format, parsedAsJsonc),
        );
      case ConfigFormat.yaml:
        return const FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'YAML',
        );
      case ConfigFormat.toml:
        return const FidelityAssessment(
          risk: FidelityRisk.warning,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'TOML',
        );
      case ConfigFormat.markdown:
      case ConfigFormat.text:
      case ConfigFormat.unknown:
        return null;
    }
  }

  static FidelityAssessment? _assessStructuredSave(
    ConfigFormat format,
    String filePath,
    bool parsedAsJsonc,
  ) {
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
        return FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: _jsonLabel(filePath, format, parsedAsJsonc),
        );
      case ConfigFormat.yaml:
        return const FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'YAML',
        );
      case ConfigFormat.toml:
        return const FidelityAssessment(
          risk: FidelityRisk.warning,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'TOML',
        );
      case ConfigFormat.markdown:
      case ConfigFormat.text:
      case ConfigFormat.unknown:
        // Defensive: structured save should never be offered for these.
        return null;
    }
  }

  static FidelityAssessment? _assessStructuredMerge(
    ConfigFormat format,
    String filePath,
    bool parsedAsJsonc,
  ) {
    // A raw-plus-structured merge runs the parser/serializer over the raw text.
    // TOML always rewrites; JSON/JSONC/YAML are conservatively caution.
    switch (format) {
      case ConfigFormat.json:
      case ConfigFormat.jsonc:
        return FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: _jsonLabel(filePath, format, parsedAsJsonc),
        );
      case ConfigFormat.yaml:
        return const FidelityAssessment(
          risk: FidelityRisk.caution,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'YAML',
        );
      case ConfigFormat.toml:
        return const FidelityAssessment(
          risk: FidelityRisk.warning,
          mechanism: SaveMechanism.parserSerialization,
          formatLabel: 'TOML',
        );
      case ConfigFormat.markdown:
      case ConfigFormat.text:
      case ConfigFormat.unknown:
        // Invalid combination; the service must reject before classifying.
        return null;
    }
  }

  /// JSON vs JSONC label: a `.json` file parsed via JSONC fallback still
  /// carries the comment/trailing-comma risk, so label it JSONC.
  static String _jsonLabel(
    String filePath,
    ConfigFormat format,
    bool parsedAsJsonc,
  ) {
    if (format == ConfigFormat.jsonc || parsedAsJsonc) return 'JSONC';
    if (filePath.toLowerCase().endsWith('.jsonc')) return 'JSONC';
    return 'JSON';
  }
}
