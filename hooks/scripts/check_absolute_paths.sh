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

    # Flag lines leaking an absolute path. URLs are excluded, but only the URL
    # portion is stripped before re-checking, so a real leak sharing a line with
    # a URL is still caught (a plain `grep -v https?://` would drop the whole
    # line and hide it).
    matches=$(
        grep -E -n "$LEAK_PATTERN" "$file" | while IFS= read -r match; do
            stripped=$(printf '%s' "$match" | sed -E 's#https?://[^[:space:]]*##g')
            if printf '%s' "$stripped" | grep -E -q "$LEAK_PATTERN"; then
                printf '%s\n' "$match"
            fi
        done
    )
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
