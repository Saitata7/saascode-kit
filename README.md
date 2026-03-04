<p align="center">
  <h1 align="center">saascode-kit</h1>
  <p align="center">SaaS development guardrails in one command. Free. Offline. Works on private repos.</p>
</p>

<p align="center">
  <a href="https://github.com/Saitata7/saascode-kit/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Saitata7/saascode-kit?style=flat-square" alt="License"></a>
  <a href="https://github.com/Saitata7/saascode-kit/stargazers"><img src="https://img.shields.io/github/stars/Saitata7/saascode-kit?style=flat-square" alt="Stars"></a>
  <a href="https://www.npmjs.com/package/saascode-kit"><img src="https://img.shields.io/npm/v/saascode-kit?style=flat-square" alt="npm"></a>
</p>

## Quick Start

```bash
npx saascode init              # Set up your SaaS project (60 seconds)
npx saascode check             # Find API route mismatches (ZERO competition)
npx saascode review --saas     # SaaS-specific code review (free CodeRabbit)
npx saascode recommend         # Project health score (0-100)
npx saascode add eslint        # Configure tools for your stack
```

## What It Does

### Endpoint Parity Checker (`saascode check`)

The **only tool that finds mismatches between frontend API calls and backend routes** before they ship. Supports 14 frameworks: NestJS, Express, Next.js, Django, Flask, FastAPI, Rails, Spring, Laravel, Go, and more.

```
  SAASCODE ENDPOINT CHECK
  ────────────────────────
  Stack: nestjs / nextjs
  Backend: apps/api/src (42 routes)
  Frontend: apps/portal/src (38 API calls)

  ✗ MISSING BACKEND ROUTE
    POST /api/users/profile
    Called in: src/components/Profile.tsx:47

  ✗ METHOD MISMATCH
    /api/orders  frontend=GET  backend=POST

  ────────────────────────
  Matched: 34 ✓  Missing: 2 ✗  Mismatch: 1 ✗  Orphaned: 2 ⚠
```

### AST Code Review (`saascode review`)

Free, offline, deterministic code review across 5 languages. No AI, no tokens, no internet.

- Missing auth guards on API routes
- Unscoped tenant queries (data leaks)
- Hardcoded secrets and API keys
- Empty catch blocks on payment flows
- SQL injection patterns
- Webhook handlers without signature verification

### Project Health Score (`saascode recommend`)

0-100 health score across 5 categories: tool coverage, security posture, code quality, CI/CD, SaaS maturity.

### Tool Orchestrator (`saascode add`)

One command configures ESLint, Prettier, Husky, or Semgrep for your exact stack.

```bash
npx saascode add eslint     # Framework-aware ESLint (or Ruff for Python, golangci for Go)
npx saascode add prettier   # Prettier with framework plugins
npx saascode add husky      # Husky + lint-staged + parity check on push
npx saascode add semgrep    # SaaS security rules (auth, tenant isolation, input validation)
npx saascode add all        # All of the above
```

## Supported Stacks

| Language | Frameworks | Review | Parity |
|----------|-----------|--------|--------|
| TypeScript/JS | NestJS, Express, Fastify, Hono, Next.js, Remix | AST (ts-morph) | AST |
| Python | Django, Flask, FastAPI | AST (stdlib) | Regex |
| Go | Gin, Chi, Mux, Echo, Fiber | Regex | Regex |
| Java | Spring Boot | Regex | Regex |
| Ruby | Rails | Regex | Regex |
| PHP | Laravel | Regex | Regex |

## Output Formats

- **Terminal** — Beautiful chalk output (default)
- **JSON** — `--json` flag for programmatic consumption
- **SARIF** — `--sarif` flag for GitHub Code Scanning integration

## How It Works

1. **Manifest-driven** — One `manifest.yaml` configures everything. Auto-detects if no manifest exists.
2. **AST-level accuracy** — Uses ts-morph for TypeScript/JS, Python stdlib ast, regex patterns for other languages.
3. **Zero dependencies at runtime** — Shell scripts need nothing installed. TypeScript CLI needs Node.js.
4. **Offline-first** — No internet, no API keys, no AI tokens. Everything runs locally.

## Install

```bash
# Run directly (recommended)
npx saascode check

# Or install globally
npm install -g saascode-kit

# Standalone parity checker
npx saascode-check ./path/to/project
```

## License

MIT
