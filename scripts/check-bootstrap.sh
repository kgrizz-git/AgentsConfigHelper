#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2012
# check-bootstrap.sh — verify bootstrap phases by repo evidence, not by claims.
#
# Run: bash scripts/check-bootstrap.sh
#
# Checks what actually exists in the repo for each phase of
# prompts/bootstrap-checklist.md. Where .context/bootstrap-state.md claims a phase
# is done but the evidence is missing, this script is right and the state file is wrong.
#
# Advisory by default: exits 0 unless --strict is passed. Never blocks a commit.
# Exit codes: 0 = ok (or advisory), 1 = missing evidence under --strict.

set -uo pipefail

STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

MISSING=0
SKIPPED=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
miss() { echo -e "  ${RED}✗${NC} $1"; MISSING=$((MISSING + 1)); }
note() { echo -e "  ${YELLOW}·${NC} $1"; }
phase() { echo -e "\n${BLUE}$1${NC}"; }

STATE=".context/bootstrap-state.md"

# Return 0 if the state file marks this phase id as skipped.
is_skipped() {
    [ -f "$STATE" ] || return 1
    grep -qiE "^\|[[:space:]]*$1[[:space:]]*\|.*\|[[:space:]]*skipped" "$STATE"
}

# Report a phase the state file marks skipped, and short-circuit its checks.
skip_guard() {
    if is_skipped "$1"; then
        note "$1 marked skipped in $STATE — not checked"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi
    return 1
}

echo "Bootstrap Evidence Check"
echo "========================"

# Running inside the template itself: findings are expected, not defects.
if [ -f prompts/bootstrap-checklist.md ] && [ -d inventory ] && [ ! -f .context/project-profile.md ]; then
    echo -e "${YELLOW}This looks like the template repo, not a bootstrapped project.${NC}"
    echo "Findings below are expected here — run this in the generated project."
fi

if [ -f "$STATE" ]; then
    echo "State file: $STATE"
else
    echo -e "${YELLOW}No $STATE — start it from templates/bootstrap-state.md (Phase P0).${NC}"
fi

# ── P1 — Project profile ─────────────────────────────────────────────────────
phase "P1  Profile"
if ! skip_guard P1; then
    if [ -f .context/project-profile.md ]; then
        pass ".context/project-profile.md exists"
        if grep -qE "^(Data classification|Repository data rule):.*TBD" .context/project-profile.md; then
            miss "profile still has TBD data classification (see prompts/bootstrap/card-data-classification.md)"
        else
            pass "data classification recorded"
        fi
        grep -q "## Agent tooling" .context/project-profile.md \
            && pass "agent tooling section present" \
            || miss "profile missing '## Agent tooling' section (P5.5)"
    else
        miss ".context/project-profile.md missing — run prompts/project-init-profile.md"
    fi
fi

# ── P2 — Remote repointed away from the template ─────────────────────────────
phase "P2  Remote"
if ! skip_guard P2; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        remote=$(git remote get-url origin 2>/dev/null || echo "")
        if [ -z "$remote" ]; then
            miss "no 'origin' remote configured"
        elif echo "$remote" | grep -qiE "template-repo|template-seed|project-seed"; then
            miss "origin still points at the template: $remote"
        else
            pass "origin repointed: $remote"
        fi
    else
        miss "not a git repository"
    fi
fi

# ── P3 — Repo hygiene ────────────────────────────────────────────────────────
phase "P3  Repo hygiene"
if ! skip_guard P3; then
    if [ -f CODEOWNERS ] || [ -f .github/CODEOWNERS ]; then
        pass "CODEOWNERS present"
    else
        note "no CODEOWNERS (expected for full tier / regulated data)"
    fi
    if [ -f SECURITY.md ] || [ -f .github/SECURITY.md ]; then
        pass "SECURITY.md present"
    else
        note "no SECURITY.md (expected for public repos)"
    fi
    [ -f .github/dependabot.yml ] \
        && pass "Dependabot configured" \
        || note "no .github/dependabot.yml"
    note "branch rulesets and secret-scanning live in GitHub settings — verify manually"
fi

# ── P4 — Hooks & CI ──────────────────────────────────────────────────────────
phase "P4  Hooks & CI"
if ! skip_guard P4; then
    if [ -f .pre-commit-config.yaml ]; then
        pass "root .pre-commit-config.yaml present"
        [ -f .git/hooks/pre-commit ] \
            && pass "pre-commit installed in .git/hooks" \
            || miss "pre-commit config exists but 'pre-commit install' was not run"
    else
        miss "no root .pre-commit-config.yaml (copy hooks/.pre-commit-config.yaml)"
    fi
    if compgen -G ".github/workflows/*.y*ml" >/dev/null 2>&1; then
        pass "CI workflows present: $(ls .github/workflows/*.y*ml 2>/dev/null | wc -l | tr -d ' ')"
    else
        miss "no workflows in .github/workflows/ (see ci/README.md)"
    fi
fi

# ── P4.5 — Environment ───────────────────────────────────────────────────────
phase "P4.5  Environment"
if ! skip_guard P4.5; then
    [ -f .envrc.example ] && pass ".envrc.example committed" || miss "no .envrc.example (direnv)"
    if [ -f .envrc ]; then
        git check-ignore -q .envrc 2>/dev/null \
            && pass ".envrc is gitignored" \
            || miss ".envrc exists but is NOT gitignored"
    fi
    if git ls-files --error-unmatch .env >/dev/null 2>&1; then
        miss ".env is TRACKED by git — remove it from the index immediately"
    fi
fi

# ── P5.5 — Agent tooling ─────────────────────────────────────────────────────
phase "P5.5  Agent tooling"
if ! skip_guard P5.5; then
    grep -q "^\.agent-state/" .gitignore 2>/dev/null \
        && pass ".agent-state/ gitignored" \
        || miss ".agent-state/ not in .gitignore (policies/agent-tooling-contract.md)"
    grep -q "Agent tooling policy" AGENTS.md 2>/dev/null \
        && pass "tooling contract pasted into AGENTS.md" \
        || miss "AGENTS.md has no 'Agent tooling policy' block"
fi

# ── P6 — Agent harness ───────────────────────────────────────────────────────
phase "P6  Agent harness"
if ! skip_guard P6; then
    if [ -f AGENTS.md ]; then
        lines=$(wc -l < AGENTS.md | tr -d ' ')
        if [ "$lines" -lt 10 ]; then
            miss "AGENTS.md is a $lines-line stub — write the project's own entrypoint"
        else
            pass "AGENTS.md present ($lines lines)"
        fi
    else
        miss "no AGENTS.md"
    fi
fi

# ── P7 — Docs & gardening ────────────────────────────────────────────────────
phase "P7  Docs & gardening"
if ! skip_guard P7; then
    [ -f CHANGELOG.md ] && pass "CHANGELOG.md present" || note "no CHANGELOG.md"
    [ -f README.md ] && pass "README.md present" || miss "no README.md"
fi

# ── PS — Sensitive data (only when classification is regulated) ──────────────
phase "PS  Sensitive data (conditional)"
if grep -qiE "^Data classification:.*regulated" .context/project-profile.md 2>/dev/null; then
    echo "  classification = regulated — gates are REQUIRED:"
    [ -f .gitignore-protected ] \
        && pass ".gitignore-protected present" \
        || miss "no .gitignore-protected"
    [ -f .forbidden-paths ] \
        && pass ".forbidden-paths present" \
        || miss "no .forbidden-paths"
else
    note "classification is not 'regulated' — Phase S not applicable"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
if [ "$MISSING" -eq 0 ]; then
    echo -e "${GREEN}All checked phases have supporting evidence.${NC}"
else
    echo -e "${RED}$MISSING item(s) missing evidence.${NC} Each maps to a phase in prompts/bootstrap-checklist.md."
fi
[ "$SKIPPED" -gt 0 ] && echo "$SKIPPED phase(s) skipped per $STATE."
echo "This checks evidence, not intent. A deliberate skip belongs in $STATE with a reason."

if [ "$STRICT" -eq 1 ] && [ "$MISSING" -gt 0 ]; then
    exit 1
fi
exit 0
