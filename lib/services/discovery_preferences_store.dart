import 'dart:convert';
import 'dart:io';

import 'package:agents_config_helper/models/discovery_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class IDiscoveryPreferencesStore {
  Future<DiscoveryPreferencesResult> load();
  Future<void> addManualPath(String path);
  Future<void> removeManualPath(String path);
  Future<void> addProjectRoot(String path);
  Future<void> removeProjectRoot(String path);
}

class DiscoveryPreferencesStore implements IDiscoveryPreferencesStore {
  DiscoveryPreferencesStore({
    Future<Directory> Function()? getDirectory,
    this.fileName = 'discovery_preferences.json',
  }) : getDirectory = getDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() getDirectory;
  final String fileName;

  Future<File> _getFile() async {
    final directory = await getDirectory();
    return File(p.join(directory.path, fileName));
  }

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
    } catch (e) {
      warnings.add('Failed to read preferences file: $e');
      return DiscoveryPreferencesResult(
        preferences: const DiscoveryPreferences(),
        warnings: warnings,
      );
    }

    dynamic json;
    try {
      json = jsonDecode(content);
    } catch (e) {
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
    final dedupedManualPathsRaw = prefs.manualFilePaths
        .map((fp) => fp.trim())
        .where((fp) => fp.isNotEmpty)
        .map(p.normalize)
        .toSet()
        .toList();
    if (dedupedManualPathsRaw.length != prefs.manualFilePaths.length) {
      warnings.add("Removed duplicate or empty paths from 'manualFilePaths'.");
    }

    final dedupedManualPaths = dedupedManualPathsRaw
        .where(p.isAbsolute)
        .toList();
    for (final bad in dedupedManualPathsRaw.where((fp) => !p.isAbsolute(fp))) {
      warnings.add("Ignored non-absolute path: '$bad'");
    }

    final dedupedProjectRootsRaw = prefs.projectRoots
        .map((fp) => fp.trim())
        .where((fp) => fp.isNotEmpty)
        .map(p.normalize)
        .toSet()
        .toList();
    if (dedupedProjectRootsRaw.length != prefs.projectRoots.length) {
      warnings.add("Removed duplicate or empty paths from 'projectRoots'.");
    }

    final dedupedProjectRoots = dedupedProjectRootsRaw
        .where(p.isAbsolute)
        .toList();
    for (final bad in dedupedProjectRootsRaw.where((fp) => !p.isAbsolute(fp))) {
      warnings.add("Ignored non-absolute path: '$bad'");
    }

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
    final dedupedManualPaths = preferences.manualFilePaths
        .map((fp) => fp.trim())
        .where((fp) => fp.isNotEmpty)
        .map(p.normalize)
        .where(p.isAbsolute)
        .toSet()
        .toList();
    final dedupedProjectRoots = preferences.projectRoots
        .map((fp) => fp.trim())
        .where((fp) => fp.isNotEmpty)
        .map(p.normalize)
        .where(p.isAbsolute)
        .toSet()
        .toList();

    final prefsToSave = preferences.copyWith(
      manualFilePaths: dedupedManualPaths,
      projectRoots: dedupedProjectRoots,
    );

    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(prefsToSave.toJson());

    // Write atomic
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(jsonString, flush: true);
    await tempFile.rename(file.path);
  }

  @override
  Future<void> addManualPath(String path) async {
    final result = await load();
    var prefs = result.preferences;
    prefs = prefs.copyWith(
      manualFilePaths: [...prefs.manualFilePaths, path],
    );
    await _save(prefs);
  }

  @override
  Future<void> removeManualPath(String path) async {
    final result = await load();
    final prefs = result.preferences;
    final normalizedToRemove = p.normalize(path.trim());
    final updatedPaths = prefs.manualFilePaths
        .where((fp) => p.normalize(fp.trim()) != normalizedToRemove)
        .toList();
    await _save(prefs.copyWith(manualFilePaths: updatedPaths));
  }

  @override
  Future<void> addProjectRoot(String path) async {
    final result = await load();
    var prefs = result.preferences;
    prefs = prefs.copyWith(
      projectRoots: [...prefs.projectRoots, path],
    );
    await _save(prefs);
  }

  @override
  Future<void> removeProjectRoot(String path) async {
    final result = await load();
    final prefs = result.preferences;
    final normalizedToRemove = p.normalize(path.trim());
    final updatedRoots = prefs.projectRoots
        .where((fp) => p.normalize(fp.trim()) != normalizedToRemove)
        .toList();
    await _save(prefs.copyWith(projectRoots: updatedRoots));
  }
}
