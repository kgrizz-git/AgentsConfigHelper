# Rust CLI Scaffold

Minimal Rust CLI tool template with best practices.

## What's Included

- **Cargo.toml** - Rust project configuration
- **Basic structure** - Standard Rust project layout
- **Tooling** - clippy, rustfmt, cargo test
- **CI example** - GitHub Actions workflow

## Usage

Copy these files to your project root:
```bash
cp -r scaffolds/rust-cli/* .
```

Then customize:
1. Edit `Cargo.toml` (project name, dependencies)
2. Adjust `src/` structure for your needs
3. Update CI workflow if needed
4. Remove this scaffold directory

## Quick Start

```bash
# Build
cargo build

# Run
cargo run

# Test
cargo test

# Format code
cargo fmt

# Lint code
cargo clippy

# Build release
cargo build --release
```

## Files to Customize

- `Cargo.toml` - Project metadata, dependencies
- `src/main.rs` - Your CLI logic
- `src/` - Additional modules
- `.github/workflows/rust-ci.yml` - CI configuration
- `README.md` - Project documentation

## Cleanup After Setup

- Remove unused dependencies from Cargo.toml
- Delete example code in `src/`
- Adjust tool configurations to your preferences
- Remove this scaffold directory from git
