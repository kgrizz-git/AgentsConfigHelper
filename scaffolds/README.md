# Project Type Scaffolds

Last reviewed: 2026-07-27

Minimal starter configurations for common project types. These are **optional starting points** - use only what matches your project.

## Philosophy

- **Minimal but complete**: Enough to run, test, and extend
- **Opt-in**: Copy only what you need
- **Template-friendly**: Easy to customize for your specific requirements
- **Best practices**: Include formatting, linting, and testing from day one

## Available Scaffolds

### Python Projects
- `python-lib/` - Python library template
- `python-app/` - Python application/service template
- `python-cli/` - Python CLI tool template

### Web Projects
- `nextjs-app/` - Next.js web application
- `react-app/` - React SPA with Vite
- `node-api/` - Node.js API service

### Data Science
- `python-ml/` - Python ML/modeling project
- `jupyter-research/` - Jupyter-based research project

### Cloudflare Workers
- `workers-api/` - Cloudflare Workers API
- `workers-cron/` - Cloudflare Workers scheduled tasks

## Usage

1. Choose a scaffold that matches your project type
2. Copy relevant files to your project root
3. Customize for your specific needs
4. Remove template-specific comments
5. Update documentation to reflect your choices

## Cleanup

After copying a scaffold:
- Remove unrelated scaffolds (don't commit them)
- Update `.gitignore` if needed
- Adjust tool versions in configuration files
- Remove example/test code you don't need

## Customization

Each scaffold includes:
- Configuration files (pyproject.toml, package.json, etc.)
- Basic directory structure
- Essential tooling configuration
- Example test structure
- Documentation pointers

Customize by:
- Adding your project-specific dependencies
- Adjusting tool configurations
- Setting up your preferred CI/CD
- Adding project-specific documentation
