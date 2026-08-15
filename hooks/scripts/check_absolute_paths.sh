#!/bin/bash
# Pre-commit hook to prevent committing absolute paths that leak local filesystem information.

# Looking for paths like /Users/ or /home/ or C:/ or /var/folders/
LEAK_PATTERN="(/Users/|/home/|[a-zA-Z]:\\\\\\\\|/var/folders/)"

has_errors=0

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    if [[ "$file" == *"check_absolute_paths.sh" ]] || [[ "$file" == *"test_policy_hooks_smoke.py" ]]; then
        continue
    fi

    matches=$(grep -E -n "$LEAK_PATTERN" "$file" | grep -v -E "https?://")
    if [[ -n "$matches" ]]; then
        echo "$matches"
        echo "ERROR: Absolute path leak detected in $file"
        has_errors=1
    fi
done

if [[ $has_errors -eq 1 ]]; then
    echo "Please use relative paths or environment variables (e.g. \$HOME) instead."
    exit 1
fi

exit 0
