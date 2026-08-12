# Go Service Scaffold

Minimal Go service/library template with best practices.

## What's Included

- **go.mod** - Go module configuration
- **Basic structure** - Standard Go project layout
- **Tooling** - gofmt, go vet, go test
- **CI example** - GitHub Actions workflow
- **Makefile** - Common commands

## Usage

Copy these files to your project root:

```bash
cp -r scaffolds/go-service/* .
```

Then customize:

1. Edit `go.mod` (module name, Go version)
2. Adjust `cmd/` and `pkg/` structure for your needs
3. Update CI workflow if needed
4. Remove this scaffold directory

## Quick Start

```bash
# Download dependencies
go mod download

# Run tests
go test ./...

# Build
go build ./cmd/your-service

# Run
./your-service

# Format code
gofmt -s -w .

# Vet code
go vet ./...
```

## Files to Customize

- `go.mod` - Module name, dependencies, Go version
- `cmd/` - Your application entry points
- `pkg/` - Your library code
- `Makefile` - Build and test commands
- `.github/workflows/go-ci.yml` - CI configuration
- `README.md` - Project documentation

## Cleanup After Setup

- Remove unused dependencies from go.mod
- Delete example code in `cmd/` and `pkg/`
- Adjust Makefile targets to your needs
- Remove this scaffold directory from git
