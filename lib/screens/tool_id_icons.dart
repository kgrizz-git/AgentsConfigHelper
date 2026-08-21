/// Icon mapping for [ToolId] values shown in the main shell sidebar.
///
/// Kept outside `MainShell` so that file stays under the repo line-length
/// gate while the switch remains exhaustive over [ToolId].
library;

import 'package:agents_config_helper/models/tool_descriptor.dart';
import 'package:flutter/material.dart';

/// Returns the Material icon used for [toolId] in the sidebar.
IconData iconForToolId(ToolId toolId) {
  // Exhaustive over ToolId so a newly added tool fails to compile until it
  // gets an explicit icon, rather than silently falling through.
  switch (toolId) {
    case ToolId.claudeCode:
      return Icons.code;
    case ToolId.cursor:
      return Icons.edit;
    case ToolId.cursorIde:
      return Icons.integration_instructions;
    case ToolId.opencode:
      return Icons.open_in_browser;
    case ToolId.paseo:
      return Icons.directions_walk;
    case ToolId.kiro:
      return Icons.keyboard;
    case ToolId.devin:
      return Icons.developer_mode;
    case ToolId.antigravity:
      return Icons.rocket_launch;
    case ToolId.antigravityIde:
      return Icons.computer;
    case ToolId.antigravityApp:
      return Icons.desktop_windows;
    case ToolId.codex:
      return Icons.book;
    case ToolId.agyAcp:
      return Icons.api;
    case ToolId.kilo:
      return Icons.memory;
    case ToolId.cline:
      return Icons.terminal;
    case ToolId.lmStudio:
      return Icons.hub;
    case ToolId.copilot:
      return Icons.flight_takeoff;
    case ToolId.agentsMd:
      return Icons.groups;
  }
}
