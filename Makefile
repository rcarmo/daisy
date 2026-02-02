SHELL := /bin/sh

.DEFAULT_GOAL := help

# Daisy - Live Disk Usage Sunburst Visualizer

.PHONY: help
help: ## Show targets
	@grep -E '^[a-zA-Z0-9_.-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

# =============================================================================
# Dependency install
# =============================================================================

.PHONY: install
install: ## Install project dependencies
	bun install

.PHONY: install-dev
install-dev: install ## Install dev dependencies (same as install for Bun)

# =============================================================================
# Development
# =============================================================================

.PHONY: dev
dev: ## Run in development mode (watches current directory)
	bun run src/cli.ts . --open

.PHONY: serve
serve: ## Run server on parent directory
	bun run src/cli.ts .. --open

.PHONY: run
run: ## Run the CLI (use ARGS to pass arguments, e.g., make run ARGS="~/Documents")
	bun run src/cli.ts $(ARGS)

# =============================================================================
# Build
# =============================================================================

.PHONY: build
build: ## Build static binary for current platform
	@mkdir -p dist
	bun build src/cli.ts --compile --outfile dist/daisy
	@echo "Built: dist/daisy"
	@ls -lh dist/daisy

.PHONY: build-all
build-all: ## Build static binaries for all platforms
	@mkdir -p dist
	bun build src/cli.ts --compile --target=bun-linux-x64 --outfile dist/daisy-linux-x64
	bun build src/cli.ts --compile --target=bun-linux-arm64 --outfile dist/daisy-linux-arm64
	bun build src/cli.ts --compile --target=bun-darwin-x64 --outfile dist/daisy-darwin-x64
	bun build src/cli.ts --compile --target=bun-darwin-arm64 --outfile dist/daisy-darwin-arm64
	bun build src/cli.ts --compile --target=bun-windows-x64 --outfile dist/daisy-windows-x64.exe
	@echo "Built all platforms:"
	@ls -lh dist/

# =============================================================================
# Quality
# =============================================================================

.PHONY: lint
lint: ## Run linters
	bun x biome check src/

.PHONY: format
format: ## Format code
	bun x biome format --write src/

.PHONY: typecheck
typecheck: ## Run TypeScript type checking
	bun x tsc --noEmit

.PHONY: test
test: ## Run tests
	bun test

.PHONY: coverage
coverage: ## Run tests with coverage
	bun test --coverage

.PHONY: check
check: lint typecheck test ## Run standard validation pipeline

# =============================================================================
# Cleanup
# =============================================================================

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf node_modules .turbo coverage dist

clean-dist: ## Remove only dist folder
	rm -rf dist
