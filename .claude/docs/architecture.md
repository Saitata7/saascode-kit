# Architecture

## v2 Overview

```
npx saascode <command>
    │
    ▼
src/cli/index.ts (Commander.js)
    │
    ├─→ init      → src/commands/init.ts (@inquirer/prompts)
    │                  └─→ writes manifest.yaml
    │
    ├─→ check     → src/commands/check.ts
    │                  └─→ src/analyzers/endpoint-checker/
    │                        ├─→ frontend-scanner.ts (ts-morph: fetch, axios, SWR)
    │                        ├─→ backend-scanner.ts (dispatches to framework scanners)
    │                        │     └─→ frameworks/ (14 scanners)
    │                        ├─→ normalizer.ts (path normalization)
    │                        ├─→ comparator.ts (matching algorithm)
    │                        └─→ reporter.ts (chalk output)
    │
    ├─→ review    → src/commands/review.ts
    │                  └─→ shells out to scripts/ast-review.sh
    │                        ├─→ ast-review.ts (TypeScript — ts-morph)
    │                        ├─→ ast-review-python.py (Python — stdlib ast)
    │                        ├─→ ast-review-go.sh (Go — regex)
    │                        ├─→ ast-review-java.sh (Java — regex)
    │                        └─→ ast-review-ruby.sh (Ruby — regex)
    │
    ├─→ add       → src/commands/add.ts
    │                  └─→ src/generators/ (eslint, prettier, husky, semgrep)
    │
    └─→ recommend → src/commands/recommend.ts
                       └─→ shells out to scripts/recommend.sh
```

## Endpoint Parity Checker (Hero Feature)

Two-tier scanning:
- **Tier 1 (TypeScript):** AST-level via ts-morph for JS/TS projects
- **Tier 2 (Shell):** Regex patterns for non-JS projects (endpoint-parity.sh)

### Frontend Scanner
Detects API calls via ts-morph AST walking:
- `fetch('/api/...')` — string + template literal + method from options
- `axios.get('/api/...')` — method calls + config objects
- `useSWR('/api/...')` — first arg is URL, always GET

### Backend Scanners (14 frameworks)
| Framework | Strategy |
|-----------|----------|
| Next.js App Router | File-system: exported GET/POST/PUT/PATCH/DELETE from route.ts |
| Next.js Pages Router | File-system: pages/api/ with req.method checks |
| Express/Fastify/Hono | AST: app.get(), router.post() calls |
| NestJS | AST: @Controller('prefix') + @Get('path') decorators |
| Remix | File-system: loader (GET) / action (POST) exports |
| Django | Regex: urlpatterns, path(), api_view |
| Flask | Regex: @app.route(), Blueprint routes |
| FastAPI | Regex: @app.get(), APIRouter prefix |
| Rails | Regex: routes.rb, resources, get/post/etc |
| Spring | Regex: @GetMapping, @RequestMapping |
| Laravel | Regex: Route::get(), Route groups, resources |
| Go (Gin/Chi/Mux) | Regex: .GET(), .HandleFunc() |

### Path Normalization
All param styles become `:param` for comparison:
- `:id` (Express) → `:param`
- `[id]` (Next.js) → `:param`
- `{id}` (Spring/Go) → `:param`
- `<int:id>` (Django/Flask) → `:param`
- `$id` (Remix) → `:param`

### Matching Algorithm
1. Normalize all paths, build lookup maps: `METHOD|normalizedPath`
2. Exact match → matched pair
3. Path-only match → method mismatch
4. Unmatched frontend → missing backend (CRITICAL — will 404!)
5. Unmatched backend → orphaned (WARNING — may be intentional)

## Review Engine Pipeline

```
saascode review [--saas] [--json] [--sarif] [--ci]
    │
    └─→ ast-review.sh (dispatcher by language)
          ├─→ ast-review.ts     (TypeScript/JS — ts-morph)
          ├─→ ast-review-python.py (Python — stdlib ast)
          ├─→ ast-review-go.sh    (Go — regex)
          ├─→ ast-review-java.sh  (Java — regex)
          └─→ ast-review-ruby.sh  (Ruby — regex)
```

## Recommend Scoring (0-100)

| Category | Weight | Checks |
|----------|--------|--------|
| Tool Coverage | 20 pts | ESLint, Prettier, TypeScript strict, Husky, Semgrep |
| Security Posture | 30 pts | Auth guards, No secrets, Tenant isolation, Rate limiting, Webhooks |
| Code Quality | 20 pts | No console.logs, No empty catches, No eval, No raw SQL |
| CI/CD Setup | 15 pts | CI pipeline, Pre-commit hooks, Tests |
| SaaS Maturity | 15 pts | Payment handling, Multi-tenancy, API docs |

## Shared Utilities

- `src/utils/manifest.ts` — YAML read/write (port from lib.sh awk parser)
- `src/utils/detect.ts` — Language/framework/ORM auto-detection
- `src/utils/output.ts` — chalk formatting, tables, findings
- `src/utils/sarif.ts` — SARIF 2.1.0 output for GitHub Code Scanning
- `src/utils/paths.ts` — Project root finding, path resolution
- `src/utils/logger.ts` — JSONL logging
