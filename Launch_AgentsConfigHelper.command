#!/usr/bin/env bash
# Double-click launcher for the macOS app built from source.
# Finder starts Terminal in $HOME, so move to the repo root first.
#
# Opens build/macos/Build/Products/Release/agents_config_helper.app, falling
# back to Debug, and builds Release first when neither exists. On the first
# run it asks scripts/ensure_launcher_icon.sh to brand this file with the
# app icon; that step is non-fatal and never blocks the launch.

set -euo pipefail

# A set CDPATH makes cd print the resolved directory into the substitution.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CDPATH='' cd -- "$script_dir"

# set -e exits before a trailing pause, so pause from the EXIT trap instead:
# a double-clicked failure must stay readable in its Terminal window.
pause_on_failure() {
  if [ "$1" -ne 0 ]; then
    printf 'Press Return to close... ' >&2
    read -r _ || true
  fi
}
trap 'pause_on_failure "$?"' EXIT

fail() {
  printf 'Launch_AgentsConfigHelper: %s\n' "$1" >&2
  exit 1
}

ensure_icon() {
  bash scripts/ensure_launcher_icon.sh || printf '%s\n' \
    'Launch_AgentsConfigHelper: icon association failed (continuing).' >&2
}

find_app() {
  local candidate
  for candidate in \
    "build/macos/Build/Products/Release/agents_config_helper.app" \
    "build/macos/Build/Products/Debug/agents_config_helper.app"; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

main() {
  if [ "$(uname -s)" != "Darwin" ]; then
    fail "This launcher supports macOS only."
  fi

  ensure_icon

  local app
  if ! app="$(find_app)"; then
    if ! command -v flutter >/dev/null 2>&1; then
      fail "No built app found and 'flutter' is not on PATH. A Finder double-click sees only the login PATH, so install Flutter where /usr/libexec/path_helper can see it, or build once from a terminal."
    fi
    printf 'No built app found; building the Release app...\n'
    flutter build macos --release || fail "flutter build macos --release failed."
    app="build/macos/Build/Products/Release/agents_config_helper.app"
    [ -d "$app" ] || fail "Build finished but $app was not produced."
  fi

  open "$app" || fail "Could not open $app."
  printf 'Opened %s\n' "$app"
}

main "$@"
