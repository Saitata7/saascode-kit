# Coding Conventions

## TypeScript (src/)

- **ESM only** — `"type": "module"`, imports use `.js` extensions
- **Strict mode** — `"strict": true` in tsconfig.json
- **No default exports** — use named exports everywhere
- **Types** — defined in `src/types/`, imported as `type` imports
- **Error handling** — throw typed errors, catch with `(error as Error).message`

## Shell Scripts (scripts/)

- **Shebang**: `#!/usr/bin/env bash` for scripts, `#!/bin/sh` for hooks
- **Variables**: UPPER_SNAKE for constants, lower_snake for locals
- **Quoting**: Always double-quote variables: `"$VAR"`, `"$1"`
- **Exit codes**: 0 = success, 1 = error/findings, 2 = critical
- **Colors**: Use variables from lib.sh: `$RED`, `$GREEN`, `$YELLOW`, `$CYAN`, `$BOLD`, `$NC`
- **Functions**: `snake_case`

## BSD Compatibility (Critical for shell scripts)

```bash
# CORRECT — works on macOS + Linux
sed -i.bak 's/old/new/' file && rm file.bak

# WRONG — GNU-only, breaks on macOS
sed -i 's/old/new/' file

# CORRECT — POSIX awk
awk '{print $1}' file

# WRONG — gawk-only features
awk -i inplace '{print $1}' file
```

## Semgrep Rules (templates/semgrep/*.yaml)

```yaml
rules:
  - id: descriptive-rule-id
    message: "What's wrong and how to fix it"
    severity: ERROR | WARNING | INFO
    languages: [typescript]
    pattern: |
      ...semgrep pattern...
```

## Adding a Framework Scanner

1. Create `src/analyzers/endpoint-checker/frameworks/<name>.ts`
2. Export `async function scan<Name>(backendPath, root, apiPrefix?): Promise<Endpoint[]>`
3. Register in `src/analyzers/endpoint-checker/backend-scanner.ts` SCANNERS map
4. Add to auto-detection in `detectBackendType()` if needed
5. Add unit test in `tests/unit/`

## Adding Language Support for Review

1. Create `scripts/ast-review-<lang>.sh` or `.py`
2. Update `scripts/ast-review.sh` dispatcher
3. Add detection logic in `src/utils/detect.ts`
4. Add source extensions to `getSourceExtensions()`
5. Add excluded dirs to `getExcludedDirs()`
