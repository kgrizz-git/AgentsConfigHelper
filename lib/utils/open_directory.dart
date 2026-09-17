import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Runs a platform file-manager command.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

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

  return await _openWithPlatformLauncher(directory.path);
}

/// Reveals an existing [file] in the platform file manager.
///
/// On macOS and Windows the file is selected in Finder or Explorer. Linux
/// file managers have no portable select-file command, so this opens the
/// file's parent directory instead. This helper never creates files or
/// directories.
Future<bool> revealFile(
  File file, {
  String? operatingSystem,
  ProcessRunner? runProcess,
}) async {
  try {
    // The asynchronous check avoids blocking the UI thread.
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return false;

    final path = file.path;
    final (command, args) = switch (operatingSystem ??
        Platform.operatingSystem) {
      'macos' => ('open', <String>['-R', path]),
      'windows' => ('explorer', <String>['/select,', path]),
      'linux' => ('xdg-open', <String>[file.parent.path]),
      _ => (null, null),
    };

    if (command == null || args == null) return false;
    final result = await (runProcess ?? Process.run)(command, args);
    return result.exitCode == 0;
  } on Object {
    return false;
  }
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
