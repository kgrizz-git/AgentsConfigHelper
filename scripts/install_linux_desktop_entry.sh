#!/usr/bin/env bash
# install_linux_desktop_entry.sh — register a source build with the Linux desktop.
#
# Run: bash scripts/install_linux_desktop_entry.sh [--uninstall] [bundle-dir]
#
# Wayland compositors (GNOME, KDE) take a window's taskbar icon from the
# .desktop entry whose name matches the app ID, not from the window itself.
# A source build has no installed entry, so this script writes one under
# ~/.local/share (no sudo) pointing at the built bundle. Run it once after
# `flutter build linux` or `flutter run -d linux`; rerun if the bundle moves.
#
# bundle-dir defaults to the release bundle if it exists, else the debug one.
# --uninstall removes the entry and icon this script installed.

set -euo pipefail

APP_ID="com.example.agents_config_helper"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_FILE="$DATA_HOME/applications/$APP_ID.desktop"
ICON_FILE="$DATA_HOME/icons/hicolor/256x256/apps/$APP_ID.png"

refresh_caches() {
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

if [[ "${1:-}" = "--uninstall" ]]; then
  rm -f "$DESKTOP_FILE" "$ICON_FILE"
  refresh_caches
  echo "Removed $DESKTOP_FILE and $ICON_FILE"
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux only." >&2
  exit 1
fi

BUNDLE_DIR="${1:-}"
if [[ -z "$BUNDLE_DIR" ]]; then
  for mode in release debug profile; do
    candidate="$REPO_ROOT/build/linux/x64/$mode/bundle"
    if [[ -x "$candidate/agents_config_helper" ]]; then
      BUNDLE_DIR="$candidate"
      break
    fi
  done
fi

if [[ -z "$BUNDLE_DIR" ]] || [[ ! -x "$BUNDLE_DIR/agents_config_helper" ]]; then
  echo "No built bundle found. Run 'flutter build linux' first, or pass the bundle directory." >&2
  exit 1
fi
BUNDLE_DIR="$(cd "$BUNDLE_DIR" && pwd)"

mkdir -p "$(dirname "$DESKTOP_FILE")" "$(dirname "$ICON_FILE")"
cp "$REPO_ROOT/linux/runner/resources/app_icon.png" "$ICON_FILE"

cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Agents Config Helper
Comment=View and edit AI agent and IDE configuration
Exec="$BUNDLE_DIR/agents_config_helper"
Icon=$APP_ID
Terminal=false
Categories=Development;Utility;
StartupWMClass=$APP_ID
EOF

refresh_caches
echo "Installed $DESKTOP_FILE"
echo "Installed $ICON_FILE"
echo "Launch target: $BUNDLE_DIR/agents_config_helper"
echo "If the taskbar still shows a generic icon, log out and back in once."
