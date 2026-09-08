import 'package:agents_config_helper/schemas/claude_code_permissions.dart';
import 'package:agents_config_helper/schemas/cursor_permissions.dart';
import 'package:agents_config_helper/schemas/policy_card.dart';
import 'package:agents_config_helper/widgets/claude_code_permissions_card.dart';
import 'package:agents_config_helper/widgets/cursor_permissions_card.dart';
import 'package:flutter/material.dart';

/// Flutter-side mapping from adapter id to card widget.
///
/// Kept separate from the pure-Dart selection registry so the adapters and
/// selection registry stay Flutter-free. A `null` return from [buildCard]
/// means "no card here" and the caller falls back to the generic editor.
class PolicyCardWidgetRegistry {
  /// Creates a registry over the given adapter-id to builder mapping.
  PolicyCardWidgetRegistry(
    Map<String, Widget? Function(PolicyCardSelection)> builders,
  ) : _builders = Map.unmodifiable(builders);

  final Map<String, Widget? Function(PolicyCardSelection)> _builders;

  /// Default registry used by the app. Never mutated by tests; tests inject
  /// their own registry explicitly instead.
  static final PolicyCardWidgetRegistry shared = PolicyCardWidgetRegistry({
    ClaudeCodePermissionsAdapter.adapterId: _buildClaudeCard,
    CursorPermissionsAdapter.adapterId: _buildCursorCard,
  });

  /// Returns the card for [selection], or `null` when there is no card.
  ///
  /// Returns `null` when the selection is not available, when its
  /// presentation is null, when no builder is registered for its adapter id,
  /// or when the presentation has an unexpected type. Never throws.
  Widget? buildCard(PolicyCardSelection selection) {
    if (!selection.isAvailable || selection.presentation == null) {
      return null;
    }
    final builder = _builders[selection.adapterId];
    if (builder == null) {
      return null;
    }
    return builder(selection);
  }

  /// Builds the Claude card with its default documentation launcher.
  static Widget? _buildClaudeCard(PolicyCardSelection selection) {
    final presentation = selection.presentation;
    if (presentation is! ClaudeCodePermissionsPresentation) {
      return null;
    }
    return ClaudeCodePermissionsCard(presentation: presentation);
  }

  /// Builds the Cursor card with its default documentation launcher.
  static Widget? _buildCursorCard(PolicyCardSelection selection) {
    final presentation = selection.presentation;
    if (presentation is! CursorPermissionsPresentation) {
      return null;
    }
    return CursorPermissionsCard(presentation: presentation);
  }
}
