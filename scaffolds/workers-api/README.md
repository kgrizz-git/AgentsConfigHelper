# Cloudflare Workers API Scaffold

Minimal Cloudflare Workers API template with TypeScript and best practices.

## What's Included

- **wrangler.toml** - Cloudflare Workers configuration
- **TypeScript config** - Strict type checking
- **Basic worker** - Example API handler
- **Tests** - Example test setup
- **CI example** - GitHub Actions deployment workflow

## Usage

Copy these files to your project root:

```bash
cp -r scaffolds/workers-api/* .
```

Then customize:

1. Edit `wrangler.toml` (worker name, routes, variables)
2. Adjust `src/` for your API logic
3. Update CI workflow if needed
4. Remove this scaffold directory

## Prerequisites

- Node.js 18+
- Wrangler CLI: `npm install -g wrangler`

## Quick Start

```bash
# Install dependencies
npm install

# Run locally
wrangler dev

# Deploy to Cloudflare
wrangler deploy

# Run tests
npm test

# Type check
npm run type-check
```

## Files to Customize

- `wrangler.toml` - Worker configuration, environment variables
- `src/index.ts` - Your worker logic
- `src/` - Additional modules and handlers
- `.github/workflows/deploy.yml` - CI/CD configuration
- `README.md` - Project documentation

## Cleanup After Setup

- Remove unused dependencies from package.json
- Delete example code in `src/`
- Adjust wrangler configuration for your routes
- Remove this scaffold directory from git
