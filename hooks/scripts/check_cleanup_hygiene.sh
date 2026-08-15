#!/usr/bin/env bash
# Pre-commit hook: cleanup hygiene check for completed work artifacts.

set -euo pipefail

POLICY_CONTEXT_MAX_AGE_DAYS="${POLICY_CONTEXT_MAX_AGE_DAYS:-14}"
POLICY_WARN_CHANGELOG_DAYS="${POLICY_WARN_CHANGELOG_DAYS:-7}"
POLICY_WARN_AS_ERROR="${POLICY_WARN_AS_ERROR:-0}"

issues=()

# --- 1. TODO cleanup: warn about completed checklist items ---
for todo_file in to_do.md TODO.md; do
    if [ -f "$todo_file" ]; then
        count=$(grep -c -E '^\s*-\s+\[x\]' "$todo_file" 2>/dev/null || true)
        if [ "$count" -gt 0 ]; then
            issues+=("${todo_file}: Found ${count} completed items that should be removed/logged")
        fi
    fi
done

# --- 2. Plan archival: warn if complete/abandoned plans aren't in plans/archive/ ---
if [ -d plans ]; then
    while IFS= read -r plan_file; do
        if grep -q -i -E 'Status:\s*(complete|abandoned)' "$plan_file" 2>/dev/null; then
            issues+=("${plan_file}: Plan marked complete/abandoned but not in plans/archive/")
        fi
    done < <(find plans -type f -name '*.md' -not -path 'plans/archive/*')
fi

# --- 3. Stale .context/ files ---
if [ -d .context ]; then
    cutoff=$(date -d "-${POLICY_CONTEXT_MAX_AGE_DAYS} days" +%s 2>/dev/null \
        || date -v-"${POLICY_CONTEXT_MAX_AGE_DAYS}"d +%s 2>/dev/null)
    now=$(date +%s)
    for context_file in .context/*; do
        [ -f "$context_file" ] || continue
        mtime=$(stat -f %m "$context_file" 2>/dev/null || stat -c %Y "$context_file" 2>/dev/null)
        if [ "$mtime" -lt "$cutoff" ]; then
            age_days=$(( (now - mtime) / 86400 ))
            issues+=("${context_file}: Scratch file ${age_days} days old (consider cleanup)")
        fi
    done
fi

# --- 4. Missing changelog entries ---
changelog_files=(CHANGELOG.md CHANGELOG.dev.md MAINTENANCE.md)
has_changelog=false
for cf in "${changelog_files[@]}"; do
    if [ -f "$cf" ]; then
        has_changelog=true
        break
    fi
done

if $has_changelog; then
    recent_commits=$(git log "--since=${POLICY_WARN_CHANGELOG_DAYS} days ago" --pretty=format:%h\ %s 2>/dev/null || true)
    if [ -n "$recent_commits" ]; then
        significant=0
        while IFS= read -r line; do
            lower=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
            case "$lower" in
                *merge*|*wip*|*draft*|*cleanup*|*typo*) continue ;;
            esac
            significant=$((significant + 1))
        done <<< "$recent_commits"

        if [ "$significant" -gt 3 ]; then
            changelog_modified=false
            for cf in "${changelog_files[@]}"; do
                if [ -f "$cf" ]; then
                    touched=$(git log "--since=${POLICY_WARN_CHANGELOG_DAYS} days ago" --pretty=format:%h -- "$cf" 2>/dev/null || true)
                    if [ -n "$touched" ]; then
                        changelog_modified=true
                        break
                    fi
                fi
            done
            if ! $changelog_modified; then
                issues+=("Found ${significant} significant commits in last ${POLICY_WARN_CHANGELOG_DAYS} days but no changelog updates")
            fi
        fi
    fi
fi

# --- Output ---
if [ ${#issues[@]} -eq 0 ]; then
    echo "✓ Cleanup hygiene check passed"
    exit 0
fi

echo "Cleanup hygiene warnings:"
for issue in "${issues[@]}"; do
    echo "  ⚠ ${issue}"
done
echo ""
echo "Run 'prompts/cleanup-completed-work.md' to address these issues"

if [ "$POLICY_WARN_AS_ERROR" = "1" ]; then
    echo ""
    echo "POLICY_WARN_AS_ERROR=1: treating warnings as errors"
    exit 1
fi

exit 0
