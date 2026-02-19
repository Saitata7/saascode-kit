---
name: security-audit
description: Run security and quality audit covering auth bypass, tenant data leaks, XSS, SQL injection, hardcoded secrets, unvalidated DTOs, and dependency vulnerabilities. Use when user says "audit", "security scan", "check vulnerabilities", or "/audit". Do NOT use for code review of specific changes (use /review instead).
---

# Skill: Security & Quality Audit

> Trigger: /audit [feature-name|module-name|"full"]
> Purpose: Security and quality audit on specified scope

**Read actual files. Never assume.**

## Step 1: Auto-Scan (run ALL before manual review)

```bash
# Auth guard — @Roles without RolesGuard (silently ignored!)
grep -rn "@Roles(" --include="*.ts" -B10 apps/api/src/modules/{{feature}}/ | grep -B10 "@Roles" | grep -v "RolesGuard"

# Unscoped queries (tenant data leak)
grep -rn "findMany()" --include="*.service.ts" apps/api/src/modules/{{feature}}/ | grep -v "tenantId"

# XSS
grep -rn "dangerouslySetInnerHTML" --include="*.tsx" apps/portal/src/

# SQL Injection
grep -rn "\$queryRaw\|\$executeRaw" --include="*.ts" apps/api/src/

# Hardcoded secrets
grep -rn "password\s*=\|secret\s*=\|api[_-]?key\s*=" --include="*.ts" apps/api/src/ | grep -v "process.env\|@Is\|interface\|type "

# Sensitive data in logs
grep -rn "console.log.*token\|console.log.*secret\|console.log.*password" --include="*.ts" apps/api/src/

# DTOs without validation
find apps/api/src/modules -name "*.dto.ts" -exec grep -L "@Is" {} \;

# Dependency vulnerabilities
npm audit --audit-level=high
```

## Step 2: Manual Review Checklist

**Backend:** Guard chain on all controllers | Queries scoped by tenantId | Ownership after findUnique | DTOs validated | Static routes before dynamic | Framework exceptions

**Frontend:** Loading/empty/error states | Role-based UI | response.data unwrap | Form validation | Toast on mutations

**Database:** Indexes on query columns | Unique constraints | Cascade deletes

## Step 3: Report

```markdown
## Audit Report: [Feature/Module]
### Summary
- Status: PASS | FAIL (X issues)
- Risk: CRITICAL | HIGH | MEDIUM | LOW

### Findings
| # | Issue | Severity | File:Line | Status |
|---|-------|----------|-----------|--------|

### Fixes Applied
1. file.ts:15 — Before → After

### Verification
- typecheck: PASS/FAIL
- build: PASS/FAIL
```

## Severity

- **CRITICAL** (9-10): Auth bypass, data leak, injection → Fix immediately
- **HIGH** (7-8.9): Privilege escalation, XSS → Fix within 24h
- **MEDIUM** (4-6.9): Info disclosure, missing limits → Fix within week
- **LOW** (0-3.9): Minor config, cosmetic → Backlog
