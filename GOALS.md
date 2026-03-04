# Goals & Vision

## The Problem

SaaS developers face bugs that only show up in production:
- Frontend calls API endpoints that don't exist (404s in production)
- Backend routes lack auth guards (data breaches)
- Tenant queries aren't scoped (cross-tenant data leaks)
- Webhook handlers don't verify signatures (security holes)
- Payment flows swallow errors (revenue loss)

Existing tools either cost $12+/seat/month (CodeRabbit, SonarQube), require internet/AI tokens, or only catch issues at PR time — too late.

## The Solution

**saascode-kit: 4 commands at 100% quality. Free. Offline. Deterministic.**

### 1. Endpoint Parity Checker (HERO — Zero Competition)
`saascode check` — The only tool in the world that automatically finds mismatches between frontend API calls and backend route definitions. Supports 14 frameworks. Uses AST analysis for TypeScript, regex for other languages.

### 2. Deterministic Code Review (Free CodeRabbit)
`saascode review --saas` — AST-based review across 5 languages finding missing auth guards, unscoped queries, hardcoded secrets, and SaaS-specific anti-patterns. No AI, no tokens, no internet.

### 3. Smart Recommendations
`saascode recommend` — Project health score 0-100 across tool coverage, security posture, code quality, CI/CD, and SaaS maturity. Points to specific commands for remediation.

### 4. Tool Orchestration
`saascode add <tool>` — One command configures ESLint, Prettier, Husky, or Semgrep for your exact stack. Framework-aware (e.g., Ruff for Python, golangci for Go).

### 5. Interactive Setup
`saascode init` — 60-second wizard that auto-detects your stack and generates a manifest.

## What Makes Us Unique

No competitor has ALL of these:
- **Endpoint parity checking** — zero competition anywhere
- **Free, offline, deterministic AST review** with SaaS-specific checks
- **Manifest-driven tool orchestration** — one YAML configures everything
- **Multi-language support** (8 languages) with framework-aware analysis
- **No AI, no tokens, no internet required**

## Positioning

- vs **CodeRabbit** ($12/seat/mo) — We're free, offline, deterministic, and catch issues before commit
- vs **SonarQube** — We're zero-config, SaaS-focused, and include endpoint parity
- vs **Husky** — We wrap Husky and add parity checking + SaaS rules on top
- vs **Semgrep** — We include curated SaaS rules and a manifest-driven orchestrator
