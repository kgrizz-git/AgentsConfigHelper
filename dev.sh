#!/usr/bin/env bash

# A thin developer command menu. Safety-sensitive staging and cleanup remain
# implemented by their dedicated scripts.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$script_dir"

usage() {
  cat <<'EOF'
Usage: ./dev.sh [command]

Commands:
  --run                 Launch the macOS app normally from source.
  --build-macos         Build the debug macOS app.
  --smoke               Build, then launch a disposable macOS test-root smoke run.
  --cleanup <root>      Remove one validated staging root after confirmation.
  --check               Format-check, analyze, and run the Flutter test suite.
  --help                Show this help.

With no command, choose an action interactively. See docs/macos-test-root.md
before using --smoke or --cleanup.
EOF
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '%s\n' 'This action supports macOS only.' >&2
    exit 1
  fi
}

run_normally() {
  require_macos
  flutter run -d macos
}

build_macos() {
  require_macos
  flutter build macos --debug
}

run_smoke() {
  cat <<'EOF'

Creating a disposable macOS test-root smoke run:
  - builds the debug app;
  - copies only repository-owned, token-free fixtures into a private temporary root;
  - launches the app with --test-root so config, backup, restore, and preference I/O stay
    below that root; and
  - leaves the root in place for manual inspection and explicit cleanup after the app exits.

Confirm the app displays TEST ROOT MODE before editing anything.
EOF
  build_macos
  scripts/run_macos_staging_smoke.sh
}

cleanup_root() {
  local root="$1"
  printf 'Remove validated staging root %q? [y/N] ' "$root"
  local answer
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    scripts/cleanup_macos_staging_root.sh "$root"
  else
    printf '%s\n' 'Cleanup cancelled.'
  fi
}

run_checks() {
  dart format --output=none --set-exit-if-changed .
  flutter analyze --fatal-infos
  flutter test
}

interactive_menu() {
  while true; do
    cat <<'EOF'

Choose an action:
  1) Launch the macOS app normally
  2) Build the debug macOS app
  3) Build and launch a disposable test-root smoke run
     (uses token-free fixtures; leaves the root for inspection and explicit cleanup)
  4) Show the manual smoke checklist
  5) Clean up a staging root
  6) Run format, analysis, and tests
  q) Quit
EOF
    printf '> '
    local choice
    read -r choice
    case "$choice" in
      1) run_normally ;;
      2) build_macos ;;
      3) run_smoke ;;
      4)
        printf '%s\n' \
          'Confirm TEST ROOT MODE, inspect user and project fixtures, perform one raw and one structured edit, then verify diff, backup, restore, and preferences stay below the printed root.' \
          'See docs/macos-test-root.md for the complete checklist.'
        ;;
      5)
        printf 'Staging root to remove: '
        local root
        read -r root
        [[ -n "$root" ]] && cleanup_root "$root"
        ;;
      6) run_checks ;;
      q|Q) return ;;
      *) printf '%s\n' 'Choose 1-6 or q.' >&2 ;;
    esac
  done
}

if [[ $# -eq 0 ]]; then
  interactive_menu
  exit 0
fi

case "$1" in
  --run) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; run_normally ;;
  --build-macos) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; build_macos ;;
  --smoke) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; run_smoke ;;
  --cleanup)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    cleanup_root "$2"
    ;;
  --check) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; run_checks ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
