import 'package:equatable/equatable.dart';

/// Persisted user preferences that influence discovery, such as manually
/// added files and project roots.
class DiscoveryPreferences extends Equatable {
  /// Creates discovery preferences.
  const DiscoveryPreferences({
    this.version = 1,
    this.manualFilePaths = const [],
    this.projectRoots = const [],
    this.extraFields = const {},
  });

  /// Parses preferences from a decoded JSON map, tolerating missing or
  /// malformed fields by falling back to defaults. Unknown keys are kept in
  /// [extraFields] so they survive a save/rewrite cycle.
  factory DiscoveryPreferences.fromJson(Map<String, dynamic> json) {
    const knownKeys = {'version', 'manualFilePaths', 'projectRoots'};
    final extraFields = <String, dynamic>{
      for (final entry in json.entries)
        if (!knownKeys.contains(entry.key)) entry.key: entry.value,
    };
    return DiscoveryPreferences(
      version: json['version'] is int ? json['version'] as int : 1,
      manualFilePaths: _parseStringList(json['manualFilePaths']),
      projectRoots: _parseStringList(json['projectRoots']),
      extraFields: Map.unmodifiable(extraFields),
    );
  }

  /// The schema version of these persisted preferences.
  final int version;

  /// Paths to configuration files the user manually added.
  final List<String> manualFilePaths;

  /// Additional project root directories the user registered for discovery.
  final List<String> projectRoots;

  /// Unknown JSON keys found at load time, preserved unmodified so nothing
  /// written by a newer app version is silently dropped.
  final Map<String, dynamic> extraFields;

  /// Returns a copy of this object with updated fields.
  DiscoveryPreferences copyWith({
    int? version,
    List<String>? manualFilePaths,
    List<String>? projectRoots,
    Map<String, dynamic>? extraFields,
  }) {
    return DiscoveryPreferences(
      version: version ?? this.version,
      manualFilePaths: manualFilePaths ?? this.manualFilePaths,
      projectRoots: projectRoots ?? this.projectRoots,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  /// Serializes these preferences to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'manualFilePaths': manualFilePaths,
      'projectRoots': projectRoots,
      ...extraFields,
    };
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  @override
  List<Object?> get props => [
    version,
    manualFilePaths,
    projectRoots,
    extraFields,
  ];
}

/// The outcome of loading [DiscoveryPreferences], including any warnings
/// produced while parsing.
class DiscoveryPreferencesResult extends Equatable {
  /// Creates a discovery preferences load result.
  const DiscoveryPreferencesResult({
    required this.preferences,
    this.warnings = const [],
  });

  /// The loaded (or defaulted) preferences.
  final DiscoveryPreferences preferences;

  /// Human-readable warnings encountered while loading preferences.
  final List<String> warnings;

  @override
  List<Object?> get props => [preferences, warnings];
}
