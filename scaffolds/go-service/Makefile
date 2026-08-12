.PHONY: build test fmt vet clean run

# Build the application
build:
	go build -o bin/your-service ./cmd/your-service

# Run tests
test:
	go test -v ./...

# Format code
fmt:
	gofmt -s -w .

# Vet code
vet:
	go vet ./...

# Clean build artifacts
clean:
	rm -rf bin/

# Run the application
run: build
	./bin/your-service

# All checks
check: fmt vet test
