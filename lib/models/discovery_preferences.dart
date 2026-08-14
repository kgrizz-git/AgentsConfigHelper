import 'package:equatable/equatable.dart';

class DiscoveryPreferences extends Equatable {
  const DiscoveryPreferences({
    this.version = 1,
    this.manualFilePaths = const [],
    this.projectRoots = const [],
  });

  factory DiscoveryPreferences.fromJson(Map<String, dynamic> json) {
    return DiscoveryPreferences(
      version: json['version'] is int ? json['version'] as int : 1,
      manualFilePaths: _parseStringList(json['manualFilePaths']),
      projectRoots: _parseStringList(json['projectRoots']),
    );
  }

  final int version;
  final List<String> manualFilePaths;
  final List<String> projectRoots;

  DiscoveryPreferences copyWith({
    int? version,
    List<String>? manualFilePaths,
    List<String>? projectRoots,
  }) {
    return DiscoveryPreferences(
      version: version ?? this.version,
      manualFilePaths: manualFilePaths ?? this.manualFilePaths,
      projectRoots: projectRoots ?? this.projectRoots,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'manualFilePaths': manualFilePaths,
      'projectRoots': projectRoots,
    };
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  @override
  List<Object?> get props => [version, manualFilePaths, projectRoots];
}

class DiscoveryPreferencesResult extends Equatable {
  const DiscoveryPreferencesResult({
    required this.preferences,
    this.warnings = const [],
  });

  final DiscoveryPreferences preferences;
  final List<String> warnings;

  @override
  List<Object?> get props => [preferences, warnings];
}
