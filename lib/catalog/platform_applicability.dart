import 'dart:io';

import 'package:agents_config_helper/models/tool_descriptor.dart';

/// Whether a catalog target declared for [target] applies on the [host]
/// platform.
///
/// [ConfigPlatform.any] applies everywhere; [ConfigPlatform.posix] expands to
/// macOS and Linux. The [host] is always a concrete platform (or
/// [ConfigPlatform.any] when the host is unknown), never
/// [ConfigPlatform.posix].
bool targetAppliesToPlatform(ConfigPlatform target, ConfigPlatform host) {
  if (target == ConfigPlatform.any || target == host) return true;
  if (target == ConfigPlatform.posix) {
    return host == ConfigPlatform.macOS || host == ConfigPlatform.linux;
  }
  return false;
}

/// Resolves the current host platform for UI composition.
///
/// Returns [ConfigPlatform.any] for unrecognized hosts so catalog targets
/// default to visible rather than silently hidden.
ConfigPlatform resolveHostConfigPlatform() {
  if (Platform.isMacOS) return ConfigPlatform.macOS;
  if (Platform.isLinux) return ConfigPlatform.linux;
  if (Platform.isWindows) return ConfigPlatform.windows;
  return ConfigPlatform.any;
}

/// A short human-readable label for a [ConfigPlatform], for audit views and
/// reports.
String platformLabel(ConfigPlatform platform) {
  switch (platform) {
    case ConfigPlatform.any:
      return 'any OS';
    case ConfigPlatform.macOS:
      return 'macOS';
    case ConfigPlatform.linux:
      return 'Linux';
    case ConfigPlatform.windows:
      return 'Windows';
    case ConfigPlatform.posix:
      return 'macOS/Linux';
  }
}
