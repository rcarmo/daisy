# Default Ignore Patterns

Daisy is designed to watch **build trees** and **AI agents at work** in real-time. The default ignore patterns are carefully chosen to exclude directories and files that would otherwise create excessive noise, slow down scanning, or provide little value in understanding disk usage patterns.

## Why These Defaults?

When watching a development workspace or monitoring an AI agent's activity, you typically care about:

- Source code and generated outputs
- Build artifacts that matter (final binaries, bundles)
- Documents and assets being created or modified

You typically **don't** care about:

- Massive dependency folders that rarely change
- Version control internals
- Cache directories that are transient
- Editor swap files

## Default Patterns

| Pattern           | Reason                                                    |
| ----------------- | --------------------------------------------------------- |
| `node_modules`    | NPM/Yarn dependencies - huge, rarely changes              |
| `.git`            | Git internals - not useful for disk visualization         |
| `.svn`            | Subversion internals                                      |
| `.DS_Store`       | macOS metadata files                                      |
| `.Trash`          | macOS trash folder                                        |
| `__pycache__`     | Python bytecode cache                                     |
| `.pytest_cache`   | Pytest cache directory                                    |
| `.mypy_cache`     | Mypy type checker cache                                   |
| `coverage`        | Test coverage reports                                     |
| `dist`            | Common build output folder                                |
| `.next`           | Next.js build cache                                       |
| `.turbo`          | Turborepo cache                                           |
| `*.swp`, `*.swo`  | Vim swap files                                            |

## Disabling Ignore Patterns

If you need to see **everything**, including ignored directories, use the `--no-ignore` flag:

```bash
# Bun version
daisy ~/project --no-ignore

# Swift version
daisy ~/project --no-ignore
```

This is useful when:

- Debugging why a directory is using unexpected space
- Auditing `node_modules` or other dependency folders
- Getting a complete picture of all disk usage

## Adding Custom Ignore Patterns (Bun only)

The Bun version supports adding additional ignore patterns via the `-i` flag:

```bash
# Ignore additional patterns
daisy ~/project -i "*.log" -i "tmp"

# Combine with no-ignore to start fresh
daisy ~/project --no-ignore -i "secret_folder"
```

## Implementation

The ignore patterns are defined in:

- **Bun**: [src/utils.ts](../src/utils.ts) - `DEFAULT_IGNORE` array
- **Swift**: [swift/Sources/DirectoryScanner.swift](../swift/Sources/DirectoryScanner.swift) - `ignoredNames` and `ignoredSuffixes`

Both implementations use the same patterns for consistency.
