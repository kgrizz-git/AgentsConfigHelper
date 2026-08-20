import 'dart:io';

import 'package:path/path.dart' as p;

/// Returns the environment variable [name] only when it is set and non-empty;
/// an empty value is treated as unset so resolution falls through to the next
/// candidate.
String? nonEmptyEnvironmentVariable(String name) {
  final value = Platform.environment[name];
  return (value != null && value.isNotEmpty) ? value : null;
}

/// Returns [raw] normalized when it is an absolute directory/file path.
///
/// Relative paths and `~`-prefixed values are rejected (return null) so callers
/// do not accidentally resolve against the process working directory.
String? absoluteNormalizedPath(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final normalized = p.normalize(raw);
  if (!p.isAbsolute(normalized)) return null;
  return normalized;
}

/// Resolves the current user's home directory from the environment.
///
/// Checks `HOME`/`USERPROFILE` first, then falls back to Windows'
/// `HOMEDRIVE`+`HOMEPATH` pair. Returns null if none are set.
String? resolveHomeDirectory() {
  final home =
      nonEmptyEnvironmentVariable('HOME') ??
      nonEmptyEnvironmentVariable('USERPROFILE');
  if (home != null) {
    return home;
  }
  if (Platform.isWindows) {
    final drive = nonEmptyEnvironmentVariable('HOMEDRIVE');
    final path = nonEmptyEnvironmentVariable('HOMEPATH');
    if (drive != null && path != null) {
      return '$drive$path';
    }
  }
  return null;
}
