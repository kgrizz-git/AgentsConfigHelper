#!/usr/bin/env bash
# Enforces a maximum file length for dart files.
MAX_LINES=700
EXIT_CODE=0

for file in "$@"; do
    if [[ "$file" == *.dart ]]; then
        LINES=$(wc -l < "$file")
        if [ "$LINES" -gt "$MAX_LINES" ]; then
            echo "Error: $file has $LINES lines, which exceeds the maximum of $MAX_LINES."
            EXIT_CODE=1
        fi
    fi
done

exit $EXIT_CODE
