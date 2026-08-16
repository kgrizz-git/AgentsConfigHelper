import 'dart:convert';
import 'dart:io';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists and retrieves user-configured discovery preferences (manual
/// file paths and project roots).
abstract class IDiscoveryPreferencesStore {
  /// Loads the current preferences, applying normalization and validation
  /// and collecting any issues encountered as warnings rather than errors.
  Future<DiscoveryPreferencesResult> load();

  /// Adds [path] to the manual file paths list.
  Future<void> addManualPath(String path);

  /// Removes [path] from the manual file paths list, if present.
  Future<void> removeManualPath(String path);

  /// Adds [path] to the project roots list.
  Future<void> addProjectRoot(String path);

  /// Removes [path] from the project roots list, if present.
  Future<void> removeProjectRoot(String path);
}

/// Thrown when a path passed to the preferences store is not usable
/// (empty or not absolute).
class InvalidPathException implements Exception {
  const InvalidPathException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Default, file-backed implementation of [IDiscoveryPreferencesStore].
///
/// Preferences are persisted as JSON in the application support directory
/// and written atomically (temp file + rename) so an interrupted write
/// can't corrupt the file. Mutating operations (add/remove) are chained
/// through [_serialize] so concurrent load-modify-save sequences don't
/// race and silently drop each other's changes.
class DiscoveryPreferencesStore implements IDiscoveryPreferencesStore {
  /// Creates a store backed by [fileName] inside the directory returned by
  /// [getDirectory] (defaults to the application support directory).
  DiscoveryPreferencesStore({
    Future<Directory> Function()? getDirectory,
    this.fileName = 'discovery_preferences.json',
  }) : getDirectory = getDirectory ?? getApplicationSupportDirectory;

  /// Resolves the directory that houses the preferences file.
  final Future<Directory> Function() getDirectory;

  /// Name of the preferences file within [getDirectory].
  final String fileName;

  // Chains mutations so concurrent load-modify-save sequences don't
  // race each other (lost updates / temp file collisions).
  Future<void> _pending = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<File> _getFile() async {
    final directory = await getDirectory();
    return File(p.join(directory.path, fileName));
  }

  /// Loads preferences from disk, tolerating a missing or corrupt file.
  ///
  /// Malformed JSON, unexpected types, non-absolute paths, and duplicate
  /// or empty entries are reported as warnings rather than thrown; the
  /// returned preferences are always usable, falling back to empty lists
  /// when validation fails.
  @override
  Future<DiscoveryPreferencesResult> load() async {
    final file = await _getFile();
    if (!file.existsSync()) {
      return const DiscoveryPreferencesResult(
        preferences: DiscoveryPreferences(),
      );
    }

    final warnings = <String>[];
    String content;
    try {
      content = await file.readAsString();
    } on Object catch (e) {
      warnings.add('Failed to read preferences file: $e');
      return DiscoveryPreferencesResult(
        preferences: const DiscoveryPreferences(),
        warnings: warnings,
      );
    }

    dynamic json;
    try {
      json = jsonDecode(content);
    } on Object catch (e) {
      warnings.add('Preferences file contains invalid JSON: $e');
      return DiscoveryPreferencesResult(
        preferences: const DiscoveryPreferences(),
        warnings: warnings,
      );
    }

    if (json is! Map<String, dynamic>) {
      warnings.add('Preferences file must contain a JSON object at the root.');
      return DiscoveryPreferencesResult(
        preferences: const DiscoveryPreferences(),
        warnings: warnings,
      );
    }

    // Check types
    if (json.containsKey('version') && json['version'] is! int) {
      warnings.add("'version' is not an integer.");
    }

    final manualPathsRaw = json['manualFilePaths'];
    if (manualPathsRaw != null && manualPathsRaw is! List) {
      warnings.add("'manualFilePaths' is not a list.");
    } else if (manualPathsRaw is List) {
      final invalidPaths = manualPathsRaw.where((e) => e is! String).toList();
      if (invalidPaths.isNotEmpty) {
        warnings.add("'manualFilePaths' contains non-string elements.");
      }
    }

    final projectRootsRaw = json['projectRoots'];
    if (projectRootsRaw != null && projectRootsRaw is! List) {
      warnings.add("'projectRoots' is not a list.");
    } else if (projectRootsRaw is List) {
      final invalidRoots = projectRootsRaw.where((e) => e is! String).toList();
      if (invalidRoots.isNotEmpty) {
        warnings.add("'projectRoots' contains non-string elements.");
      }
    }

    // Parse it
    var prefs = DiscoveryPreferences.fromJson(json);

    // Normalize and deduplicate
    final dedupedManualPaths = _normalizeAndFilterPaths(
      prefs.manualFilePaths,
      'manualFilePaths',
      collectWarnings: true,
      warnings: warnings,
    );
    final dedupedProjectRoots = _normalizeAndFilterPaths(
      prefs.projectRoots,
      'projectRoots',
      collectWarnings: true,
      warnings: warnings,
    );

    prefs = prefs.copyWith(
      manualFilePaths: dedupedManualPaths,
      projectRoots: dedupedProjectRoots,
    );

    return DiscoveryPreferencesResult(
      preferences: prefs,
      warnings: warnings,
    );
  }

  Future<void> _save(DiscoveryPreferences preferences) async {
    final file = await _getFile();
    final parent = file.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }

    // Normalize and deduplicate before saving
    final dedupedManualPaths = _normalizeAndFilterPaths(
      preferences.manualFilePaths,
      'manualFilePaths',
      collectWarnings: false,
    );
    final dedupedProjectRoots = _normalizeAndFilterPaths(
      preferences.projectRoots,
      'projectRoots',
      collectWarnings: false,
    );

    final prefsToSave = preferences.copyWith(
      manualFilePaths: dedupedManualPaths,
      projectRoots: dedupedProjectRoots,
    );

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(prefsToSave.toJson());

    // Write atomic. Suffix the temp file with the process id and a
    // microsecond timestamp so concurrent saves don't collide.
    final tempFile = File(
      '${file.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await tempFile.writeAsString(jsonString, flush: true);
    await tempFile.rename(file.path);
  }

  /// Trims, drops empties, normalizes, deduplicates, and filters to absolute
  /// paths. When [collectWarnings] is true, writes the distinct dedup and
  /// non-absolute warnings (formatted with [fieldName]) into [warnings].
  List<String> _normalizeAndFilterPaths(
    List<String> input,
    String fieldName, {
    required bool collectWarnings,
    List<String>? warnings,
  }) {
    final deduped = input
        .map((fp) => fp.trim())
        .where((fp) => fp.isNotEmpty)
        .map(p.normalize)
        .toSet()
        .toList();
    if (collectWarnings) {
      if (deduped.length != input.length) {
        warnings!.add("Removed duplicate or empty paths from '$fieldName'.");
      }
      for (final bad in deduped.where((fp) => !p.isAbsolute(fp))) {
        warnings!.add("Ignored non-absolute path: '$bad'");
      }
    }
    return deduped.where(p.isAbsolute).toList();
  }

  /// Validates that [path] is non-empty (after trimming) and absolute.
  /// Throws [InvalidPathException] otherwise.
  String _validatePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw const InvalidPathException('Path must not be empty.');
    }
    if (!p.isAbsolute(trimmed)) {
      throw InvalidPathException("Path must be absolute: '$trimmed'");
    }
    return trimmed;
  }

  /// Validates [path] and appends it to the manual file paths list.
  ///
  /// Throws [InvalidPathException] if [path] is empty or not absolute.
  @override
  Future<void> addManualPath(String path) {
    final validated = _validatePath(path);
    return _serialize(() async {
      final result = await load();
      var prefs = result.preferences;
      prefs = prefs.copyWith(
        manualFilePaths: [...prefs.manualFilePaths, validated],
      );
      await _save(prefs);
    });
  }

  /// Removes [path] from the manual file paths list, comparing normalized
  /// forms so equivalent paths (e.g. differing only in trailing
  /// separators) still match.
  @override
  Future<void> removeManualPath(String path) {
    return _serialize(() async {
      final result = await load();
      final prefs = result.preferences;
      final normalizedToRemove = p.normalize(path.trim());
      final updatedPaths = prefs.manualFilePaths
          .where((fp) => p.normalize(fp.trim()) != normalizedToRemove)
          .toList();
      await _save(prefs.copyWith(manualFilePaths: updatedPaths));
    });
  }

  /// Validates [path] and appends it to the project roots list.
  ///
  /// Throws [InvalidPathException] if [path] is empty or not absolute.
  @override
  Future<void> addProjectRoot(String path) {
    final validated = _validatePath(path);
    return _serialize(() async {
      final result = await load();
      var prefs = result.preferences;
      prefs = prefs.copyWith(
        projectRoots: [...prefs.projectRoots, validated],
      );
      await _save(prefs);
    });
  }

  /// Removes [path] from the project roots list, comparing normalized
  /// forms so equivalent paths still match.
  @override
  Future<void> removeProjectRoot(String path) {
    return _serialize(() async {
      final result = await load();
      final prefs = result.preferences;
      final normalizedToRemove = p.normalize(path.trim());
      final updatedRoots = prefs.projectRoots
          .where((fp) => p.normalize(fp.trim()) != normalizedToRemove)
          .toList();
      await _save(prefs.copyWith(projectRoots: updatedRoots));
    });
  }
}
