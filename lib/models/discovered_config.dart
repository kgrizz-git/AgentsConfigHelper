import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

/// A configuration source discovered by the app.
class DiscoveredConfig extends Equatable {
  const DiscoveredConfig({
    required this.id,
    required this.filePath,
    required this.descriptor,
    required this.scope,
    required this.kind,
    required this.format,
    required this.sourceLabel,
  });

  /// Factory that automatically derives the [id] from the normalized absolute path and source kind.
  factory DiscoveredConfig.fromPath({
    required String filePath,
    required ConfigLocationScope scope,
    required ConfigSourceKind kind,
    required ConfigFormat format,
    required String sourceLabel,
    ToolDescriptor? descriptor,
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
    );
  }

  /// A stable identifier derived from the normalized absolute path and source kind.
  /// Keeps duplicate configurations for one tool independently selectable.
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

  /// Returns a copy of this object with updated fields.
  DiscoveredConfig copyWith({
    String? id,
    String? filePath,
    ToolDescriptor? descriptor,
    ConfigLocationScope? scope,
    ConfigSourceKind? kind,
    ConfigFormat? format,
    String? sourceLabel,
  }) {
    return DiscoveredConfig(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      // If descriptor was explicitly passed as null, we can't easily distinguish it
      // with standard copyWith unless we use a wrapper, but for our usage this is fine.
      descriptor: descriptor ?? this.descriptor,
      scope: scope ?? this.scope,
      kind: kind ?? this.kind,
      format: format ?? this.format,
      sourceLabel: sourceLabel ?? this.sourceLabel,
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
  ];
}
