/// The normalized inputs used to drive a single discovery scan.
class DiscoveryRequest {
  /// Creates a discovery request.
  const DiscoveryRequest({
    this.normalizedHomePath,
    this.normalizedProjectRoots = const [],
    this.manualPaths = const [],
    this.normalizedCopilotHomePath,
    this.enableClineRulesFallback,
  });

  /// The normalized absolute path to the user's home directory, or null if
  /// unavailable.
  final String? normalizedHomePath;

  /// Normalized absolute paths to project roots to scan.
  final List<String> normalizedProjectRoots;

  /// Normalized absolute paths to manually added configuration files.
  final List<String> manualPaths;

  /// Effective Copilot CLI config directory from `COPILOT_HOME`, when set.
  ///
  /// When null, Copilot CLI user targets resolve under `~/.copilot/`.
  final String? normalizedCopilotHomePath;

  /// Whether to discover the Linux/WSL `~/Cline/Rules` fallback.
  ///
  /// When null (default), discovery auto-detects by checking whether
  /// `~/Documents/Cline/Rules` exists. Tests may force `true`/`false`.
  final bool? enableClineRulesFallback;
}
