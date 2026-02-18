# Architecture

## How It Works

```
manifest.yaml
    │
    ▼
setup.sh (reads manifest via lib.sh)
    │
    ├─→ templates/*.template  ──→  CLAUDE.md, .cursorrules, .windsurfrules
    │     (replace_placeholders + process_conditionals)
    │
    ├─→ skills/*.md           ──→  .claude/skills/*.md
    ├─→ cursor-rules/*.mdc    ──→  .cursor/rules/*.mdc
    ├─→ rules/*.yaml          ──→  .saascode/rules/*.yaml
    ├─→ hooks/*               ──→  .git/hooks/pre-commit, pre-push
    ├─→ scripts/*.sh          ──→  .saascode/scripts/*.sh
    ├─→ checklists/*.md       ──→  .saascode/checklists/*.md
    ├─→ ci/*.yml              ──→  .github/workflows/saascode.yml
    └─→ .claude/settings.json ──→  PostToolUse hooks (check-file, intent-log)
```

## Template Engine

Two-phase processing in `lib.sh`:

1. **`replace_placeholders`** — sed-based `{{key.subkey}}` substitution
2. **`process_conditionals`** — awk-based block processing:
   - `{{#if field}}...{{/if}}` — include block if field is truthy
   - `{{#if_eq field "value"}}...{{/if_eq}}` — include block if field equals value
   - `{{#each array}}...{{/each}}` — loop over array items

Both are BSD-compatible (macOS + Linux).

## 7-Layer Prevention Stack

```
Layer 1: IDE Context         → CLAUDE.md, .cursorrules (while AI writes)
Layer 2: PostToolUse Hooks   → check-file.sh < 1s (after each AI edit)
Layer 3: Semgrep             → Real-time in IDE (static analysis)
Layer 4: Pre-commit Hook     → Secrets, .env, merge markers (< 3s)
Layer 5: On-demand CLI       → saascode review / sweep (before push)
Layer 6: Pre-push Hook       → TypeScript, build, security audit
Layer 7: GitHub Actions CI   → Build, test, parity, security (on PR)
```

## Review Engine Pipeline

```
saascode review
    │
    ├─→ ast-review.sh (dispatcher)
    │     ├─→ ast-review.ts     (TypeScript/JS — ts-morph)
    │     ├─→ ast-review-python.py (Python — stdlib ast)
    │     └─→ ast-review-java.sh   (Java — bash+grep+awk)
    │
    └─→ --ai flag
          └─→ ai-review.sh (7 LLM providers, auto-detect from .env)
```

## Script Dependencies

All scripts in `scripts/` follow this pattern:
```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"       # Always source lib.sh
load_manifest_vars                 # Load manifest into shell vars
```

Exception: `check-file.sh` has a 60-second manifest cache for performance.

## Multi-Language Detection

`lib.sh` provides detection helpers that adapt to `stackLanguage`:
- `detect_pkg_manager` — npm/yarn/pnpm/pip/poetry/bundler/cargo/go/maven/gradle/composer
- `detect_build_cmd` — per-language build commands
- `detect_test_cmd` — per-language test commands
- `get_source_extensions` — `.ts,.tsx` / `.py` / `.go` / `.java` / etc.
- `get_debug_patterns` — console.log / print() / fmt.Println / etc.
