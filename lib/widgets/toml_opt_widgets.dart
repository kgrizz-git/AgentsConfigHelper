import 'package:agents_config_helper/widgets/toml_opt_in_banner.dart';
import 'package:flutter/material.dart';

/// The TOML structured-save opt-in/opt-out widgets for `ConfigEditor`.
///
/// Renders nothing when [isTomlStructured] is false. Otherwise shows the
/// opt-out row when [enabled], or the opt-in banner with top spacing when
/// disabled. Pure presentation: the enable/disable decisions stay with the
/// owner. Extracted from `ConfigEditor` to hold the 700-line file cap.
class TomlOptWidgets extends StatelessWidget {
  /// Creates the opt widgets.
  const TomlOptWidgets({
    required this.isTomlStructured,
    required this.enabled,
    required this.onEnable,
    required this.onDisable,
    super.key,
  });

  /// Whether the open file is a TOML file shown with structured editing.
  final bool isTomlStructured;

  /// Whether structured TOML saves are currently enabled.
  final bool enabled;

  /// Called when the user enables structured TOML saves.
  final VoidCallback onEnable;

  /// Called when the user disables structured TOML saves.
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    if (!isTomlStructured) return const SizedBox.shrink();
    if (enabled) return TomlOptOutRow(onDisable: onDisable);
    // min + stretch keeps the pre-extraction layout: full-width banner with
    // top spacing, no vertical expansion.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TomlOptInBanner(onEnable: onEnable),
      ],
    );
  }
}
