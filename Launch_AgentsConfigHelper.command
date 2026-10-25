#!/usr/bin/env bash
# Double-click launcher for the macOS app built from source.
# Finder starts Terminal in $HOME, so move to the repo root first.
#
# Opens build/macos/Build/Products/Release/agents_config_helper.app when that
# bundle has its executable and a valid Contents/Info.plist, otherwise Debug,
# and builds Release when neither usable bundle exists. A directory left
# behind by an interrupted build does not count. On the first run it asks
# scripts/ensure_launcher_icon.sh to brand this file with the app icon; that
# step is non-fatal and never blocks the launch.

set -euo pipefail

# A set CDPATH makes cd print the resolved directory into the substitution.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CDPATH='' cd -- "$script_dir"

BUILD_LOCK="$script_dir/.agents-config-helper-launcher-build.lock"
build_lock_held=0
build_lock_private=""

# set -e exits before a trailing pause, so pause from the EXIT trap instead:
# a double-clicked failure must stay readable in its Terminal window.
pause_on_failure() {
  if [ "$1" -ne 0 ]; then
    printf 'Press Return to close... ' >&2
    read -r _ || true
  fi
}

# Drop the public lock only when it still points at this process's private
# directory. A waiter that replaced the symlink is left alone.
release_build_lock() {
  local current held
  if [ "$build_lock_held" -ne 1 ]; then
    return 0
  fi
  build_lock_held=0
  current="$(readlink "$BUILD_LOCK" 2>/dev/null || true)"
  if [ "$current" != "$build_lock_private" ]; then
    return 0
  fi
  held="$script_dir/tmp/launcher-build-lock.releasing.$$"
  rm -rf "$held"
  if mv "$BUILD_LOCK" "$held" 2>/dev/null; then
    current="$(readlink "$held" 2>/dev/null || true)"
    if [ "$current" = "$build_lock_private" ]; then
      rm -f "$held"
      rm -rf "$build_lock_private"
    else
      mv "$held" "$BUILD_LOCK" 2>/dev/null || true
    fi
  fi
  build_lock_private=""
}

on_exit() {
  local status="$1"
  # find_app runs in a command substitution. That subshell inherits this trap,
  # and exiting it must not release the lock the parent still holds.
  [ "${BASH_SUBSHELL:-0}" -eq 0 ] || return 0
  release_build_lock
  rm -rf "$script_dir/tmp/launcher-build-lock.preparing.$$" \
    "$script_dir/tmp/launcher-build-lock.stale.$$" \
    "$script_dir/tmp/launcher-build-lock.releasing.$$"
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

# Info.plist is a required part of a macOS app bundle. Accept it only when it
# parses and names this product's executable. Without plutil (test hosts),
# require the same keys in an XML plist.
valid_info_plist() {
  local plist="$1" exe pkg
  [ -f "$plist" ] && [ -s "$plist" ] || return 1
  if [ -x /usr/bin/plutil ]; then
    /usr/bin/plutil -lint -s "$plist" >/dev/null 2>&1 || return 1
    exe="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$plist" 2>/dev/null || true)"
    pkg="$(/usr/bin/plutil -extract CFBundlePackageType raw -o - "$plist" 2>/dev/null || true)"
    [ "$exe" = "agents_config_helper" ] || return 1
    [ "$pkg" = "APPL" ] || return 1
    return 0
  fi
  grep -q '<key>CFBundleExecutable</key>' "$plist" || return 1
  grep -q '<string>agents_config_helper</string>' "$plist" || return 1
  grep -q '<key>CFBundlePackageType</key>' "$plist" || return 1
  grep -q '<string>APPL</string>' "$plist" || return 1
}

# A finished bundle has the product executable and a valid Contents/Info.plist.
# An empty directory, or an executable left without that plist, is not launchable.
launchable_bundle() {
  local exe="$1/Contents/MacOS/agents_config_helper"
  [ -f "$exe" ] && [ -x "$exe" ] || return 1
  valid_info_plist "$1/Contents/Info.plist"
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

# The pid file is written in a private directory, then a symlink to that
# directory becomes the public lock. ln fails when the public name exists, so
# a crash before the link does not publish an ownerless lock. mv onto an
# existing directory would succeed by nesting the new lock inside it.
publish_build_lock() {
  local private="$script_dir/tmp/launcher-build-lock.preparing.$$"
  mkdir -p "$script_dir/tmp" || return 1
  rm -rf "$private"
  mkdir "$private" || return 1
  printf '%s\n' "$$" > "$private/pid" || {
    rm -rf "$private"
    return 1
  }
  # ln follows an existing directory and reports success by nesting the new
  # link inside it. An occupied name is not ours; -h then keeps a symlink
  # that won the race from being followed.
  if [ -e "$BUILD_LOCK" ] || [ -L "$BUILD_LOCK" ]; then
    rm -rf "$private"
    return 1
  fi
  if ln -h -s "$private" "$BUILD_LOCK" 2>/dev/null; then
    build_lock_private="$private"
    build_lock_held=1
    return 0
  fi
  rm -rf "$private"
  return 1
}

# One waiter renames a dead or ownerless lock aside and deletes that copy.
# The public name is then free. The renamed copy is not a lock someone else
# just published, including a symlink that replaced the stale one.
claim_stale_build_lock() {
  local holder target private="$script_dir/tmp/launcher-build-lock.stale.$$"
  if [ ! -e "$BUILD_LOCK" ] && [ ! -L "$BUILD_LOCK" ]; then
    return 1
  fi
  holder="$(cat "$BUILD_LOCK/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    return 1
  fi
  mkdir -p "$script_dir/tmp" || return 1
  rm -rf "$private"
  if ! mv "$BUILD_LOCK" "$private" 2>/dev/null; then
    return 1
  fi
  holder="$(cat "$private/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    mv "$private" "$BUILD_LOCK" 2>/dev/null || true
    return 1
  fi
  if [ -L "$private" ]; then
    target="$(readlink "$private" 2>/dev/null || true)"
    rm -f "$private"
    if [ -n "$target" ]; then
      rm -rf "$target"
    fi
  else
    rm -rf "$private"
  fi
  return 0
}

# One launcher builds the shared product directory. Waiters re-check after
# the lock so they open the finished bundle instead of starting a second build.
acquire_build_lock() {
  local i=0
  while [ "$i" -lt 900 ]; do
    if publish_build_lock; then
      return 0
    fi
    if claim_stale_build_lock; then
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
