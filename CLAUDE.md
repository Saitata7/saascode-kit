# Kit — Project Context

> This is the development context for working ON the kit itself, not a user project.

## What This Is

Kit is a manifest-driven development toolkit that gives AI agents (Claude Code, Cursor, Windsurf) project-specific intelligence. One `manifest.yaml` generates context files, skills, rules, hooks, review engines, and CI pipelines.

**Primary users:** AI agents. **Secondary users:** Human developers via CLI.

## Tech Stack

- **Core:** Bash/Zsh (zero dependencies for CLI)
- **AST Review:** TypeScript (ts-morph), Python (stdlib ast), Java (bash+grep+awk)
- **AI Review:** Shell + curl (7 LLM providers)
- **Static Analysis:** Semgrep YAML rules
- **Distribution:** npm (npx kit)
- **Template Engine:** Custom awk/sed (BSD-compatible, no Python/Node dependency for init)

## Project Structure

```
bin/cli.sh                    # npx entry point
scripts/saascode.sh           # Command dispatcher (20+ commands)
scripts/lib.sh                # Shared library (manifest parsing, detection, templates)
scripts/*.sh                  # Individual command scripts
setup.sh                      # Installer (reads manifest, generates everything)
templates/                    # IDE context templates (CLAUDE.md, cursorrules, windsurfrules)
skills/                       # Claude Code skills (15 .md files)
cursor-rules/                 # Cursor rules (8 .mdc files)
rules/                        # Semgrep rule sets (5 .yaml files)
hooks/                        # Git hooks (pre-commit, pre-push)
checklists/                   # Quality checklists (3 .md files)
ci/                           # CI pipeline templates
tests/                        # 16 fixture projects for testing
docs/                         # Documentation
docs/product/                 # Internal strategy docs (gitignored)
```

## Key Conventions

- **All scripts source `scripts/lib.sh`** for manifest parsing, detection helpers, and template engine
- **POSIX-compatible hooks** — `hooks/pre-commit` and `hooks/pre-push` use `/bin/sh`, not bash
- **Multi-language support** — 8 languages (TS, JS, Python, Ruby, Go, Java, Rust, PHP) via detection helpers in lib.sh
- **Template placeholders** — `{{key.subkey}}` syntax, processed by `replace_placeholders` and `process_conditionals`
- **Conditional blocks** — `{{#if field}}`, `{{#if_eq field "value"}}`, `{{#each array}}`
- **JSONL logging** — `log_issue()` writes to `.saascode/logs/issues-YYYY-MM-DD.jsonl`
- **BSD compatibility** — sed/awk must work on macOS without GNU coreutils

## Golden Rules

| # | May do | Must NOT do |
|---|--------|-------------|
| 1 | Edit scripts, templates, skills, rules | Break BSD/POSIX compatibility in hooks |
| 2 | Add new CLI commands via saascode.sh | Add Python/Node runtime dependencies to core CLI |
| 3 | Add language detection in lib.sh | Hardcode NestJS-specific patterns in generic scripts |
| 4 | Create new Semgrep rules in rules/ | Use GNU-only sed/awk flags (use POSIX-compatible) |
| 5 | Enhance check-file.sh categories | Make PostToolUse hooks slower than 1 second |
| 6 | Add new skill .md files | Change the skill format (Trigger, Purpose, Steps, Output, Rules) |
| 7 | Add new cursor rule .mdc files | Remove the globs/description frontmatter from .mdc files |

## File Editing Rules

- **Templates** (`templates/*.template`): Use `{{placeholder}}` syntax from manifest keys
- **Skills** (`skills/*.md`): Follow format: `# Skill: Name`, `> Trigger:`, `> Purpose:`, then `## Step N:`
- **Cursor rules** (`cursor-rules/*.mdc`): YAML frontmatter with `description` + `globs`, then markdown
- **Semgrep rules** (`rules/*.yaml`): Standard Semgrep format with `rules:` array
- **Hooks** (`hooks/*`): Must be POSIX `/bin/sh` compatible, include inline manifest reader (no sourcing lib.sh)
- **Scripts** (`scripts/*.sh`): Source lib.sh at top, use `load_manifest_vars` for manifest access

## Commands for Development

```bash
# Validate kit structure (no unwanted files)
bash scripts/validate-structure.sh

# Test against fixture projects
bash tests/run-tests.sh

# Check a script for syntax errors
bash -n scripts/some-script.sh
```

## Competitive Positioning

Kit = **Superpower Prompts** (like Obra, but manifest-driven + multi-IDE) + **Code Review** (like CodeRabbit, but free + before-commit) + **Intent Verification** (like kluster.ai, but free + hook-based) + **Prevention Gates** (like Husky+Semgrep)

## Detailed Guidelines

- [Architecture](.claude/docs/architecture.md) — template engine, prevention stack, review pipeline, script dependencies
- [Conventions](.claude/docs/conventions.md) — shell style, BSD compat, skill/rule formats, adding commands/languages

## Anti-Patterns

- Do NOT add `npm install` or `pip install` to any core script — zero runtime dependencies
- Do NOT use `sed -i ''` (macOS) or `sed -i` (GNU) — use `sed -i.bak` then `rm *.bak` for BSD compatibility
- Do NOT add interactive prompts (`read -p`) to scripts that run in hooks — they hang
- Do NOT create files in project root during development — use appropriate subdirectories
- Do NOT commit `docs/product/` — it contains internal strategy docs (gitignored)
