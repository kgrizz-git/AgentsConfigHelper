#!/usr/bin/env bash
# Lightweight project setup script for template-repo-v1
# This script helps initialize common project configurations without being opinionated.
# Run: bash scripts/setup.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
section() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Main setup steps
main() {
    echo "Template Repo Setup"
    echo "===================="
    echo ""

    # 1. Environment file setup
    info "Checking environment configuration..."
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            success "Created .env from .env.example"
            warn "Please edit .env with your actual values (never commit .env)"
        else
            warn "No .env.example found, skipping .env creation"
        fi
    else
        info ".env already exists, skipping"
    fi

    # 2. Pre-commit hooks setup
    info "Setting up pre-commit hooks..."
    if check_command pre-commit; then
        if [ -f hooks/.pre-commit-config.yaml ] && [ ! -f .pre-commit-config.yaml ]; then
            cp hooks/.pre-commit-config.yaml .pre-commit-config.yaml
            success "Copied pre-commit config to project root"
        fi

        pre-commit install
        success "Pre-commit hooks installed"
    else
        warn "pre-commit not found. Install with: pip install pre-commit"
    fi

    # 3. Git remote validation
    info "Checking git remote configuration..."
    if git rev-parse --git-dir > /dev/null 2>&1; then
        current_remote=$(git remote get-url origin 2>/dev/null || echo "")
        template_keywords="template-repo|template-seed|project-seed"

        if echo "$current_remote" | grep -qiE "$template_keywords"; then
            warn "Current remote appears to be the template repo: $current_remote"
            info "Before pushing, update to your project remote:"
            echo "  git remote set-url origin <your-project-remote-url>"
            echo "  Or: git remote rename origin template && git remote add origin <your-project-remote-url>"
        else
            success "Git remote configuration looks good"
        fi
    else
        warn "Not a git repository, skipping remote check"
    fi

    # 4. Optional: Python environment setup
    info "Python environment setup (optional)..."
    if check_command python3 || check_command python; then
        py_cmd=$(check_command python3 && echo "python3" || echo "python")

        if [ ! -f .python-version ] && [ ! -f pyproject.toml ] && [ ! -f requirements.txt ]; then
            read -r -p "Create .python-version file? (y/n): " create_pyversion
            if [ "$create_pyversion" = "y" ]; then
                $py_cmd --version | awk '{print $2}' > .python-version
                success "Created .python-version with current Python version"
            fi
        else
            info "Python project files detected, skipping .python-version creation"
        fi
    else
        info "Python not found, skipping Python setup"
    fi

    # 5. Optional: Create basic directories
    info "Creating standard directories..."
    mkdir -p .context backups logs temp
    success "Created .context, backups, logs, temp directories"

    # 6. Cleanup suggestions
    echo ""
    section "Cleanup Suggestions"
    info "Based on your project type, you may want to remove irrelevant content:"
    echo ""
    info "Medical/PII data projects:"
    echo "  - Keep: inventory/medical-data-security.md, hooks/scripts/check_sensitive_data.py"
    echo "  - Remove: irrelevant domain-specific inventories"
    echo ""
    info "Web/frontend projects:"
    echo "  - Keep: inventory/frontend-design-ux.md, inventory/python.md (if using Python)"
    echo "  - Remove: inventory/scientific-domain.md, inventory/financial-modeling.md"
    echo ""
    info "Data science/ML projects:"
    echo "  - Keep: inventory/rag.md, inventory/scientific-domain.md"
    echo "  - Remove: inventory/frontend-design-ux.md (if not building UI)"
    echo ""
    info "General software projects:"
    echo "  - Keep: inventory/tools-index.md, inventory/security-quality.md"
    echo "  - Remove: domain-specific inventories not relevant to your stack"
    echo ""
    info "Editor-specific rules:"
    echo "  - Keep only the editor rules you actually use"
    echo "  - Remove: .cursor/, .windsurf/, .claude/ directories you don't use"
    echo ""
    warn "Review your project type after running bootstrap-project.md"
    warn "Then remove clearly irrelevant inventory files and editor configs"

    echo ""
    success "Setup complete!"
    echo ""
    info "Next steps:"
    echo "  1. Edit .env with your actual values"
    echo "  2. Update git remote if needed"
    echo "  3. Run: prompts/bootstrap-project.md with your AI agent"
    echo "  4. Review and remove irrelevant content based on project type"
    echo "  5. Run: pre-commit run --all-files (initial check)"
}

# Run main function
main "$@"
