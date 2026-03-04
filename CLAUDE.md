# saascode-kit v2 — Project Context

> Development context for working ON the kit itself, not a user project.

## What This Is

saascode-kit is a SaaS development guardrails CLI with 5 pillars: `init`, `check`, `review`, `add`, `recommend`. It's a hybrid TypeScript + Shell project that provides deterministic, offline, free code analysis for SaaS projects.

**Hero feature:** Endpoint parity checker (`saascode check`) — the only tool that finds mismatches between frontend API calls and backend routes. Zero competition globally.

**Primary users:** Developers building SaaS applications. **No AI required.**

## Tech Stack

- **CLI:** TypeScript (Commander.js) — `src/cli/index.ts`
- **Parity Checker:** TypeScript (ts-morph) — `src/analyzers/endpoint-checker/`
- **AST Review:** TypeScript (ts-morph), Python (stdlib ast), Shell (bash+grep+awk)
- **Generators:** TypeScript — `src/generators/`
- **Recommend:** Shell — `scripts/recommend.sh`
- **Static Analysis:** Semgrep YAML rules — `templates/semgrep/`
- **Distribution:** npm (npx saascode)
- **Testing:** Vitest

## Project Structure

```
src/
  cli/
    index.ts                    # Commander.js entry (5 commands)
    check-standalone.ts         # Standalone parity checker entry
  commands/
    init.ts                     # Interactive wizard (@inquirer/prompts)
    check.ts                    # Parity checker command
    review.ts                   # Review command (wraps shell scripts)
    add.ts                      # Tool orchestrator
    recommend.ts                # Recommend command (wraps shell)
  analyzers/
    endpoint-checker/
      index.ts                  # Main orchestrator
      types.ts                  # Endpoint, ParityResult types
      frontend-scanner.ts       # Extract API calls (fetch, axios, SWR)
      backend-scanner.ts        # Dispatch to framework scanners
      comparator.ts             # Compare + find mismatches
      normalizer.ts             # Path normalization (:param, [id], {id})
      reporter.ts               # chalk output formatting
      frameworks/               # 12 framework scanners
  generators/
    eslint.ts                   # ESLint/Ruff/golangci config generation
    prettier.ts                 # Prettier config generation
    semgrep.ts                  # Semgrep SaaS rules
    husky.ts                    # Husky + lint-staged setup
  utils/
    manifest.ts                 # YAML read/write
    output.ts                   # chalk formatting, tables
    detect.ts                   # Auto-detect project structure
    logger.ts                   # JSONL logging
    sarif.ts                    # SARIF 2.1.0 output
    paths.ts                    # Cross-platform path utilities
  types/
    manifest.ts                 # Manifest YAML schema
    findings.ts                 # Finding/report types
scripts/
  ast-review.sh                 # Review dispatcher
  ast-review.ts                 # TypeScript reviewer (ts-morph)
  ast-review-python.py          # Python reviewer (ast)
  ast-review-go.sh              # Go reviewer
  ast-review-java.sh            # Java reviewer
  ast-review-ruby.sh            # Ruby reviewer
  recommend.sh                  # Health scoring script
  lib.sh                        # Shared shell library
  endpoint-parity.sh            # Shell-based parity fallback
  check-file.sh                 # Single-file validator
  review-formatter.sh           # SARIF/JSON formatting
templates/
  semgrep/                      # 10 Semgrep SaaS security rule sets
tests/
  unit/                         # Vitest unit tests
  projects/                     # 16 fixture projects
archive/v1/                     # Archived v1 features (skills, templates, etc.)
```

## Commands

| Command | Description |
|---------|-------------|
| `saascode init` | Interactive setup wizard |
| `saascode check` | Endpoint parity checker (hero) |
| `saascode review [--saas]` | Deterministic AST code review |
| `saascode add <tool>` | Configure eslint/prettier/husky/semgrep |
| `saascode recommend` | Project health score (0-100) |

## Development Commands

```bash
npm run build          # Compile TypeScript
npm run dev            # Run CLI in development mode
npm run typecheck      # Type check without emitting
npm test               # Run Vitest unit tests
npm run test:legacy    # Run legacy shell test suite
```

## Key Conventions

- **TypeScript source** lives in `src/`, compiled to `dist/`
- **Shell scripts** in `scripts/` remain for review system (already works across 5 languages)
- **Tests** use Vitest, fixture projects in `tests/projects/`
- **ESM-only** — `"type": "module"` in package.json
- **Node16 module resolution** — imports use `.js` extensions

## Golden Rules

| # | May do | Must NOT do |
|---|--------|-------------|
| 1 | Add framework scanners in `src/analyzers/endpoint-checker/frameworks/` | Break existing shell reviewers |
| 2 | Enhance TypeScript types and utilities | Add AI/LLM dependencies |
| 3 | Add Semgrep rules in `templates/semgrep/` | Use GNU-only sed/awk in shell scripts |
| 4 | Add unit tests in `tests/unit/` | Modify fixture projects without good reason |
| 5 | Enhance generators for new frameworks | Make recommend.sh slower than 5 seconds |

## Anti-Patterns

- Do NOT add AI/LLM dependencies — the tool must work offline with zero tokens
- Do NOT use CommonJS (`require()`) in TypeScript source — ESM only
- Do NOT break BSD compatibility in shell scripts
- Do NOT commit `docs/product/` — internal strategy docs (gitignored)
