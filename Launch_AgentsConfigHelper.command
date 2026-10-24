#!/usr/bin/env bash
# Double-click launcher for the macOS app built from source.
# Finder starts Terminal in $HOME, so move to the repo root first.
#
# Opens build/macos/Build/Products/Release/agents_config_helper.app when that
# bundle has an executable, otherwise Debug, and builds Release when neither
# usable bundle exists. A directory left behind by an interrupted build does
# not count. On the first run it asks scripts/ensure_launcher_icon.sh to brand
# this file with the app icon; that step is non-fatal and never blocks the launch.

set -euo pipefail

# A set CDPATH makes cd print the resolved directory into the substitution.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CDPATH='' cd -- "$script_dir"

BUILD_LOCK="$script_dir/.agents-config-helper-launcher-build.lock"
build_lock_held=0

# set -e exits before a trailing pause, so pause from the EXIT trap instead:
# a double-clicked failure must stay readable in its Terminal window.
pause_on_failure() {
  if [ "$1" -ne 0 ]; then
    printf 'Press Return to close... ' >&2
    read -r _ || true
  fi
}

release_build_lock() {
  if [ "$build_lock_held" -eq 1 ]; then
    rm -rf "$BUILD_LOCK"
    build_lock_held=0
  fi
}

on_exit() {
  local status="$1"
  release_build_lock
  pause_on_failure "$status"
}
trap 'on_exit "$?"' EXIT

fail() {
  printf 'Launch_AgentsConfigHelper: %s\n' "$1" >&2
  exit 1
}

ensure_icon() {
  bash scripts/ensure_launcher_icon.sh || printf '%s\n' \
    'Launch_AgentsConfigHelper: icon association failed (continuing).' >&2
}

# A finished bundle has the product executable. An empty .app directory,
# such as one left by a failed Release build, is not launchable.
launchable_bundle() {
  local exe="$1/Contents/MacOS/agents_config_helper"
  [ -f "$exe" ] && [ -x "$exe" ]
}

find_app() {
  local candidate
  for candidate in \
    "build/macos/Build/Products/Release/agents_config_helper.app" \
    "build/macos/Build/Products/Debug/agents_config_helper.app"; do
    if launchable_bundle "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# One launcher builds the shared product directory. Waiters re-check after
# the lock so they open the finished bundle instead of starting a second build.
# A lock whose owner is gone is removed so a crashed build cannot stick.
acquire_build_lock() {
  local i=0 holder
  while [ "$i" -lt 900 ]; do
    if mkdir "$BUILD_LOCK" 2>/dev/null; then
      printf '%s\n' "$$" > "$BUILD_LOCK/pid"
      build_lock_held=1
      return 0
    fi
    holder="$(cat "$BUILD_LOCK/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$BUILD_LOCK"
      continue
    fi
    i=$((i + 1))
    sleep 1
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
    acquire_build_lock || fail "Another launcher is still building the Release app."
    if ! app="$(find_app)"; then
      printf 'No built app found; building the Release app...\n'
      flutter build macos --release || fail "flutter build macos --release failed."
      app="build/macos/Build/Products/Release/agents_config_helper.app"
      launchable_bundle "$app" || fail "Build finished but $app was not produced."
    fi
    release_build_lock
  fi

  open "$app" || fail "Could not open $app."
  printf 'Opened %s\n' "$app"
}

main "$@"
