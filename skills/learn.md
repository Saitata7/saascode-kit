---
name: learn-pattern
description: Capture bug patterns and learnings into LEARNINGS.md, feeding fixes back into manifest patterns, Semgrep rules, checklists, skills, and context templates for self-improvement. Use when user says "learn from this", "remember this pattern", "add to learnings", or "/learn". Do NOT use for debugging active issues (use /debug instead).
---

# Skill: Self-Improvement

> Trigger: /learn [finding|"review"|"sync"]
> Purpose: Capture lessons and feed them back into the kit

## Modes

- `/learn [description]` — Capture one finding from current session
- `/learn review` — Scan recent git history for learnable moments
- `/learn sync` — Regenerate project files from updated manifest

## Step 1: Classify

| Type | Destination | Example |
|------|-------------|---------|
| Bug pattern | `manifest.yaml` → `patterns.critical` | Missing guard → auth bypass |
| Anti-pattern | `manifest.yaml` → `patterns.anti_patterns` | findMany without tenant scope |
| Semgrep rule | `rules/*.yaml` | Recurring catchable code pattern |
| Checklist item | `checklists/*.md` | New verification step needed |
| Skill update | `skills/*.md` | Missing check in /audit flow |
| Context update | `templates/*.template` | AI keeps making same mistake |

## Step 2: Validate

Only add if ALL true:
- [ ] Caused a real bug, security issue, or wasted significant time
- [ ] Not already covered by existing patterns/rules
- [ ] General enough to apply more than once
- [ ] Fix is clear and actionable

Skip: one-off mistakes, style preferences, theoretical vulnerabilities, framework bugs.

## Step 3: Apply

**Bug/Anti-pattern → manifest.yaml:**
```yaml
- id: "[short-id]"
  description: "[What goes wrong]"
  correct: "[Right way]"
  wrong: "[Wrong way]"
```

**Semgrep rule → rules/*.yaml:**

| Issue Type | File |
|-----------|------|
| Auth/permission | `rules/auth-guards.yaml` |
| Tenant data | `rules/tenant-isolation.yaml` |
| XSS, SQLi, secrets | `rules/security.yaml` |
| Input/DTO | `rules/input-validation.yaml` |
| Frontend/UI | `rules/ui-consistency.yaml` |

```yaml
- id: [descriptive-id]
  message: "[What's wrong. How to fix.]"
  severity: ERROR
  languages: [typescript]
  pattern: [code pattern to match]
```

**Checklist → checklists/*.md:** Add to feature-complete, security-review, or deploy-ready.

**Skill → skills/*.md:** Add check step or root cause to audit/build/debug/review.

**Context → templates/*.template:** Add to "Do NOT" section in CLAUDE.md/cursorrules.

## Step 4: Sync (`/learn sync`)

```bash
# Re-run setup or copy manually:
cp skills/*.md [project]/.claude/skills/
cp rules/*.yaml [project]/.saascode/rules/
cp checklists/*.md [project]/docs/checklists/
# Or: ./setup.sh [project-path]
```

## Step 5: Log

Append to `saascode-kit/LEARNINGS.md`:

```markdown
## [Date] — [Short Title]
**Found during:** /audit | /build | /debug | /review
**Severity:** CRITICAL | HIGH | MEDIUM
**What happened:** [One sentence]
**Root cause:** [One sentence]
**Added to:** [manifest | rules/file | checklists/file | skills/file]
```

## `/learn review`

```bash
git log --oneline -20 | grep -iE "fix|bug|hotfix|revert|patch|security"
git log --oneline -10 -- "*.controller.ts" "*.service.ts" "*.guard.ts"
git diff --name-only HEAD~10 | grep -E "auth|guard|webhook|middleware"
```

For each: Was it preventable? Would a rule have caught it? Worth adding? If yes → Step 2-5.

## Report

```markdown
| # | Type | Added To | Description |
|---|------|----------|-------------|
| 1 | Pattern | manifest.yaml | [description] |
| 2 | Rule | rules/security.yaml | [description] |
```

## Rules

1. Real bugs only — no theoretical patterns
2. No duplicates — check existing before adding
3. Actionable — every addition has a clear "correct" way
4. Logged — every learning in LEARNINGS.md with date and source
