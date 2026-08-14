import 'dart:io';

/// Resolves the current user's home directory from the environment.
///
/// Checks `HOME`/`USERPROFILE` first, then falls back to Windows'
/// `HOMEDRIVE`+`HOMEPATH` pair. Returns null if none are set.
String? resolveHomeDirectory() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) {
    return home;
  }
  if (Platform.isWindows) {
    final drive = Platform.environment['HOMEDRIVE'];
    final path = Platform.environment['HOMEPATH'];
    if (drive != null && path != null) {
      return '$drive$path';
    }
  }
  return null;
}
