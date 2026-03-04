---
name: code-review
description: Code review covering security, quality, tenant isolation, AI safety, and endpoint parity. Use when user says "review", "PR review", "code review", "check my code", or "/review". Do NOT use for full security audit (use /audit) or pre-deploy checks (use /preflight).
---

# Skill: PR Code Review

> Trigger: /review [pr-number|file-path|"staged"]
> Purpose: Review code changes for security, quality, and correctness

**FIRST:** Read `.claude/context/project-map.md` for endpoints, models, patterns.

**Confidence scoring:** Only report findings with confidence >= 70.

| Confidence | Meaning | Action |
|-----------|---------|--------|
| 90-100 | Certain bug/security hole | CRITICAL |
| 70-89 | Strong evidence of issue | WARNING |
| < 70 | Uncertain | Skip |

## Step 0: AST Review (automated)

```bash
# Full scan:
npx tsx saascode-kit/scripts/ast-review.ts

# Changed files only (PR reviews):
npx tsx saascode-kit/scripts/ast-review.ts --changed-only
```

Include AST output in report. Checks: guard chains, @Roles/@Public, tenant scoping, empty catch, console.log, raw SQL, secrets.

## Step 0.5: Load Product Context

Read `saascode-kit/manifest.yaml` (or `.saascode/manifest.yaml`) to determine which checks apply:

| Manifest Key | Value | Effect |
|-------------|-------|--------|
| `tenancy.enabled` | `false` | SKIP all tenant isolation checks in Steps 3-4 |
| `tenancy.identifier` | e.g. `tenantId` | Use this field name instead of hardcoded "tenantId" |
| `ai.enabled` | `true` | ADD AI/LLM security checks to Step 3 |
| `stack.backend` | empty | SKIP backend checks (.service.ts, .controller.ts) |
| `stack.frontend` | empty | SKIP frontend checks (.tsx) |

**If manifest not found:** Run all checks with defaults (tenantId, no AI checks).

## Step 1: Get Changes

```bash
# Staged: git diff --cached
# PR:     gh pr diff [pr_number]
# All:    git diff
```

## Step 2: Cross-Reference Project Map

- New controller → guard chain pattern?
- New API calls → matching backend endpoints exist?
- New model fields → {tenancy.identifier} present? *(only if tenancy.enabled=true)*
- New page → loading/empty/error states?

## Step 3: Security Check

**Backend (.service.ts, .controller.ts) — skip if no stack.backend:**
- Guard chain present (conf: 95 if missing)
- No raw SQL with interpolation (conf: 99)
- No hardcoded secrets (conf: 99)
- No sensitive data in logs (conf: 90)

**Tenant Isolation (only if tenancy.enabled=true — skip otherwise):**
- Queries scoped by {tenancy.identifier} (conf: 95 if missing)
- Ownership verified after findUnique (conf: 90)
- No unscoped queries returning multi-tenant data (conf: 95)

**Frontend (.tsx) — skip if no stack.frontend:**
- No dangerouslySetInnerHTML with user input (conf: 95)
- response.data unwrap correct
- No API keys in frontend (conf: 99)

**AI/LLM Security (only if ai.enabled=true in manifest — skip otherwise):**
- Prompt injection: user input interpolated directly into prompts (conf: 95)
- System prompt exposure in API responses (conf: 95)
- LLM output used in eval() or dangerouslySetInnerHTML (conf: 99)
- AI endpoints without rate limiting / @Throttle() (conf: 85)
- Hardcoded model names instead of config constants (conf: 75)
- AI API calls without error handling (try/catch) (conf: 80)
- AI API calls without timeout / AbortController (conf: 80)
- PII/credentials sent to external AI providers (conf: 90)
- Embedding calls inside loops instead of batched (conf: 75)
- AI-generated content written to DB without validation (conf: 85)
- Streaming responses without error/close event handlers (conf: 80)

**Schema:** tenantId on tenant models | Indexes | Cascade deletes *(skip tenant checks if tenancy.enabled=false)*

## Step 4: Quality Check

Console.log (conf: 80) | Empty catch blocks | Endpoint parity | Static before dynamic routes | Module registered

## Step 5: Report

```markdown
## Code Review: [PR/Change]
### Summary
- **Verdict**: APPROVE | REQUEST CHANGES | COMMENT
- **Issues**: X critical, Y warnings | **Files**: Z
- **Product type**: [SDE | SDE+AI] (from manifest)

### Findings (confidence >= 70 only)
| # | File:Line | Severity | Confidence | Issue | Fix |
|---|-----------|----------|------------|-------|-----|

### Clean Files
- file1.ts
```

## Rules

1. Project map before judging — don't guess
2. Read manifest to determine product type — don't check for things that don't apply
3. Confidence >= 70 or skip
4. Security first — auth, tenant isolation, secrets, AI safety
5. Be specific — exact line, exact fix
6. Don't flag style — if the codebase does X, X is correct
7. No prose for clean files — just list them
8. Table format only for findings
