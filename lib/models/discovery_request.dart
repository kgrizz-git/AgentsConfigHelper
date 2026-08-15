/// The normalized inputs used to drive a single discovery scan.
class DiscoveryRequest {
  /// Creates a discovery request.
  const DiscoveryRequest({
    this.normalizedHomePath,
    this.normalizedProjectRoots = const [],
    this.manualPaths = const [],
  });

  /// The normalized absolute path to the user's home directory, or null if
  /// unavailable.
  final String? normalizedHomePath;

  /// Normalized absolute paths to project roots to scan.
  final List<String> normalizedProjectRoots;

  /// Normalized absolute paths to manually added configuration files.
  final List<String> manualPaths;
}
