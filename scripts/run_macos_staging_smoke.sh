#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'This staging launcher supports macOS only.' >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
fixture_root="$repo_root/test/fixtures/staging_home"
app_path="$repo_root/build/macos/Build/Products/Debug/agents_config_helper.app"
marker_name='.agents-config-helper-test-root'
marker_contents='agents-config-helper staging root v1'
staging_parent="$(cd -- "${TMPDIR:?TMPDIR must be set on macOS}" && pwd -P)"

if [[ ! -d "$fixture_root" ]]; then
  printf 'Missing staging fixture tree: %s\n' "$fixture_root" >&2
  exit 1
fi
if [[ ! -d "$app_path" ]]; then
  printf '%s\n' 'Build the app first: flutter build macos --debug' >&2
  exit 1
fi

umask 077
test_root="$(mktemp -d "$staging_parent/agents-config-helper-staging.XXXXXX")"
cp -R "$fixture_root"/. "$test_root"/
printf '%s' "$marker_contents" > "$test_root/$marker_name"

printf 'Created staging root: %s\n' "$test_root"
printf '%s\n' 'The app opens in TEST ROOT MODE. Do not add personal configuration files.'
printf '%s\n' 'Optional project fixture: add the workspace directory through the app.'
printf '%s\n' 'After inspection and app exit, remove only this root with:'
printf '  scripts/cleanup_macos_staging_root.sh %q\n' "$test_root"

open -n "$app_path" --args "--test-root=$test_root"
