<p align="center">
  <h1 align="center">SaasCode Kit</h1>
  <p align="center">Universal development kit for SaaS projects. One manifest, multiple outputs.</p>
</p>

<p align="center">
  <a href="https://github.com/Saitata7/saascode-kit/blob/main/LICENSE"><img src="https://img.shields.io/github/license/Saitata7/saascode-kit?style=flat-square" alt="License"></a>
  <a href="https://github.com/Saitata7/saascode-kit/stargazers"><img src="https://img.shields.io/github/stars/Saitata7/saascode-kit?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/Saitata7/saascode-kit/network/members"><img src="https://img.shields.io/github/forks/Saitata7/saascode-kit?style=flat-square" alt="Forks"></a>
  <a href="https://github.com/Saitata7/saascode-kit/issues"><img src="https://img.shields.io/github/issues/Saitata7/saascode-kit?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/Saitata7/saascode-kit/commits/main"><img src="https://img.shields.io/github/last-commit/Saitata7/saascode-kit?style=flat-square" alt="Last Commit"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#what-it-does">What It Does</a> &middot;
  <a href="#cli-commands">CLI Commands</a> &middot;
  <a href="#customization">Customization</a> &middot;
  <a href="#contributing">Contributing</a>
</p>

---

## Why This Kit Exists

AI coding tools (Claude Code, Cursor, Copilot) are powerful but blind — they don't know your auth pattern, tenant isolation rules, or which endpoints exist. You end up repeating yourself, fixing the same mistakes, and babysitting every prompt. This kit gives the AI your project's rules upfront so it gets things right the first time.

## The 5 Goals

| Goal | Without Kit | With Kit | How |
|------|:-----------:|:--------:|-----|
| **Time Saving** | ~10% | **55-65%** | Golden reference templates, `/recipe` prompts, `/build` skill builds full features end-to-end. No more writing boilerplate or explaining patterns every conversation. |
| **Single-Shot Prompts** | ~30% | **80-85%** | Tiered context (CLAUDE.md + project-map + golden-reference) means the AI knows your models, endpoints, components, and patterns. One prompt = working code. |
| **Token Saving** | 0% (baseline) | **85-90%** | Prompt caching on static CLAUDE.md (~60 lines), message classification (QUICK/MEDIUM/FULL) skips context loading for small fixes. Only loads what's needed. |
| **Replace CodeRabbit** | 0% | **80-88%** | AST-based review (`ast-review.ts`) parses every controller and service with ts-morph. Catches missing guards, tenant scoping gaps, empty catch blocks, hardcoded secrets — with confidence scores. |
| **Vibe Coding Power** | ~15% | **75-82%** | `/build` skill follows 6-phase workflow with inline validation. `/recipe` templates for common tasks. Endpoint parity enforcer catches frontend-backend mismatches before runtime. |

> **Without Kit** = raw AI tool with no project context, default prompts, manual review.
> **With Kit** = same AI tool with SaasCode Kit installed, context loaded, skills available.

## Use Cases

### For Solo Developers / Small Teams
- **Vibe coding sessions** — Say `/build phone-numbers` and get a complete feature: schema, service, controller, API client, page — all following your project's patterns. No hand-holding required.
- **Quick fixes without waste** — Message classification means "fix the div error on line 12" costs ~200 tokens instead of 5000. The AI knows when NOT to load context.
- **One-person code review** — Run `saascode review` or `/review staged` and get a real security audit: guard chains, tenant isolation, SQL injection, secrets — with exact line numbers and fixes.

### For Growing Teams
- **Onboard new developers** — `/onboard` generates a project walkthrough from the actual codebase. New devs understand the architecture in minutes, not days.
- **Consistent code quality** — Every developer's AI uses the same CLAUDE.md, same patterns, same guard chain. No more "I didn't know we needed TenantGuard."
- **Replace paid tools** — AST review + endpoint parity + pre-commit hooks covers 80%+ of what CodeRabbit, Augment, and similar tools do. Zero per-seat cost.

### For Specific Workflows
- **Adding a new feature** — `/recipe crud` gives you a fill-in-the-blank template. Fill in the model name and fields, AI builds all 6 layers (schema through page).
- **Pre-deployment** — `saascode predeploy` runs build check + TypeScript check + endpoint parity + security audit. Catches issues before they reach production.
- **Debugging** — `/debug` classifies the bug, traces the full request path (frontend -> API client -> controller -> service -> DB), and proposes a fix with validation.
- **Database migrations** — `/migrate plan` analyzes schema changes, warns about breaking changes, generates the migration with rollback strategy.
- **PR reviews** — `/review 42` fetches the PR diff, runs AST analysis, cross-references the project map, and outputs a table of findings with confidence scores.

### What It Prevents
- Auth bypass (missing guards) — caught by AST review + Semgrep rules
- Tenant data leaks (unscoped queries) — caught by AST review + service scanning
- 404 errors (frontend calls missing backend) — caught by endpoint parity enforcer
- Secrets in code — caught by pre-commit hook + AST review
- Broken deployments — caught by pre-deploy checks + CI pipeline
- Repeated mistakes — caught by `/learn` which feeds findings back into kit rules

## What It Does

You fill out one `manifest.yaml` with your project's stack, auth, tenancy, billing, and patterns. The kit provides:

| Output | Purpose | Works With |
|--------|---------|------------|
| `CLAUDE.md` | AI coding context | Claude Code |
| `.cursorrules` | AI coding context | Cursor |
| `.windsurfrules` | AI coding context | Windsurf |
| Skills (`/audit`, `/build`, `/preflight`, `/review`, `/docs`, `/debug`, `/learn`) | Mid-conversation commands | Claude Code |
| Semgrep rules | Static analysis in IDE | Any IDE with Semgrep |
| Git hooks | Pre-commit & pre-push checks | Any git workflow |
| GitHub Actions | CI pipeline on PRs | GitHub |
| Shell scripts | On-demand audit & deploy checks | Any terminal |
| Checklists | Manual review guides | Any workflow |

## Installation

```bash
# Add as git submodule (recommended — stays in sync with updates)
git submodule add https://github.com/Saitata7/saascode-kit.git saascode-kit

# Or clone directly
git clone https://github.com/Saitata7/saascode-kit.git saascode-kit
```

## Quick Start

```bash
# 1. Configure manifest
cp saascode-kit/manifest.example.yaml saascode-kit/manifest.yaml
# Edit manifest.yaml with your project details

# 2. Full setup (interactive — installs everything)
./saascode-kit/setup.sh .

# Or just install for your IDE:
saascode claude     # Claude Code: CLAUDE.md + skills + hooks
saascode cursor     # Cursor: .cursorrules + .cursor/rules/
saascode windsurf   # Windsurf: .windsurfrules

# 3. Set up the CLI alias (one-time)
echo 'alias saascode=".saascode/scripts/saascode.sh"' >> ~/.zshrc
source ~/.zshrc
```

### Manual Setup

If you prefer to install components individually instead of using `setup.sh`:

```bash
# IDE context (pick your tool):
cp templates/CLAUDE.md.template /your-project/CLAUDE.md
cp templates/cursorrules.template /your-project/.cursorrules
cp templates/windsurfrules.template /your-project/.windsurfrules

# Skills (Claude Code only):
mkdir -p /your-project/.claude/skills
cp skills/*.md /your-project/.claude/skills/

# Semgrep rules:
mkdir -p /your-project/.saascode/rules
cp rules/*.yaml /your-project/.saascode/rules/

# Git hooks:
cp hooks/pre-commit /your-project/.git/hooks/pre-commit
cp hooks/pre-push /your-project/.git/hooks/pre-push
chmod +x /your-project/.git/hooks/pre-commit /your-project/.git/hooks/pre-push

# GitHub Actions:
mkdir -p /your-project/.github/workflows
cp ci/github-action.yml /your-project/.github/workflows/saascode.yml

# Scripts:
mkdir -p /your-project/.saascode/scripts
cp scripts/*.sh /your-project/.saascode/scripts/
cp scripts/*.ts /your-project/.saascode/scripts/
chmod +x /your-project/.saascode/scripts/*.sh

# Checklists:
cp -r checklists/ /your-project/docs/checklists/
```

## Directory Structure

```
saascode-kit/
├── setup.sh                       # Automated setup — reads manifest, generates everything
├── manifest.example.yaml          # Single source of truth — copy and customize
├── LEARNINGS.md                   # Growth log — tracked by /learn skill
├── SOURCES.md                     # Research sources for kit improvements
│
├── templates/                     # IDE/AI context files (pick your tool)
│   ├── CLAUDE.md.template         #   Claude Code context (slim, cached ~60 lines)
│   ├── cursorrules.template       #   Cursor context
│   └── windsurfrules.template     #   Windsurf context
│
├── skills/                        # Claude Code skills (mid-conversation commands)
│   ├── audit.md                   #   /audit — security & quality scan
│   ├── build-feature.md           #   /build — end-to-end feature builder (6-phase + validation)
│   ├── preflight.md               #   /preflight — deployment gates
│   ├── review-pr.md               #   /review — PR code review (AST-powered)
│   ├── recipe.md                  #   /recipe — prompt templates (crud, endpoint, page, form...)
│   ├── docs.md                    #   /docs — documentation organizer
│   ├── debug.md                   #   /debug — systematic debugging
│   ├── test.md                    #   /test — write + run tests
│   ├── migrate.md                 #   /migrate — database migration workflow
│   ├── deploy.md                  #   /deploy — deployment guide
│   ├── changelog.md               #   /changelog — generate changelog from git
│   ├── api.md                     #   /api — generate API reference
│   ├── onboard.md                 #   /onboard — developer onboarding guide
│   └── learn.md                   #   /learn — self-improvement, feeds findings back into kit
│
├── cursor-rules/                  # Cursor IDE rules (auto-applied by file pattern)
│   ├── backend-controller.mdc     #   Controller patterns: guards, roles, routes
│   ├── backend-service.mdc        #   Service patterns: tenant scoping, error handling
│   ├── backend-dto.mdc            #   DTO patterns: validation, transformations
│   ├── frontend-api-client.mdc    #   API client patterns: response unwrap, error handling
│   ├── frontend-page.mdc          #   Page patterns: 3 states, loading, error, empty
│   ├── schema.mdc                 #   Schema patterns: tenantId, indexes, cascades
│   └── security.mdc               #   Security patterns: auth, secrets, XSS
│
├── rules/                         # Semgrep static analysis rules
│   ├── auth-guards.yaml           #   Auth guard chain verification
│   ├── tenant-isolation.yaml      #   Multi-tenant query scoping
│   ├── security.yaml              #   XSS, SQLi, secrets, SSRF
│   ├── input-validation.yaml      #   DTO validation checks
│   └── ui-consistency.yaml        #   UI component & pattern rules
│
├── hooks/                         # Git hooks
│   ├── pre-commit                 #   Block secrets, .env, merge conflicts, large files
│   └── pre-push                   #   TypeScript check, build verification, security audit
│
├── scripts/                       # Shell + TypeScript scripts
│   ├── lib.sh                     #   Shared library (colors, manifest parsing, template replacement)
│   ├── saascode.sh                #   CLI dispatcher — `saascode <command>`
│   ├── check-file.sh              #   Single-file validator (17 check categories, < 1s)
│   ├── ai-review.sh               #   AI-powered review via Groq (free tier)
│   ├── intent-log.sh              #   PostToolUse hook — logs every AI edit to JSONL
│   ├── intent-cli.sh              #   Intent log viewer (session/file/summary)
│   ├── ast-review.ts              #   AST-based code review (ts-morph) — guards, scoping, secrets
│   ├── ast-review.sh              #   Shell wrapper for ast-review.ts
│   ├── endpoint-parity.sh         #   Route-level frontend↔backend comparison
│   ├── snapshot.sh                #   Auto-generate project-map.md from codebase
│   ├── full-audit.sh              #   Run all security + quality + pattern checks
│   └── pre-deploy.sh              #   Full deployment readiness verification
│
├── ci/                            # CI/CD pipeline configs
│   └── github-action.yml          #   GitHub Actions: build, test, security, patterns
│
├── checklists/                    # Manual review checklists
│   ├── feature-complete.md        #   Before marking a feature done
│   ├── security-review.md         #   Before merging security-sensitive PRs
│   └── deploy-ready.md            #   Before production deployment
│
└── README.md                      # This file
```

## How It Works

### 7-Layer Bug Prevention

```
Layer 1: CLAUDE.md / .cursorrules        While you code (AI context + patterns)
Layer 2: Claude Code hooks (check-file)  Real-time — after every AI edit (< 1 second)
Layer 3: AI review (saascode review --ai) On-demand — LLM-powered semantic analysis (Groq)
Layer 4: Semgrep rules                   In your IDE (real-time static analysis)
Layer 5: Git hooks (pre-commit)          At commit time (blocks secrets, conflicts)
Layer 6: AST review + endpoint parity    At review time (ts-morph code analysis)
Layer 7: GitHub Actions                  At PR time (build, test, security, patterns)
```

```
            PREVENTION          DETECTION              GATE
            (while coding)      (after edit)           (before ship)
            ─────────────       ────────────           ─────────────
IDE Rules → .cursorrules
             .windsurfrules

Claude Code →                 → Hooks (post-edit)   →
                                check-file.sh
                                intent-log.sh

Manual      →                 → saascode review --ai →

Git Commit  →                                        → Pre-commit (7 checks)
Git Push    →                                        → Pre-push (3 checks)
Pull Request →                                       → CI/CD (5 jobs)
Deploy      →                                        → Pre-deploy (7 gates)
```

Each layer catches what the previous one missed. Together they prevent:
- Auth bypass (missing guards/roles) — Layer 1, 2, 3, 6
- Tenant data leaks (unscoped queries) — Layer 1, 2, 3, 6
- Security vulnerabilities (XSS, SQLi, secrets) — Layer 2, 4, 5, 6
- N+1 queries (Prisma calls in loops) — Layer 2, 3
- React hook violations — Layer 2
- Switch exhaustiveness gaps — Layer 2
- Runtime 404s (endpoint mismatch) — Layer 6
- Intent drift (AI did wrong thing) — Layer 2 (intent tracking)
- Bad deployments (untested, unverified code) — Layer 5, 7

### Skills (Claude Code)

Skills are `.md` files that act as mid-conversation commands:

```
/build phone-numbers → Builds a feature end-to-end (6-phase + inline validation)
/review 42           → AST-powered PR review with confidence scores
/recipe crud         → Fill-in-the-blank template for common tasks
/audit agents        → Security + quality audit on a specific module
/preflight           → All deployment gates in one command
/debug 500           → Classifies bug, traces request path, proposes fix
/test phone-numbers  → Writes + runs tests for a module
/migrate plan        → Analyzes schema changes, warns about breaking changes
/docs init           → Organizes project docs into standard SaaS structure
/changelog v1.2      → Generates changelog from git history
/onboard             → Developer onboarding guide from actual codebase
/learn [finding]     → Captures lessons and feeds them back into kit rules
```

They work because Claude Code loads skill files on invocation, giving the AI targeted instructions, checklists, and verification commands for that specific task.

### Tiered Context System

The kit uses a 3-tier context architecture to minimize token usage:

```
Tier 1: CLAUDE.md (~60 lines)              Always loaded, prompt-cached by Anthropic
Tier 2: .claude/context/project-map.md     Loaded on-demand for MEDIUM tasks
Tier 3: .claude/context/golden-reference.md Loaded on-demand for FULL tasks
```

Message classification (built into CLAUDE.md):
- **QUICK** — "fix the typo", "rename this var" → No context loading, just fix it
- **MEDIUM** — "add an endpoint", "update this page" → Load project-map
- **FULL** — "/build", "/review", new module → Load everything

This means a quick CSS fix costs ~200 tokens instead of 5000+.

### CLI Commands

```bash
# IDE Setup (pick your IDE)
saascode claude                    # Install Claude Code config (CLAUDE.md, skills, hooks)
saascode cursor                    # Install Cursor config (.cursorrules, rules)
saascode windsurf                  # Install Windsurf config (.windsurfrules)

# Setup & Sync
saascode init                      # Full interactive setup (all components)
saascode update                    # Sync kit source → installed locations
saascode verify                    # Verify development environment
saascode status                    # Kit installation status

# Code Review
saascode review                    # AST-based code review (ts-morph)
saascode review --ai               # AI-powered review via Groq (free)
saascode review --ai --file X.ts   # AI review a specific file
saascode check-file <path>         # Single-file validator (Claude Code hook)

# Analysis
saascode audit                     # Full security + quality audit
saascode parity                    # Frontend↔backend endpoint comparison
saascode snapshot                  # Regenerate project-map.md from codebase

# Tracking & Deployment
saascode intent                    # View AI edit intent log
saascode intent --summary          # Session summaries (files, pass/warn/blocked)
saascode predeploy                 # Pre-deployment gates
saascode checklist [name]          # Show a checklist
```

### Semgrep Rules

The rules work with Semgrep CLI or IDE extension:

```bash
# Install Semgrep
pip install semgrep

# Run all rules
semgrep --config rules/ apps/

# Run specific rule set
semgrep --config rules/security.yaml apps/api/src/
semgrep --config rules/tenant-isolation.yaml apps/api/src/modules/
```

IDE integration (VS Code):
1. Install "Semgrep" extension
2. Set config path to your rules directory
3. Issues appear inline as you code

## Customization

### manifest.yaml

The manifest is the single source of truth. Key sections:

| Section | Controls |
|---------|----------|
| `project` | Name, type, domain |
| `stack` | Framework, ORM, database, UI library |
| `auth` | Provider, roles, guard pattern |
| `tenancy` | Isolation level, identifier field |
| `billing` | Provider, model, webhooks |
| `paths` | Your project's directory structure |
| `patterns` | Critical patterns, anti-patterns, color system |

### Adding Custom Semgrep Rules

Create a new `.yaml` file in `rules/`:

```yaml
rules:
  - id: my-custom-rule
    message: |
      Description of what's wrong and how to fix it.
    severity: ERROR  # ERROR, WARNING, INFO
    languages: [typescript]
    pattern: <the code pattern to match>
```

### Adding Custom Skills

Create a new `.md` file in `skills/`:

```markdown
# Skill: My Custom Skill

> Trigger: /my-skill [args]
> Purpose: What this skill does

## Instructions
You are a [role]. Do [task].

## Execution
### Step 1: ...
### Step 2: ...

## Output
Report format...
```

## Template Placeholders

Templates use `{{handlebars}}` syntax. Replace with values from your manifest:

| Placeholder | Example Value |
|-------------|---------------|
| `{{project.name}}` | MyApp |
| `{{stack.frontend.framework}}` | nextjs |
| `{{stack.backend.framework}}` | nestjs |
| `{{auth.provider}}` | clerk |
| `{{tenancy.identifier}}` | tenantId |
| `{{paths.backend}}` | apps/api |
| `{{paths.frontend}}` | apps/portal |
| `{{paths.schema}}` | apps/api/prisma/schema.prisma |
| `{{paths.api_client}}` | apps/portal/src/lib/api |

Conditional blocks:
- `{{#if tenancy.enabled}}...{{/if}}` — include if true
- `{{#if_eq auth.guard_pattern "decorator"}}...{{/if_eq}}` — include if value matches
- `{{#each auth.roles}}...{{/each}}` — loop over array

## What This Kit Is NOT

- **Not a code generator** — it doesn't scaffold your app
- **Not a framework** — it works alongside your existing stack
- **Not opinionated about architecture** — it adapts to your manifest
- **Not a replacement for tests** — it's an additional safety layer
- **Not vendor-locked** — works with Claude Code, Cursor, Windsurf, any Semgrep-compatible IDE

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- Report bugs via [Issues](https://github.com/Saitata7/saascode-kit/issues)
- Submit improvements via [Pull Requests](https://github.com/Saitata7/saascode-kit/pulls)
- Star the repo if you find it useful

## Author

**Sai Kumar Tata** ([@Saitata7](https://github.com/Saitata7))

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Sai Kumar Tata
