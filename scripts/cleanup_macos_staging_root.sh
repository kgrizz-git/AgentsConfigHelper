#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'This staging cleanup supports macOS only.' >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <staging-root>\n' "$0" >&2
  exit 1
fi

marker_name='.agents-config-helper-test-root'
marker_contents='agents-config-helper staging root v1'
staging_parent="${TMPDIR:?TMPDIR must be set on macOS}"
input_root="$1"

if [[ -L "$input_root" ]]; then
  printf '%s\n' 'Refusing to remove a symbolic-link root.' >&2
  exit 1
fi
if [[ ! -d "$input_root" ]]; then
  printf 'Staging root does not exist: %s\n' "$input_root" >&2
  exit 1
fi

physical_parent="$(cd -- "$staging_parent" && pwd -P)"
physical_root="$(cd -- "$input_root" && pwd -P)"
case "$physical_root" in
  "$physical_parent"/agents-config-helper-staging.*) ;;
  *)
    printf '%s\n' 'Refusing to remove a path outside the script-created staging prefix.' >&2
    exit 1
    ;;
esac

marker_path="$physical_root/$marker_name"
if [[ -L "$marker_path" || ! -f "$marker_path" ]]; then
  printf '%s\n' 'Refusing to remove a root without the regular staging marker.' >&2
  exit 1
fi
if [[ "$(<"$marker_path")" != "$marker_contents" ]]; then
  printf '%s\n' 'Refusing to remove a root with an unexpected staging marker.' >&2
  exit 1
fi

rm -rf "$physical_root"
printf 'Removed staging root: %s\n' "$physical_root"
