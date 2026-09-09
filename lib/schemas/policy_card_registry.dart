import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';

/// Single pure-Dart selection point for policy-card adapters.
///
/// Holds the adapters in registration order. [select] returns the first
/// non-`notApplicable` selection (registration order wins), or a
/// `notApplicable` sentinel when no adapter matches.
class PolicyCardRegistry {
  /// Creates a registry over the given adapters in priority order.
  PolicyCardRegistry(List<PolicyCardAdapter> adapters)
    : _adapters = List.unmodifiable(adapters);

  final List<PolicyCardAdapter> _adapters;

  /// Sentinel adapter id for the "no adapter matched" selection.
  ///
  /// Callers and tests use this named constant instead of relying on an
  /// implicit default. No widget builder is registered for it, so
  /// `buildCard` returns `null` for the sentinel.
  static const noAdapterId = '';

  /// Default registry used by the app. Never mutated by tests; tests inject
  /// their own registry explicitly instead.
  static final PolicyCardRegistry shared = PolicyCardRegistry([
    ClaudeCodePermissionsAdapter(),
    CursorPermissionsAdapter(),
  ]);

  /// Returns the first non-`notApplicable` interpretation, else the sentinel.
  PolicyCardSelection select({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  }) {
    for (final adapter in _adapters) {
      final selection = adapter.interpret(
        config: config,
        discoveredConfig: discoveredConfig,
      );
      if (selection.status != PolicyCardStatus.notApplicable) {
        return selection;
      }
    }
    return const PolicyCardSelection(
      adapterId: noAdapterId,
      status: PolicyCardStatus.notApplicable,
    );
  }
}
