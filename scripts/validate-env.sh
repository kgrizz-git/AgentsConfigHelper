#!/usr/bin/env bash
# Lightweight environment validation script
# Run: bash scripts/validate-env.sh
# Or use in CI to validate build environment

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FAIL_ON_ERROR=${FAIL_ON_ERROR:-0}  # Set to 1 to make errors fail the script

# Helper functions
check() { 
    if [ $? -eq 0 ]; then 
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else 
        echo -e "${RED}✗${NC} $1"
        if [ "$FAIL_ON_ERROR" = "1" ]; then
            exit 1
        fi
        return 1
    fi
}
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
section() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

error_count=0
increment_error() { ((error_count++)); }

echo "Environment Validation"
echo "===================="

# 1. Essential tools
section "Essential Tools"

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

if check_command git; then
    check "git available"
else
    warn "git not found"
    increment_error
fi

# 2. Project-specific tools (detected from project files)
section "Project Tools"

# Python
if [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f setup.py ]; then
    if check_command python3 || check_command python; then
        check "Python available"
    else
        warn "Python required but not found"
        increment_error
    fi
    
    if check_command pip || check_command pip3; then
        check "pip available"
    else
        warn "pip required but not found"
        increment_error
    fi
fi

# Node.js
if [ -f package.json ]; then
    if check_command node; then
        check "Node.js available"
    else
        warn "Node.js required but not found"
        increment_error
    fi
    
    if check_command npm || check_command yarn || check_command pnpm; then
        check "Package manager available"
    else
        warn "Package manager required but not found"
        increment_error
    fi
fi

# 3. Development tools
section "Development Tools"

if [ -f .pre-commit-config.yaml ]; then
    if check_command pre-commit; then
        check "pre-commit available"
    else
        warn "pre-commit configured but not installed"
        info "Install with: pip install pre-commit"
        increment_error
    fi
fi

if [ -f .markdownlint-cli2.yaml ] || grep -q "markdownlint" .pre-commit-config.yaml 2>/dev/null; then
    if check_command markdownlint || check_command markdownlint-cli2; then
        check "markdownlint available"
    else
        warn "markdownlint configured but not installed"
    fi
fi

# 4. Environment variables
section "Environment Variables"

if [ -f .env.example ]; then
    info "Checking .env.example for required variables..."
    
    # Extract variable names from .env.example (lines like VAR_NAME=value)
    required_vars=$(grep -E "^[A-Z_]+" .env.example | cut -d'=' -f1 | head -10)
    
    if [ -n "$required_vars" ]; then
        for var in $required_vars; do
            if [ -z "${!var+x}" ]; then
                warn "$var not set in environment"
            else
                check "$var is set"
            fi
        done
    fi
else
    info "No .env.example found, skipping variable checks"
fi

# 5. Git configuration
section "Git Configuration"

if git rev-parse --git-dir > /dev/null 2>&1; then
    if git config user.name > /dev/null 2>&1; then
        check "git user.name configured"
    else
        warn "git user.name not configured"
        info "Set with: git config --global user.name 'Your Name'"
    fi
    
    if git config user.email > /dev/null 2>&1; then
        check "git user.email configured"
    else
        warn "git user.email not configured"
        info "Set with: git config --global user.email 'you@example.com'"
    fi
else
    info "Not a git repository, skipping git config checks"
fi

# 6. File permissions
section "File Permissions"

if [ -f scripts/setup.sh ]; then
    if [ -x scripts/setup.sh ]; then
        check "scripts/setup.sh is executable"
    else
        warn "scripts/setup.sh not executable"
        info "Run: chmod +x scripts/setup.sh"
    fi
fi

if [ -f scripts/health-check.sh ]; then
    if [ -x scripts/health-check.sh ]; then
        check "scripts/health-check.sh is executable"
    else
        warn "scripts/health-check.sh not executable"
        info "Run: chmod +x scripts/health-check.sh"
    fi
fi

# 7. Summary
section "Summary"

if [ $error_count -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$error_count issue(s) found${NC}"
    if [ "$FAIL_ON_ERROR" = "1" ]; then
        exit 1
    else
        exit 0
    fi
fi
