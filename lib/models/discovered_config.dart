import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// A configuration source discovered by the app.
class DiscoveredConfig extends Equatable {
  /// Creates a discovered configuration with an explicit [id].
  const DiscoveredConfig({
    required this.id,
    required this.filePath,
    required this.descriptor,
    required this.scope,
    required this.kind,
    required this.format,
    required this.sourceLabel,
    this.fromCatalog = false,
    this.fromManual = false,
  });

  /// Factory that automatically derives the [id] from the normalized
  /// absolute path and source kind.
  factory DiscoveredConfig.fromPath({
    required String filePath,
    required ConfigLocationScope scope,
    required ConfigSourceKind kind,
    required ConfigFormat format,
    required String sourceLabel,
    ToolDescriptor? descriptor,
    bool fromCatalog = false,
    bool fromManual = false,
  }) {
    final normalizedPath = p.normalize(filePath);
    return DiscoveredConfig(
      id: '${kind.name}:$normalizedPath',
      filePath: normalizedPath,
      descriptor: descriptor,
      scope: scope,
      kind: kind,
      format: format,
      sourceLabel: sourceLabel,
      fromCatalog: fromCatalog,
      fromManual: fromManual,
    );
  }

  /// A stable identifier derived from the normalized absolute path and
  /// source kind. Keeps duplicate configurations for one tool independently
  /// selectable.
  final String id;

  /// The normalized absolute path to the configuration file.
  final String filePath;

  /// The tool descriptor associated with this config, if known.
  final ToolDescriptor? descriptor;

  /// The scope of this configuration (user, project, manual).
  final ConfigLocationScope scope;

  /// The kind of configuration source.
  final ConfigSourceKind kind;

  /// The serialization format for this configuration.
  final ConfigFormat format;

  /// A display name for the source. If the file is unknown, this is typically
  /// "Unknown configuration".
  final String sourceLabel;

  /// True if this source was discovered via a catalog target (user or project).
  final bool fromCatalog;

  /// True if this source was explicitly added manually by the user.
  final bool fromManual;

  /// True if this source was explicitly added manually by the user.
  /// Derived from [fromManual] for backward compatibility.
  bool get isManual => fromManual;

  /// Returns a copy of this object with updated fields.
  DiscoveredConfig copyWith({
    String? id,
    String? filePath,
    ToolDescriptor? descriptor,
    ConfigLocationScope? scope,
    ConfigSourceKind? kind,
    ConfigFormat? format,
    String? sourceLabel,
    bool? fromCatalog,
    bool? fromManual,
  }) {
    final nextKind = kind ?? this.kind;
    final nextFilePath = filePath != null
        ? p.normalize(filePath)
        : this.filePath;
    // Keep id synchronized with kind + filePath (as the factory derives it)
    // whenever either changes, unless an explicit id is supplied.
    final nextId =
        id ??
        (filePath != null || kind != null
            ? '${nextKind.name}:$nextFilePath'
            : this.id);
    return DiscoveredConfig(
      id: nextId,
      filePath: nextFilePath,
      descriptor: descriptor ?? this.descriptor,
      scope: scope ?? this.scope,
      kind: nextKind,
      format: format ?? this.format,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      fromCatalog: fromCatalog ?? this.fromCatalog,
      fromManual: fromManual ?? this.fromManual,
    );
  }

  @override
  List<Object?> get props => [
    id,
    filePath,
    descriptor,
    scope,
    kind,
    format,
    sourceLabel,
    fromCatalog,
    fromManual,
  ];
}
