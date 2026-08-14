class DiscoveryRequest {
  const DiscoveryRequest({
    this.normalizedHomePath,
    this.normalizedProjectRoots = const [],
    this.manualPaths = const [],
  });

  final String? normalizedHomePath;
  final List<String> normalizedProjectRoots;
  final List<String> manualPaths;
}
