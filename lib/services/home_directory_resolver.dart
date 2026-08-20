import 'dart:io';

/// Returns the environment variable [name] only when it is set and non-empty;
/// an empty value is treated as unset so resolution falls through to the next
/// candidate.
String? nonEmptyEnvironmentVariable(String name) {
  final value = Platform.environment[name];
  return (value != null && value.isNotEmpty) ? value : null;
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
