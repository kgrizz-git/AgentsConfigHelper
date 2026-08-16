import 'dart:io';

/// Resolves the current user's home directory from the environment.
///
/// Checks `HOME`/`USERPROFILE` first, then falls back to Windows'
/// `HOMEDRIVE`+`HOMEPATH` pair. Returns null if none are set.
String? resolveHomeDirectory() {
  final home = _nonEmptyEnv('HOME') ?? _nonEmptyEnv('USERPROFILE');
  if (home != null) {
    return home;
  }
  if (Platform.isWindows) {
    final drive = _nonEmptyEnv('HOMEDRIVE');
    final path = _nonEmptyEnv('HOMEPATH');
    if (drive != null && path != null) {
      return '$drive$path';
    }
  }
  return null;
}

/// Returns the environment variable [name] only when it is set and non-empty;
/// an empty value is treated as unset so resolution falls through to the next
/// candidate.
String? _nonEmptyEnv(String name) {
  final value = Platform.environment[name];
  return (value != null && value.isNotEmpty) ? value : null;
}
