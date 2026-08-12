# Python Application Scaffold

Minimal Python application/service template with best practices baked in.

## What's Included

- **pyproject.toml** - Modern Python project configuration
- **Basic structure** - `src/` layout with tests
- **Tooling** - Ruff (lint/format), pytest (testing), mypy (type checking)
- **CI example** - GitHub Actions workflow
- **Documentation** - Basic README structure

## Usage

Copy these files to your project root:
```bash
cp -r scaffolds/python-app/* .
```

Then customize:
1. Edit `pyproject.toml` (project name, dependencies, versions)
2. Adjust `src/` structure for your needs
3. Update CI workflow if needed
4. Remove this scaffold directory

## Quick Start

```bash
# Install dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Format code
ruff format .

# Lint code
ruff check .

# Type check
mypy src/
```

## Files to Customize

- `pyproject.toml` - Project metadata, dependencies, tool config
- `src/` - Your application code
- `tests/` - Your tests
- `.github/workflows/python-ci.yml` - CI configuration
- `README.md` - Project documentation

## Cleanup After Setup

- Remove unused dependencies from pyproject.toml
- Delete example code in `src/` and `tests/`
- Adjust tool configurations to your preferences
- Remove this scaffold directory from git
