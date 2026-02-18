# Coding Conventions

## Shell Scripts

- **Shebang**: `#!/usr/bin/env bash` for scripts, `#!/bin/sh` for hooks
- **Variables**: UPPER_SNAKE for constants, lower_snake for locals
- **Quoting**: Always double-quote variables: `"$VAR"`, `"$1"`
- **Exit codes**: 0 = success, 1 = error, 2 = critical findings (review scripts)
- **Colors**: Use variables from lib.sh or define locally: `RED='\033[0;31m'`, `NC='\033[0m'`
- **Functions**: `snake_case`, prefix with `cmd_` for CLI commands in saascode.sh

## BSD Compatibility (Critical)

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

## Skill Files (.md)

```markdown
# Skill: [Name]

> Trigger: /command [args]
> Purpose: One-line description

## Step 1: [Action]
...

## Output Rules
- Rule 1
- Rule 2
```

## Cursor Rule Files (.mdc)

```markdown
---
description: When and why this rule activates
globs:
  - "**/path/**/*.ext"
---

# Rule content in markdown
- CORRECT: `code example`
- WRONG: `code example`
```

## Semgrep Rules (.yaml)

```yaml
rules:
  - id: descriptive-rule-id
    message: "What's wrong and how to fix it"
    severity: ERROR | WARNING | INFO
    languages: [typescript]
    pattern: |
      ...semgrep pattern...
```

## Adding a New CLI Command

1. Add the command case to `scripts/saascode.sh` in the `case` block
2. If complex, create a dedicated script in `scripts/`
3. Source `lib.sh` and call `load_manifest_vars`
4. Add to `show_help()` in `bin/cli.sh`
5. Add to `cmd_update()` in `saascode.sh` if the script should sync

## Adding Language Support

1. Add detection logic to `lib.sh` detection helpers
2. Add file extensions to `get_source_extensions`
3. Add debug/test/SQL patterns to respective functions
4. Update `check-file.sh` for language-specific checks
5. Optionally create `ast-review-<lang>.sh` or `.py`
6. Update `ast-review.sh` dispatcher
