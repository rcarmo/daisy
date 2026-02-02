# Copilot instructions for Daisy

This is a Bun CLI application that provides live disk usage visualization via a sunburst diagram.

## Mandatory: use the Makefile

Use `make` targets for build/lint/test/format/dev flows whenever available.
If you need a new workflow step, add a Make target rather than running ad-hoc commands.

## Common workflows (expected Make targets)

- `make help` — list targets
- `make install` / `make install-dev` — install dependencies
- `make lint` / `make format` — static checks / formatting
- `make test` — run tests
- `make coverage` — run tests with coverage
- `make check` — run the project's standard validation pipeline
- `make clean` — remove local build/test artifacts
- `make dev` — run in development mode

## CI/CD convention

CI should call `make check` (or `make lint` + `make test` when `check` doesn't exist).
Keep CI logic minimal; prefer Make targets for consistency.

## Technology Stack

- **Runtime**: Bun (TypeScript)
- **Linter/Formatter**: Biome
- **Dependencies**: Zero runtime dependencies (Bun built-ins only)
- **Frontend**: Vanilla JS + custom SVG rendering

## Architecture

- `src/cli.ts` - CLI entry point, argument parsing
- `src/server.ts` - Bun HTTP server + SSE streaming
- `src/scanner.ts` - Recursive directory traversal
- `src/watcher.ts` - File system watching
- `src/types.ts` - TypeScript interfaces
- `public/` - Static web assets (HTML, JS, CSS)

## Code Style

- Use TypeScript strict mode
- Prefer async/await over callbacks
- Use Bun built-in APIs where possible
- Keep files focused and single-purpose
- Document public functions with JSDoc
