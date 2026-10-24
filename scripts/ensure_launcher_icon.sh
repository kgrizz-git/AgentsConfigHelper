#!/usr/bin/env bash
# ensure_launcher_icon.sh — attach the app icon to the macOS .command launcher.
#
# Run: bash scripts/ensure_launcher_icon.sh [target-file]
#
# Gives Launch_AgentsConfigHelper.command the app icon in Finder by writing a
# custom icon (NSWorkspace via JXA). Idempotent and non-fatal: exits 0 when
# already associated, when not on macOS, when the target is absent, when a
# previous attempt failed (sentinel .agents-config-helper-launcher-icon-failed;
# delete it to retry), and on unexpected errors. The optional target argument
# exists for validation only; the default is the repo-root launcher.

set -euo pipefail

# Callers run under set -e. Status stays 0 even when set -u or a command
# outside main aborts the script, so icon setup can never block a launch.
trap 'exit 0' EXIT

# A set CDPATH makes cd print the resolved directory, which the command
# substitution would capture and then fail the following cd under set -e.
script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || exit 0
repo_root="$(CDPATH='' cd -- "$script_dir/.." && pwd -P)" || exit 0

SENTINEL_NAME=".agents-config-helper-launcher-icon-failed"

warn() { printf 'ensure_launcher_icon: %s\n' "$1" >&2; }

# Associated only when the icon payload and the Finder custom-icon flag are
# both present; any partial state (flag without payload, payload without
# flag) must re-associate so a failed attempt can never look done.
associated() {
  local target="$1" hex byte8
  /usr/bin/xattr -p com.apple.ResourceFork "$target" >/dev/null 2>&1 || return 1
  hex="$(/usr/bin/xattr -px com.apple.FinderInfo "$target" 2>/dev/null | tr -d ' \n' || true)"
  [ "${#hex}" -ge 18 ] || return 1
  byte8="${hex:16:2}"
  [ $((16#$byte8 & 4)) -ne 0 ] || return 1
  return 0
}

main() {
  local target="${1:-$repo_root/Launch_AgentsConfigHelper.command}"
  local sentinel="$repo_root/$SENTINEL_NAME"

  [ "$(uname -s)" = "Darwin" ] || return 0
  [ -e "$target" ] || return 0
  [ -e "$sentinel" ] && return 0
  associated "$target" && return 0

  local icon="" candidate
  for candidate in \
    "$repo_root/build/macos/Build/Products/Release/agents_config_helper.app/Contents/Resources/AppIcon.icns" \
    "$repo_root/build/macos/Build/Products/Debug/agents_config_helper.app/Contents/Resources/AppIcon.icns" \
    "$repo_root/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"; do
    if [ -f "$candidate" ]; then
      icon="$candidate"
      break
    fi
  done
  if [ -z "$icon" ]; then
    warn "no icon source found; skipping"
    touch "$sentinel" || true
    return 0
  fi

  local result
  result="$(/usr/bin/osascript -l JavaScript -e '
    function run(argv) {
      ObjC.import("AppKit");
      var img = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
      if (!img || img.isNil()) { return "nil-image"; }
      var ok = $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, argv[1], 0);
      return ok ? "true" : "false";
    }' "$icon" "$target" 2>&1)" || true

  if [ "$result" != "true" ]; then
    warn "could not apply the app icon (${result:-no output})"
    touch "$sentinel" || true
    return 0
  fi
  if ! associated "$target"; then
    warn "setIcon reported success but the association is incomplete"
    touch "$sentinel" || true
    return 0
  fi

  printf 'ensure_launcher_icon: applied the app icon to %s\n' "${target##*/}"
  return 0
}

main "$@" || true
exit 0
