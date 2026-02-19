# Changelog

All notable changes to SaasCode Kit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-18

### Added

- **CLI** (`bin/cli.sh`, `scripts/saascode.sh`) — 25+ commands via `npx kit <command>`
- **Template engine** — `{{placeholder}}` substitution, `{{#if_eq}}` conditionals, `{{#each}}` loops
- **IDE support** — Claude Code, Cursor, Windsurf, Google Antigravity, GitHub Copilot, Aider, Cline, Continue (8 IDEs)
- **Claude Code skills** — 19 skills (`/audit`, `/build`, `/test`, `/debug`, `/docs`, `/prd`, `/design`, `/techstack`, `/todo`, `/api`, `/migrate`, `/deploy`, `/changelog`, `/onboard`, `/learn`, `/preflight`, `/review`, `/recipe`, `/skill-create`)
- **Skill frontmatter** — all skills have YAML frontmatter with name, description, trigger phrases, and negative triggers (Anthropic skills guide compliant)
- **Design docs** — `/design` generates feature architecture, UI wireframes (ASCII), API contracts
- **Tech stack ADRs** — `/techstack` generates Architecture Decision Records with comparison matrix
- **Task planning** — `/todo` breaks features into ordered tasks with acceptance criteria and dependencies
- **Cursor rules** — 8 file-pattern-specific rules with multi-framework support (NestJS, Express, Django, Rails, Spring Boot, Laravel)
- **AST code review** — TypeScript (ts-morph), Python (stdlib ast), Java, Go, Ruby reviewers
- **AI review** — 7 LLM providers (Groq, OpenAI, Anthropic, Gemini, DeepSeek, Kimi, Qwen) with auto-detection
- **Review output** — JSON and SARIF output formats for CI/tool integration
- **Repo-level review** — circular imports, orphan files, dead exports, cross-module tenant scoping
- **Intent verification** — LLM-based diff-vs-intent comparison (`saascode review --verify-intent`)
- **Semgrep rules** — 95 rules across 6 languages (TypeScript/JS, Python, Java, Go, Ruby, PHP)
- **Git hooks** — pre-commit (7 checks) and pre-push (3 checks), POSIX-compatible
- **PostToolUse hooks** — `check-file.sh` (17 checks, <1s) and `intent-log.sh` for Claude Code
- **Full audit** — 13-check security + quality audit (`saascode audit`)
- **Endpoint parity** — frontend-backend route comparison (`saascode parity`)
- **Pre-deploy gates** — 8-gate deployment readiness checker (`saascode predeploy`)
- **Sweep** — combined audit + predeploy + review (`saascode sweep`)
- **Snapshot** — project-map.md generator (`saascode snapshot`)
- **Docs** — project overview, Mermaid diagrams, Product Brief generator (`saascode docs`)
- **Intent tracking** — JSONL edit logging with session summaries (`saascode intent`)
- **Issue reports** — detected issues viewer + GitHub issue creation (`saascode report`)
- **Adaptive learning** — warning pattern tracker, auto-suppress noisy warnings (`saascode learn`)
- **Stealth mode** — hide/restore all kit traces (`saascode cloak` / `saascode uncloak`)
- **CI pipelines** — GitHub Actions and GitLab CI templates, language-aware with conditional blocks
- **Doctor** — 10-check setup diagnostics (`saascode doctor`)
- **Update --full** — `kit update --full` regenerates all IDE templates from manifest (not just raw file sync)
- **Workflow guide** — `kit help` shows recommended command order (setup → plan → build → review → ship → maintain)
- **Verbose mode** — `--verbose` / `-v` flag for debug output
- **Golden reference** — auto-generated code patterns for `/build` skill
- **Manifest-driven** — single `saascode-kit.yaml` drives all generation
- **Zero runtime dependencies** — core CLI is pure Bash/Zsh, no Python/Node required
- **Multi-language** — supports TypeScript, JavaScript, Python, Go, Java, Ruby, Rust, PHP
