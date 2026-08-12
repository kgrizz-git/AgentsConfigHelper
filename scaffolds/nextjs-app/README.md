# Next.js Application Scaffold

Modern Next.js web application template with TypeScript and best practices.

## What's Included

- **package.json** - Dependencies and scripts
- **TypeScript config** - Strict type checking
- **ESLint/Prettier** - Code quality and formatting
- **Basic structure** - App router with example pages
- **CI example** - GitHub Actions workflow

## Usage

Copy these files to your project root:
```bash
cp -r scaffolds/nextjs-app/* .
```

Then customize:
1. Edit `package.json` (project name, dependencies)
2. Adjust `app/` structure for your needs
3. Update CI workflow if needed
4. Remove this scaffold directory

## Quick Start

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Run tests
npm test

# Build for production
npm run build

# Lint code
npm run lint

# Format code
npm run format
```

## Files to Customize

- `package.json` - Project metadata, dependencies, scripts
- `app/` - Your application pages and components
- `components/` - Reusable components
- `.github/workflows/nextjs-ci.yml` - CI configuration
- `README.md` - Project documentation

## Cleanup After Setup

- Remove unused dependencies from package.json
- Delete example pages and components
- Adjust tool configurations to your preferences
- Remove this scaffold directory from git
