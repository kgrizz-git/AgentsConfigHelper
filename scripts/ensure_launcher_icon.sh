#!/usr/bin/env bash
# ensure_launcher_icon.sh — attach the app icon to the macOS .command launcher.
#
# Run: bash scripts/ensure_launcher_icon.sh [target-file]
#
# Gives Launch_AgentsConfigHelper.command the app icon in Finder by writing a
# custom icon (NSWorkspace via JXA). Idempotent and non-fatal: exits 0 when
# already associated, when not on macOS, when the target is absent, when a
# previous attempt failed and the icon is still missing (sentinel
# .agents-config-helper-launcher-icon-failed; delete it to retry), and on
# unexpected errors. The optional target argument exists for validation only;
# the default is the repo-root launcher.
#
# Inputs: optional target path. Icon sources, in order: Release AppIcon.icns,
# Debug AppIcon.icns, then the checked-in 1024px PNG.
# Output: status 0 always. A one-line success message on stderr-free stdout
# when a candidate is applied. A gitignored stamp of the applied resource-fork
# hash so a different custom icon is replaced on the next run.

set -euo pipefail

# Callers run under set -e. Status stays 0 even when set -u or a command
# outside main aborts the script, so icon setup can never block a launch.
trap 'exit 0' EXIT

# A set CDPATH makes cd print the resolved directory, which the command
# substitution would capture and then fail the following cd under set -e.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 0
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)" || exit 0

SENTINEL_NAME=".agents-config-helper-launcher-icon-failed"
STAMP_NAME=".agents-config-helper-launcher-icon-stamp"

warn() { printf 'ensure_launcher_icon: %s\n' "$1" >&2; }

# Finder custom-icon signals only. A partial state is not associated.
icon_signals() {
  local target="$1" hex byte8
  /usr/bin/xattr -p com.apple.ResourceFork "$target" >/dev/null 2>&1 || return 1
  hex="$(/usr/bin/xattr -px com.apple.FinderInfo "$target" 2>/dev/null | tr -d ' \n' || true)"
  [ "${#hex}" -ge 18 ] || return 1
  byte8="${hex:16:2}"
  [ $((16#$byte8 & 4)) -ne 0 ] || return 1
  return 0
}

# Hash of the icon payload. Empty or unreadable forks are not a match.
fork_hash() {
  local target="$1" sum
  /usr/bin/xattr -p com.apple.ResourceFork "$target" >/dev/null 2>&1 || return 1
  sum="$(/usr/bin/xattr -px com.apple.ResourceFork "$target" 2>/dev/null | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')" || return 1
  [ -n "$sum" ] || return 1
  printf '%s\n' "$sum"
}

# The default launcher remembers the fork it applied. Validation targets skip
# the stamp so a scratch file cannot mark the repo launcher as done.
tracks_stamp() {
  [ "$1" = "$repo_root/Launch_AgentsConfigHelper.command" ]
}

stamp_matches() {
  local target="$1" hash stamp
  tracks_stamp "$target" || return 0
  hash="$(fork_hash "$target")" || return 1
  stamp="$(tr -d '[:space:]' < "$repo_root/$STAMP_NAME" 2>/dev/null || true)"
  [ -n "$stamp" ] && [ "$stamp" = "$hash" ]
}

record_stamp() {
  local target="$1" hash
  tracks_stamp "$target" || return 0
  hash="$(fork_hash "$target")" || return 1
  printf '%s\n' "$hash" > "$repo_root/$STAMP_NAME"
}

# Associated only when the payload, the Finder flag, and (for the repo
# launcher) the stamp of that payload are all present. Any other custom icon
# is replaced.
associated() {
  icon_signals "$1" || return 1
  stamp_matches "$1" || return 1
  return 0
}

# A concurrent success can land between a failed candidate and this write.
# Do not suppress later retries when the icon is actually present.
note_failure() {
  local target="$1" sentinel="$2"
  if associated "$target"; then
    rm -f "$sentinel" || true
    return 0
  fi
  touch "$sentinel" || true
}

apply_candidate() {
  local icon="$1" target="$2" result
  result="$(/usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      ObjC.import("AppKit");
      var img = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
      if (!img || img.isNil()) { return "nil-image"; }
      var ok = $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, argv[1], 0);
      return ok ? "true" : "false";
    }' "$icon" "$target" 2>&1)" || true
  [ "$result" = "true" ] || return 1
  icon_signals "$target" || return 1
  record_stamp "$target" || return 1
  associated "$target" || return 1
  return 0
}

main() {
  local target="${1:-$repo_root/Launch_AgentsConfigHelper.command}"
  local sentinel="$repo_root/$SENTINEL_NAME"

  [ "$(uname -s)" = "Darwin" ] || return 0
  [ -e "$target" ] || return 0
  if associated "$target"; then
    rm -f "$sentinel" || true
    return 0
  fi
  # A failed attempt suppresses retries only while the icon is still absent.
  # An unrelated custom icon (signals without our stamp) is tried again.
  if [ -e "$sentinel" ] && ! icon_signals "$target"; then
    return 0
  fi
  rm -f "$sentinel" || true

  local candidate applied=0
  for candidate in \
    "$repo_root/build/macos/Build/Products/Release/agents_config_helper.app/Contents/Resources/AppIcon.icns" \
    "$repo_root/build/macos/Build/Products/Debug/agents_config_helper.app/Contents/Resources/AppIcon.icns" \
    "$repo_root/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"; do
    [ -f "$candidate" ] || continue
    if apply_candidate "$candidate" "$target"; then
      applied=1
      break
    fi
  done
  if [ "$applied" -ne 1 ]; then
    if associated "$target"; then
      rm -f "$sentinel" || true
      return 0
    fi
    warn "could not apply the app icon from any source"
    note_failure "$target" "$sentinel"
    return 0
  fi

  rm -f "$sentinel" || true
  printf 'ensure_launcher_icon: applied the app icon to %s\n' "${target##*/}"
  return 0
}

main "$@" || true
exit 0
