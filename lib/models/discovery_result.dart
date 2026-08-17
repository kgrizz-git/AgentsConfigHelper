import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:equatable/equatable.dart';

/// A non-fatal issue encountered while scanning a specific path during
/// discovery.
class DiscoveryWarning extends Equatable {
  /// Creates a discovery warning.
  const DiscoveryWarning({
    required this.path,
    required this.message,
  });

  /// The path that produced the warning.
  final String path;

  /// A human-readable description of the issue.
  final String message;

  @override
  List<Object?> get props => [path, message];
}

/// The outcome of scanning for tool configurations, including any
/// discovered items and warnings.
class DiscoveryResult extends Equatable {
  /// Creates a discovery result.
  const DiscoveryResult({
    required this.items,
    this.warnings = const [],
    this.projectRoots = const [],
  });

  /// The configurations found during the scan.
  final List<DiscoveredConfig> items;

  /// Non-fatal issues encountered while scanning.
  final List<DiscoveryWarning> warnings;

  /// The project root directories that were scanned.
  final List<String> projectRoots;

  @override
  List<Object?> get props => [items, warnings, projectRoots];
}
