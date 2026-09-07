import 'package:agents_config_helper/models/discovered_config.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:equatable/equatable.dart';

/// The outcome of asking a schema adapter whether it can display a config.
enum PolicyCardStatus {
  /// The adapter does not apply to the current configuration.
  notApplicable,

  /// The adapter can display the current configuration.
  available,

  /// The adapter applies but cannot display the current shape.
  unsupported,
}

/// No Flutter dependencies. Base class for a schema's display payload.
/// Extends [Equatable] so concrete presentations keep value equality.
abstract class PolicyCardPresentation extends Equatable {
  const PolicyCardPresentation();
}

/// Outcome of asking a schema adapter to interpret the current config.
///
/// Invariant: an `available` selection MUST carry a non-null [presentation];
/// a null [presentation] on `available` is a contract violation and is treated
/// as "no card" by the widget registry.
class PolicyCardSelection extends Equatable {
  const PolicyCardSelection({
    required this.adapterId,
    required this.status,
    this.presentation,
    this.unsupportedReason,
  });

  /// Stable key of the adapter that produced this selection.
  final String adapterId;

  /// Whether the source can be displayed, cannot be displayed, or is
  /// unrelated.
  final PolicyCardStatus status;

  /// The presentation to render when [status] is available.
  final PolicyCardPresentation? presentation;

  /// A concise reason to show when the subtree is unsupported.
  final String? unsupportedReason;

  /// Whether a card is safe to show.
  bool get isAvailable => status == PolicyCardStatus.available;

  /// Whether the source applies to the adapter but cannot be represented.
  bool get isUnsupported => status == PolicyCardStatus.unsupported;

  @override
  List<Object?> get props => [
    adapterId,
    status,
    presentation,
    unsupportedReason,
  ];
}

/// A tool schema's read-only interpretation step.
abstract class PolicyCardAdapter {
  /// Stable key used by the widget registry. Each concrete adapter exposes a
  /// `static const adapterId` so callers reference it by name (a static member
  /// cannot share the name `id` with this instance getter), and forwards it:
  /// `String get id => adapterId;`
  String get id;

  /// The adapter **interprets** a config into a selection; only the registry
  /// below is named `select`. Method is `interpret` to match the existing
  /// `ClaudeCodePermissionsAdapter.interpret` and avoid renaming its callers.
  PolicyCardSelection interpret({
    required ToolConfig config,
    required DiscoveredConfig? discoveredConfig,
  });
}
