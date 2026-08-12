import 'dart:io';
import 'package:path/path.dart' as p;

/// Service responsible for discovering AI agent configuration files
/// on the local filesystem.
class DiscoveryService {
  DiscoveryService({String? customHome})
    : homeDirectory = customHome ?? _resolveHomeDirectory();

  /// The user's home directory.
  final String homeDirectory;

  static String _resolveHomeDirectory() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw StateError(
        'Could not resolve home directory from environment variables.',
      );
    }
    return home;
  }

  /// The standard list of configuration paths to check on launch, relative
  /// to the user's home directory, ordered by detection priority.
  static const List<String> defaultRelativePaths = [
    '.claude/settings.json', // Claude Code
    '.codex/config.toml', // Codex
    '.config/opencode/opencode.json', // Opencode
    '.paseo/config.json', // Paseo
    '.cursor/permissions.json', // Cursor
    '.kiro/settings/permissions.yaml', // Kiro
    '.config/devin/config.json', // Devin
    '.gemini/antigravity-cli/settings.json', // Antigravity
    '.openab/agy-acp/sessions.json', // agy-acp
  ];

  /// Scans the file system for known configuration files.
  /// Returns a list of absolute paths that exist on disk.
  Future<List<String>> discoverConfigs() async {
    final discoveredPaths = <String>[];

    for (final relPath in defaultRelativePaths) {
      final absolutePath = p.join(homeDirectory, relPath);
      final file = File(absolutePath);

      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        discoveredPaths.add(absolutePath);
      }
    }

    return discoveredPaths;
  }
}
