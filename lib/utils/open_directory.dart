import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens [directory] in the platform file manager.
///
/// Tries `url_launcher` first, then falls back to `open` (macOS),
/// `xdg-open` (Linux), or `explorer` (Windows). The directory is created if
/// it does not already exist. Returns `true` if a launcher reported success.
Future<bool> openDirectory(Directory directory) async {
  try {
    // The asynchronous check avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final uri = Uri.directory(directory.path);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (launched) return true;
  } on Object {
    // Fall through to the platform-specific launcher.
  }

  return _openWithPlatformLauncher(directory.path);
}

Future<bool> _openWithPlatformLauncher(String path) async {
  final (command, args) = switch (Platform.operatingSystem) {
    'macos' => ('open', <String>[path]),
    'linux' => ('xdg-open', <String>[path]),
    'windows' => ('explorer', <String>[path]),
    _ => (null, null),
  };

  if (command == null || args == null) return false;

  try {
    final result = await Process.run(command, args);
    return result.exitCode == 0;
  } on Object {
    return false;
  }
}
