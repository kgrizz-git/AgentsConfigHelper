#!/usr/bin/env bash
# Lightweight project health check script
# Run: bash scripts/health-check.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
section() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

echo "Project Health Check"
echo "===================="

# 1. Git Configuration
section "Git Configuration"
if git rev-parse --git-dir > /dev/null 2>&1; then
    check "Git repository initialized"

    # Check for template remote
    current_remote=$(git remote get-url origin 2>/dev/null || echo "")
    if echo "$current_remote" | grep -qiE "template-repo|template-seed|project-seed"; then
        warn "Remote still points to template: $current_remote"
    else
        check "Git remote configured (not template)"
    fi

    # Check for uncommitted changes
    if [ -n "$(git status --porcelain)" ]; then
        warn "Uncommitted changes present"
    else
        check "Working directory clean"
    fi
else
    warn "Not a git repository"
fi

# 2. Environment Files
section "Environment Configuration"
if [ -f .env ]; then
    warn ".env exists (ensure it's not committed)"
else
    check "No .env file (good practice)"
fi

if [ -f .env.example ]; then
    check ".env.example exists"
else
    warn ".env.example missing"
fi

# 3. Pre-commit Hooks
section "Pre-commit Hooks"
if [ -f .pre-commit-config.yaml ]; then
    check "Pre-commit config exists"
    if command -v pre-commit &> /dev/null; then
        check "pre-commit command available"
        if [ -f .git/hooks/pre-commit ]; then
            check "Pre-commit hooks installed"
        else
            warn "Pre-commit hooks not installed (run: pre-commit install)"
        fi
    else
        warn "pre-commit not installed"
    fi
else
    warn "Pre-commit config missing"
fi

# 4. Documentation
section "Documentation"
if [ -f README.md ]; then
    check "README.md exists"
else
    warn "README.md missing"
fi

if [ -f AGENTS.md ]; then
    check "AGENTS.md exists"
else
    warn "AGENTS.md missing"
fi

if [ -f .context/project-profile.md ]; then
    check "Project profile exists"
else
    info "Project profile not created yet (run bootstrap prompt)"
fi

# 5. Security
section "Security Configuration"
if [ -f .gitignore ]; then
    if grep -q ".env" .gitignore; then
        check ".env in .gitignore"
    else
        warn ".env not in .gitignore"
    fi
else
    warn ".gitignore missing"
fi

# Check for common secret patterns
if git rev-parse --git-dir > /dev/null 2>&1; then
    if git grep -iE "api[_-]?key|secret|password|token" -- '*.env' '*.py' '*.js' '*.ts' 2>/dev/null | grep -v "example\|changeme\|TODO" > /dev/null 2>&1; then
        warn "Potential secrets found in tracked files"
    else
        check "No obvious secrets in tracked files"
    fi
fi

# 6. Project Structure
section "Project Structure"
for dir in prompts templates policies hooks inventory ci; do
    if [ -d "$dir" ]; then
        check "$dir/ directory exists"
    else
        warn "$dir/ directory missing"
    fi
done

# 7. Language-Specific Checks
section "Language-Specific"

# Python
if [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f setup.py ]; then
    info "Python project detected"
    if command -v python3 &> /dev/null || command -v python &> /dev/null; then
        check "Python available"
    else
        warn "Python not available"
    fi

    if [ -f .python-version ]; then
        check ".python-version specified"
    else
        info ".python-version not set"
    fi
fi

# Node.js
if [ -f package.json ]; then
    info "Node.js project detected"
    if command -v node &> /dev/null; then
        check "Node.js available"
    else
        warn "Node.js not available"
    fi

    if [ -d node_modules ]; then
        check "node_modules installed"
    else
        warn "Dependencies not installed (run: npm install)"
    fi
fi

# 8. CI Configuration
section "CI Configuration"
if [ -d .github/workflows ]; then
    check ".github/workflows exists"
    workflow_count=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)
    if [ "$workflow_count" -gt 0 ]; then
        check "$workflow_count workflow file(s) found"
    else
        warn "No workflow files found"
    fi
else
    info "No CI workflows configured"
fi

# 9. Hooks Scripts
section "Policy Scripts"
if [ -d hooks/scripts ]; then
    script_count=$(find hooks/scripts -name "*.py" -o -name "*.sh" 2>/dev/null | wc -l)
    check "$script_count policy script(s) available"
else
    warn "hooks/scripts directory missing"
fi

echo ""
section "Summary"
echo "Run this script periodically to check project health."
echo "Fix warnings by following the suggested commands."
