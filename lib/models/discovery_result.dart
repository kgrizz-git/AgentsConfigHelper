import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:equatable/equatable.dart';

class DiscoveryWarning extends Equatable {
  const DiscoveryWarning({
    required this.path,
    required this.message,
  });

  final String path;
  final String message;

  @override
  List<Object?> get props => [path, message];
}

class DiscoveryResult extends Equatable {
  const DiscoveryResult({
    required this.items,
    this.warnings = const [],
  });

  final List<DiscoveredConfig> items;
  final List<DiscoveryWarning> warnings;

  @override
  List<Object?> get props => [items, warnings];
}
