#!/usr/bin/env bash
# Enforces a maximum file length for dart files.
MAX_LINES=700
EXIT_CODE=0

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

for file in "$@"; do
    if [[ "$file" == *.dart ]]; then
        [[ -e "$file" ]] || continue
        resolved_file=$(cd "$(dirname -- "$file")" 2>/dev/null && pwd -P)/$(basename -- "$file")
        # `pwd -P` canonicalizes the directory, but the final component may
        # still be a symlink. Reject it: -f follows links, so also require the
        # resolved target itself is not a symlink before the containment check,
        # so wc only reads a real file resolved within the repo.
        [[ -f "$resolved_file" && ! -L "$resolved_file" ]] || continue
        case "$resolved_file" in
            "$REPO_ROOT"/*) ;;
            *) continue ;;
        esac
        LINES=$(wc -l < "$resolved_file")
        if [[ "$LINES" -gt "$MAX_LINES" ]]; then
            echo "Error: $file has $LINES lines, which exceeds the maximum of $MAX_LINES." >&2
            EXIT_CODE=1
        fi
    fi
done

exit $EXIT_CODE
