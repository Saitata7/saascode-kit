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
  <a href="https://www.npmjs.com/package/saascode-kit"><img src="https://img.shields.io/npm/v/saascode-kit?style=flat-square" alt="npm"></a>
</p>

<p align="center">
  <a href="#what-is-saascode-kit">What Is It</a> &middot;
  <a href="#key-features">Key Features</a> &middot;
  <a href="#who-is-this-for">Who Is This For</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="GOALS.md">Goals & Vision</a> &middot;
  <a href="SETUP.md">Full Setup Guide</a>
</p>

---

## What Is SaasCode Kit?

AI coding tools are powerful but blind -- they don't know your auth flow, your security patterns, your API conventions, or which endpoints already exist. You end up repeating the same instructions, fixing the same mistakes, and babysitting every prompt.

SaasCode Kit solves this. You fill out one `manifest.yaml` with your project's stack, and the kit generates IDE-specific context files, code review automation, git hooks, and CLI tools -- all tailored to **your** project.

**One manifest. Every IDE. Every developer. Same rules.**

---

## Key Features

### Code Review & Analysis

| Feature | What It Does |
|---------|-------------|
| **AST-Based Code Review** | Parses your controllers and services with ts-morph. Catches missing auth guards, unscoped queries, empty catch blocks, hardcoded secrets -- with exact line numbers and confidence scores. Aggregates noisy warnings (e.g. console.log) per file to surface meaningful findings |
| **AI-Powered Review** | LLM-based semantic code review using free-tier providers (Groq). Catches logical issues that pattern matching can't |
| **Real-Time File Validation** | Claude Code hooks run after every AI edit (< 1 second). 17 check categories -- the AI self-corrects before you even review |
| **Endpoint Parity Checker** | Compares frontend API client calls against backend controller routes. Catches 404s before runtime |

### Prevention & Gates

| Feature | What It Does |
|---------|-------------|
| **Pre-Commit Hook** | Blocks secrets, .env files, merge conflict markers, debug statements, and oversized files before they enter git |
| **Pre-Push Hook** | Runs TypeScript check, build verification, and security audit before code reaches the remote |
| **CI/CD Pipeline** | GitHub Actions workflow: build, test, endpoint parity, and security checks on every PR |
| **Pre-Deploy Gates** | Full deployment readiness verification -- build, types, tests, parity, security in one command. Auto-detects monorepo vs single-package projects |

### IDE Context & AI Skills

| Feature | What It Does |
|---------|-------------|
| **IDE Context Generation** | Generates `CLAUDE.md`, `.cursorrules`, `.windsurfrules` from your manifest -- your project's rules baked into every AI conversation |
| **14 AI Skills** | Mid-conversation commands for Claude Code: `/build` (full features), `/review` (PR review), `/audit` (security scan), `/debug`, `/test`, `/migrate`, and 8 more |
| **Tiered Context System** | Message classification (QUICK/MEDIUM/FULL) so a CSS fix costs ~200 tokens instead of 5000+ |
| **Semgrep Rule Sets** | 5 rule sets for real-time static analysis in any IDE: auth, security, input validation, data scoping, UI consistency |

### Tracking & Intelligence

| Feature | What It Does |
|---------|-------------|
| **Intent Tracking** | Logs every AI edit with context -- what was changed, which file, what the check-file validator found. Full audit trail |
| **Issue Report Logging** | Every detected issue (from check-file, audit, pre-deploy) is auto-logged to `.saascode/logs/`. View with `saascode report`, or file to GitHub with `--github` |
| **Full Sweep** | One command runs audit + pre-deploy + code review in sequence with a combined pass/fail summary |
| **Stealth Mode (Cloak)** | Removes all traces of saascode-kit and AI tools from your repo. Renames directories, strips branding, stashes `.claude/`, `.cursor/`, `.cursorrules`, `.windsurfrules`. Nobody can tell you're using it |
| **Self-Improving Rules** | `/learn` skill captures real bugs found during development and feeds them back into the kit's patterns |
| **Project Snapshot** | Auto-generates `project-map.md` from your actual codebase -- models, endpoints, pages, components |

---

## Who Is This For?

### SaaS Developers Using AI Coding Tools

If you use Claude Code, Cursor, or Windsurf to build SaaS applications and want the AI to follow your project's patterns instead of guessing.

### Solo Developers Who Need Code Review

If you're a solo developer or small team without dedicated reviewers. The kit gives you automated security and quality checks that would otherwise require expensive per-seat tools.

### Teams Who Want Consistency

If your team has 3+ developers using AI tools and you want everyone's AI to follow the same conventions -- same auth patterns, same API structure, same code style.

### Projects With Custom Patterns

If your project has specific rules that generic linters can't enforce -- auth guard ordering, data scoping conventions, API response formats, or any project-specific patterns that matter.

---

## Quick Start

### Option 1: npx (Recommended)

```bash
npx saascode-kit init
```

This creates `manifest.yaml` from the template. Edit it with your project details, then run `npx saascode-kit init` again to install everything.

### Option 2: Git Submodule

```bash
# 1. Add to your project
git submodule add https://github.com/Saitata7/saascode-kit.git saascode-kit

# 2. Configure
cp saascode-kit/manifest.example.yaml saascode-kit/manifest.yaml
# Edit manifest.yaml with your project details

# 3. Install for your IDE
saascode claude     # Claude Code users
saascode cursor     # Cursor users
saascode windsurf   # Windsurf users

# Or install everything at once
saascode init
```

> See **[SETUP.md](SETUP.md)** for detailed installation, manifest configuration, CLI reference, and directory structure.

## CLI Commands

```bash
# IDE Setup
saascode claude                    # Install Claude Code config
saascode cursor                    # Install Cursor config
saascode windsurf                  # Install Windsurf config

# Code Review
saascode review                    # AST-based code review
saascode review --changed-only     # Review only files changed in last commit
saascode review --ai               # AI-powered review (LLM)
saascode check-file <path>         # Single-file validator (17 checks)

# Analysis & Deployment
saascode sweep                     # Run ALL checks (audit + predeploy + review)
saascode audit                     # Full security + quality audit
saascode parity                    # Frontend-backend endpoint comparison
saascode predeploy                 # Pre-deployment gates

# Issue Tracking
saascode report                    # View detected issues
saascode report --github           # File issues to GitHub
saascode report --summary          # Issue counts by category

# Stealth Mode
saascode cloak                     # Hide all kit + AI tool traces
saascode uncloak                   # Reverse stealth mode

# Setup & Sync
saascode init                      # Full interactive setup
saascode update                    # Sync kit to installed locations
saascode status                    # Show what's installed
saascode help                      # All commands
```

## Documentation

| Document | What's In It |
|----------|-------------|
| **[GOALS.md](GOALS.md)** | Vision, aims, use cases, pros & cons, how it compares to alternatives |
| **[SETUP.md](SETUP.md)** | Installation, manifest config, CLI reference, directory structure, troubleshooting |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | How to contribute, code style, testing guidelines |
| **[LEARNINGS.md](LEARNINGS.md)** | Growth log -- auto-populated by the `/learn` skill |

## Author

Created by **Sai Kumar Tata** ([@Saitata7](https://github.com/Saitata7))

## License

[MIT License](LICENSE) -- Copyright (c) 2026 Sai Kumar Tata
