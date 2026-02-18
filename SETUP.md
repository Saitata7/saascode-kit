# Setup Guide

## Prerequisites

- **bash** or **zsh** shell
- **Node.js** (for npx and AST-based review)
- **Git** (if using submodule or clone method)
- A SaaS project to configure

---

## Installation

### Option 1: npx (Recommended)

Fastest way to get started. No git knowledge needed:

```bash
npx kit init
```

First run creates `saascode-kit.yaml` in your project. Edit it with your project details, then run again:

```bash
# Edit saascode-kit.yaml with your project details
npx kit init
```

The second run reads your manifest and installs everything (templates, skills, rules, hooks, CI, scripts).

### Option 2: Git Submodule

Stays in sync with kit updates. Run from your project root:

```bash
git submodule add https://github.com/Saitata7/saascode-kit.git saascode-kit
```

To update later:

```bash
cd saascode-kit && git pull origin main && cd ..
```

When cloning a project that already has the submodule:

```bash
git clone --recurse-submodules <your-repo-url>
# Or if already cloned:
git submodule update --init
```

### Option 3: Clone Directly

```bash
git clone https://github.com/Saitata7/saascode-kit.git saascode-kit
```

---

## Configuration

### For npx users

Edit `saascode-kit.yaml` (created by `npx kit init`) and run the init command again.

### For submodule/clone users

```bash
cp saascode-kit/manifest.example.yaml saascode-kit/manifest.yaml
```

### Manifest Reference

The manifest is the single source of truth. Key sections to fill in:

| Section | What to Set |
|---------|------------|
| `project` | Your app name, type (multi-tenant-saas, api-service, etc.), domain |
| `stack` | Frontend framework, backend framework, ORM, database |
| `auth` | Provider (clerk, auth0, etc.), roles, guard pattern |
| `tenancy` | Isolation level, identifier field (e.g. `tenantId`) |
| `billing` | Provider (stripe, etc.), model (subscription, usage-based) |
| `ai` | Set `enabled: true` if your app has AI features |
| `paths` | Your project's directory structure (frontend, backend, schema, api client) |
| `patterns` | Critical patterns and anti-patterns specific to your project |

### 3. Install

**For a specific IDE:**

```bash
saascode claude     # CLAUDE.md + skills + hooks
saascode cursor     # .cursorrules + .cursor/rules/
saascode windsurf   # .windsurfrules
```

**For everything (interactive):**

```bash
saascode init
```

### 4. Set Up the CLI Alias

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias saascode=".saascode/scripts/saascode.sh"
```

Then reload:

```bash
source ~/.zshrc
```

---

## CLI Commands

### IDE Setup

| Command | What It Installs |
|---------|-----------------|
| `saascode claude` | `CLAUDE.md` (from template), `.claude/skills/*.md`, `.claude/settings.json` (hooks) |
| `saascode cursor` | `.cursorrules` (from template), `.cursor/rules/*.mdc` (conditional `ai-security.mdc`) |
| `saascode windsurf` | `.windsurfrules` (from template) |
| `saascode init` | Everything above + Semgrep rules, git hooks, CI, scripts, checklists |
| `saascode update` | Syncs kit source to all installed locations |

### Code Review

| Command | What It Does |
|---------|-------------|
| `saascode review` | AST-based code review using ts-morph |
| `saascode review --changed-only` | Review only files changed in last commit (filters out kit/tooling files) |
| `saascode review --ai` | AI-powered review (auto-detects provider from API key in .env) |
| `saascode review --ai --provider X` | Use specific provider: groq, openai, claude, gemini, deepseek, kimi, qwen |
| `saascode review --ai --model X` | Override default model for any provider |
| `saascode review --ai --file X.ts` | AI review a specific file |
| `saascode check-file <path>` | Single-file validator (17 check categories, < 1 second) |

### Analysis

| Command | What It Does |
|---------|-------------|
| `saascode sweep` | Run ALL checks in sequence (audit + predeploy + review) |
| `saascode sweep --ai` | Full sweep with AI-powered review |
| `saascode sweep --skip-review` | Skip the review step |
| `saascode sweep --skip-predeploy` | Skip the predeploy step |
| `saascode audit` | Full security + quality audit |
| `saascode parity` | Frontend-backend endpoint comparison |
| `saascode snapshot` | Regenerate `project-map.md` from codebase |

### Tracking & Deployment

| Command | What It Does |
|---------|-------------|
| `saascode intent` | View AI edit intent log |
| `saascode intent --summary` | Session summaries (files, pass/warn/blocked) |
| `saascode report` | View detected issues (today by default) |
| `saascode report --days N` | Show issues from last N days |
| `saascode report --severity critical` | Filter by severity (critical or warning) |
| `saascode report --source check-file` | Filter by source (check-file, full-audit, pre-deploy) |
| `saascode report --summary` | Aggregate issue counts by category + severity |
| `saascode report --json` | Raw JSONL output |
| `saascode report --github` | Create a GitHub Issue from collected issues |
| `saascode report --clear` | Delete issue logs older than 30 days |
| `saascode predeploy` | Pre-deployment gates (auto-detects monorepo vs single-package) |
| `saascode checklist [name]` | Show a checklist (feature-complete, security-review, deploy-ready) |

### Stealth Mode

| Command | What It Does |
|---------|-------------|
| `saascode cloak` | Hide all kit + AI tool traces from repo (default: `.devkit`) |
| `saascode cloak --name .tools` | Use a custom directory name instead of `.devkit` |
| `saascode uncloak` | Reverse stealth mode, restore all files to original locations |

Cloak renames `.saascode/` to your chosen name, strips all branding from scripts/hooks/CI, stashes `.claude/`, `.cursor/`, `.cursorrules`, `.windsurfrules`, `CLAUDE.md` inside the cloaked directory, and cleans `.gitignore` of tool mentions. Uncloak reverses everything. After uncloaking, run `saascode claude`/`cursor` to restore full branding.

### Info

| Command | What It Does |
|---------|-------------|
| `saascode status` | Show kit installation status |
| `saascode verify` | Verify development environment setup |
| `saascode rules` | List installed Semgrep rules |
| `saascode skills` | List installed Claude Code skills |
| `saascode help` | Full help message |

---

## Directory Structure

```
saascode-kit/
├── package.json                   # npm package config (for npx kit init)
├── bin/
│   └── cli.sh                     # npx CLI entry point
├── setup.sh                       # Automated setup -- reads manifest, generates everything
├── manifest.example.yaml          # Template -- copy to manifest.yaml and customize
├── README.md                      # Project overview
├── GOALS.md                       # Vision, aims, use cases, pros & cons
├── SETUP.md                       # This file
├── CONTRIBUTING.md                # Contribution guidelines
├── LEARNINGS.md                   # Growth log -- auto-populated by /learn skill
├── LICENSE                        # MIT License
│
├── templates/                     # IDE context templates
│   ├── CLAUDE.md.template         #   Claude Code context
│   ├── cursorrules.template       #   Cursor context
│   └── windsurfrules.template     #   Windsurf context
│
├── skills/                        # Claude Code skills (14 commands)
│   ├── build-feature.md           #   /build -- end-to-end feature builder
│   ├── review-pr.md               #   /review -- PR code review
│   ├── audit.md                   #   /audit -- security & quality scan
│   ├── preflight.md               #   /preflight -- deployment gates
│   ├── recipe.md                  #   /recipe -- prompt templates
│   ├── debug.md                   #   /debug -- systematic debugging
│   ├── test.md                    #   /test -- write + run tests
│   ├── docs.md                    #   /docs -- documentation organizer
│   ├── migrate.md                 #   /migrate -- database migration workflow
│   ├── deploy.md                  #   /deploy -- deployment guide
│   ├── changelog.md               #   /changelog -- generate changelog
│   ├── api.md                     #   /api -- generate API reference
│   ├── onboard.md                 #   /onboard -- developer onboarding
│   └── learn.md                   #   /learn -- self-improvement
│
├── cursor-rules/                  # Cursor file-pattern rules
│   ├── backend-controller.mdc     #   Controller patterns
│   ├── backend-service.mdc        #   Service patterns
│   ├── backend-dto.mdc            #   DTO patterns
│   ├── frontend-api-client.mdc    #   API client patterns
│   ├── frontend-page.mdc          #   Page patterns
│   ├── schema.mdc                 #   Schema patterns
│   ├── security.mdc               #   Security patterns
│   └── ai-security.mdc            #   AI security (only if ai.enabled=true)
│
├── rules/                         # Semgrep static analysis rules
│   ├── auth-guards.yaml           #   Auth guard chain verification
│   ├── tenant-isolation.yaml      #   Multi-tenant query scoping
│   ├── security.yaml              #   XSS, SQLi, secrets, SSRF
│   ├── input-validation.yaml      #   DTO validation checks
│   └── ui-consistency.yaml        #   UI component rules
│
├── hooks/                         # Git hooks
│   ├── pre-commit                 #   Block secrets, .env, merge conflicts, large files
│   └── pre-push                   #   TypeScript check, build, security audit
│
├── scripts/                       # Shell + TypeScript scripts
│   ├── lib.sh                     #   Shared library (manifest parsing, templates, log_issue)
│   ├── saascode.sh                #   CLI dispatcher
│   ├── check-file.sh              #   Single-file validator (17 checks)
│   ├── ai-review.sh               #   AI-powered review (multi-provider)
│   ├── ast-review.ts              #   AST-based review (ts-morph)
│   ├── ast-review.sh              #   Shell wrapper for ast-review.ts
│   ├── endpoint-parity.sh         #   Frontend-backend route comparison
│   ├── snapshot.sh                #   Auto-generate project-map.md
│   ├── full-audit.sh              #   All security + quality checks
│   ├── pre-deploy.sh              #   Deployment readiness verification
│   ├── intent-log.sh              #   PostToolUse hook (logs AI edits)
│   ├── intent-cli.sh              #   Intent log viewer
│   ├── report-cli.sh              #   Issue report viewer + GitHub issue creator
│   ├── sweep-cli.sh               #   Full sweep (audit + predeploy + review)
│   └── cloak-cli.sh               #   Stealth mode (cloak/uncloak)
│
├── ci/                            # CI/CD configs
│   └── github-action.yml          #   GitHub Actions pipeline
│
├── checklists/                    # Manual review checklists
│   ├── feature-complete.md        #   Before marking a feature done
│   ├── security-review.md         #   Before merging security-sensitive PRs
│   └── deploy-ready.md            #   Before production deployment
│
└── .github/                       # GitHub templates
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   └── feature_request.md
    └── PULL_REQUEST_TEMPLATE.md
```

---

## Template Placeholders

Templates use `{{handlebars}}` syntax, replaced with values from your manifest:

| Placeholder | Example Value |
|-------------|---------------|
| `{{project.name}}` | MyApp |
| `{{project.port}}` | 4000 |
| `{{stack.frontend.framework}}` | nextjs |
| `{{stack.backend.framework}}` | nestjs |
| `{{stack.backend.orm}}` | prisma |
| `{{auth.provider}}` | clerk |
| `{{tenancy.identifier}}` | tenantId |
| `{{paths.backend}}` | apps/api |
| `{{paths.frontend}}` | apps/portal |
| `{{paths.schema}}` | apps/api/prisma/schema.prisma |
| `{{paths.api_client}}` | apps/portal/src/lib/api |

---

## Customization

### Adding Custom Semgrep Rules

Create a `.yaml` file in `rules/`:

```yaml
rules:
  - id: my-custom-rule
    message: "Description of what's wrong and how to fix it."
    severity: ERROR
    languages: [typescript]
    pattern: <the code pattern to match>
```

### Adding Custom Skills

Create a `.md` file in `skills/`:

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

---

## Troubleshooting

**`saascode: command not found`**
Add the alias to your shell profile: `alias saascode=".saascode/scripts/saascode.sh"`

**`manifest.yaml not found`**
If using npx: Run `npx kit init` to create `saascode-kit.yaml`.
If using submodule: `cp saascode-kit/manifest.example.yaml saascode-kit/manifest.yaml`

**Placeholders not replaced**
Make sure `manifest.yaml` exists and has values filled in. Run `saascode claude` (or cursor/windsurf) again after editing the manifest.

**Submodule empty after clone**
Run: `git submodule update --init`
