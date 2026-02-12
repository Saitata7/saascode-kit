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
  <a href="#what-is-saascode-kit">What Is It</a> &middot;
  <a href="#quick-start">Quick Start</a> &middot;
  <a href="#cli-commands">CLI Commands</a> &middot;
  <a href="GOALS.md">Goals & Vision</a> &middot;
  <a href="SETUP.md">Full Setup Guide</a> &middot;
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

---

## What Is SaasCode Kit?

AI coding tools are powerful but blind -- they don't know your auth pattern, tenant isolation rules, or which endpoints exist. You end up repeating yourself, fixing the same mistakes, and babysitting every prompt.

SaasCode Kit solves this. You fill out one `manifest.yaml` with your project's stack, and the kit generates IDE-specific context files, code review rules, git hooks, and CLI tools -- all tailored to your project.

**One manifest. Every IDE. Every developer. Same rules.**

### What It Generates

| Output | Purpose | Works With |
|--------|---------|------------|
| `CLAUDE.md` | AI coding context | Claude Code |
| `.cursorrules` + `.cursor/rules/` | AI coding context + file-pattern rules | Cursor |
| `.windsurfrules` | AI coding context | Windsurf |
| 14 Skills (`/build`, `/review`, `/audit`, etc.) | Mid-conversation commands | Claude Code |
| 5 Semgrep rule sets | Static analysis in IDE | Any IDE with Semgrep |
| Git hooks | Pre-commit & pre-push checks | Any git workflow |
| GitHub Actions | CI pipeline on PRs | GitHub |
| Shell scripts | On-demand audit, review & deploy checks | Any terminal |

## Quick Start

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

> See [SETUP.md](SETUP.md) for detailed installation, manifest configuration, and directory structure.

## CLI Commands

```bash
# IDE Setup
saascode claude                    # Install Claude Code config
saascode cursor                    # Install Cursor config
saascode windsurf                  # Install Windsurf config

# Setup & Sync
saascode init                      # Full interactive setup
saascode update                    # Sync kit source to installed locations
saascode status                    # Show what's installed

# Code Review
saascode review                    # AST-based code review
saascode review --ai               # AI-powered review via Groq
saascode check-file <path>         # Single-file validator

# Analysis
saascode audit                     # Full security + quality audit
saascode parity                    # Frontend-backend endpoint comparison
saascode snapshot                  # Regenerate project-map.md

# Deployment
saascode predeploy                 # Pre-deployment gates
saascode checklist [name]          # Show a checklist
```

## How It Works

7 layers of protection, from writing code to deploying it:

```
While coding     CLAUDE.md, .cursorrules, .windsurfrules    (AI knows your rules)
After each edit  Claude Code hooks (check-file.sh)          (validates in < 1 second)
On demand        saascode review --ai                       (LLM-powered analysis)
In your IDE      Semgrep rules                              (real-time static analysis)
At commit        Pre-commit hook                            (blocks secrets, conflicts)
At review        AST review + endpoint parity               (ts-morph code analysis)
At PR            GitHub Actions                             (build, test, security)
```

Each layer catches what the previous one missed.

## Documentation

| Document | What's In It |
|----------|-------------|
| **[GOALS.md](GOALS.md)** | Vision, aims, use cases, pros & cons, how it compares to alternatives |
| **[SETUP.md](SETUP.md)** | Installation, manifest configuration, CLI setup, directory structure |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | How to contribute, code style, testing guidelines |
| **[LEARNINGS.md](LEARNINGS.md)** | Growth log -- auto-populated by the `/learn` skill |

## Author

Created by **Sai Kumar Tata** ([@Saitata7](https://github.com/Saitata7))

## License

[MIT License](LICENSE) -- Copyright (c) 2026 Sai Kumar Tata
