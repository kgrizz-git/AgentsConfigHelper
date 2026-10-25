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

# Put a lock we renamed aside back on the public name only when that name is
# free. mv onto an existing symlink replaces it, and mv onto a directory nests
# the restored lock inside the directory.
restore_claimed_lock() {
  local from="$1" target
  if [ -e "$BUILD_LOCK" ] || [ -L "$BUILD_LOCK" ]; then
    return 1
  fi
  if [ -L "$from" ]; then
    target="$(readlink "$from" 2>/dev/null || true)"
    [ -n "$target" ] || return 1
    link_lock "$target" "$BUILD_LOCK" || return 1
    rm -f "$from"
    return 0
  fi
  mv "$from" "$BUILD_LOCK" 2>/dev/null || return 1
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
      restore_claimed_lock "$held" || true
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
  discard_lock_aside "$script_dir/tmp/launcher-build-lock.preparing.$$"
  discard_lock_aside "$script_dir/tmp/launcher-build-lock.stale.$$"
  discard_lock_aside "$script_dir/tmp/launcher-build-lock.releasing.$$"
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

# symlink(2) fails when the name exists, including when it is a directory.
# ln follows a directory and would report success by nesting the new link.
link_lock() {
  local source="$1" dest="$2"
  if [ -x /usr/bin/perl ]; then
    /usr/bin/perl -e 'symlink($ARGV[0], $ARGV[1]) or exit 1' "$source" "$dest"
    return $?
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    return 1
  fi
  ln -h -s "$source" "$dest"
}

# Keep the guard file in place: unlinking it would let waiters lock different
# inodes. The kernel releases flock even if the guarded launcher is killed.
with_build_lock_guard() {
  mkdir -p "$script_dir/tmp" || return 1
  /usr/bin/perl -e '
    use Fcntl qw(:flock);
    open(my $guard, ">>", shift @ARGV) or exit 1;
    flock($guard, LOCK_EX) or exit 1;
    system @ARGV;
    exit($? == -1 ? 1 : ($? & 127) ? 1 : $? >> 8);
  ' "$script_dir/tmp/launcher-build-lock.guard" \
    bash -c 'source "$1"; trap - EXIT; launcher_pid="$3"; "$2"' bash "${BASH_SOURCE[0]}" "$1" "$$"
}

publish_build_lock() {
  if with_build_lock_guard publish_build_lock_guarded; then
    build_lock_private="$script_dir/tmp/launcher-build-lock.preparing.$$"
    build_lock_held=1
    return 0
  fi
  return 1
}

claim_stale_build_lock() {
  with_build_lock_guard claim_stale_build_lock_guarded
}

# The pid file is written in a private directory, then a symlink to that
# directory becomes the public lock. A crash before the link does not publish
# an ownerless lock.
publish_build_lock_guarded() {
  local private="$script_dir/tmp/launcher-build-lock.preparing.${launcher_pid:-$$}"
  local current
  current="$(readlink "$BUILD_LOCK" 2>/dev/null || true)"
  if [ "$current" = "$private" ]; then
    build_lock_private="$private"
    build_lock_held=1
    return 0
  fi
  mkdir -p "$script_dir/tmp" || return 1
  rm -rf "$private"
  mkdir "$private" || return 1
  printf '%s\n' "${launcher_pid:-$$}" > "$private/pid" || {
    rm -rf "$private"
    return 1
  }
  if link_lock "$private" "$BUILD_LOCK"; then
    build_lock_private="$private"
    build_lock_held=1
    return 0
  fi
  rm -rf "$private"
  return 1
}

# One waiter renames a dead or ownerless lock aside and deletes that copy.
# The shared guard excludes publication throughout inspection and rename.
# Keep the post-move live-owner check as a defensive fallback.
claim_stale_build_lock_guarded() {
  local holder target private="$script_dir/tmp/launcher-build-lock.stale.${launcher_pid:-$$}"
  if [ ! -e "$BUILD_LOCK" ] && [ ! -L "$BUILD_LOCK" ]; then
    return 1
  fi
  holder="$(cat "$BUILD_LOCK/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    return 1
  fi
  mkdir -p "$script_dir/tmp" || return 1
  if [ -e "$private" ] || [ -L "$private" ]; then
    holder="$(cat "$private/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && [ "$holder" != "${launcher_pid:-$$}" ] && kill -0 "$holder" 2>/dev/null; then
      restore_claimed_lock "$private" || true
      if [ -e "$private" ] || [ -L "$private" ]; then
        return 1
      fi
    fi
    rm -rf "$private"
  fi
  if ! mv "$BUILD_LOCK" "$private" 2>/dev/null; then
    return 1
  fi
  holder="$(cat "$private/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    restore_claimed_lock "$private" || true
    return 1
  fi
  if [ -L "$private" ]; then
    target="$(readlink "$private" 2>/dev/null || true)"
    rm -f "$private"
    remove_lock_target "$target"
  else
    rm -rf "$private"
  fi
  return 0
}

# Only delete lock directories this launcher created under tmp/.
remove_lock_target() {
  local target="$1"
  case "$target" in
    "$script_dir"/tmp/launcher-build-lock.*)
      rm -rf "$target"
      ;;
  esac
}

# Remove a private or aside path. A live lock we could not put back stays.
discard_lock_aside() {
  local path="$1" holder target
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi
  if [ "$path" = "$(readlink "$BUILD_LOCK" 2>/dev/null || true)" ]; then
    return 0
  fi
  holder="$(cat "$path/pid" 2>/dev/null || true)"
  if [ -n "$holder" ] && [ "$holder" != "$$" ] && kill -0 "$holder" 2>/dev/null; then
    restore_claimed_lock "$path" || true
    if [ -e "$path" ] || [ -L "$path" ]; then
      return 0
    fi
  fi
  if [ -L "$path" ]; then
    target="$(readlink "$path" 2>/dev/null || true)"
    rm -f "$path"
    if [ "$target" != "$(readlink "$BUILD_LOCK" 2>/dev/null || true)" ]; then
      remove_lock_target "$target"
    fi
    return 0
  fi
  rm -rf "$path"
}

# One launcher builds the shared product directory. Waiters re-check after
# the lock so they open the finished bundle instead of starting a second build.
acquire_build_lock() {
  local i=0 current prep
  prep="$script_dir/tmp/launcher-build-lock.preparing.$$"
  while [ "$i" -lt 900 ]; do
    current="$(readlink "$BUILD_LOCK" 2>/dev/null || true)"
    if [ "$current" = "$prep" ]; then
      build_lock_private="$prep"
      build_lock_held=1
      return 0
    fi
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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
