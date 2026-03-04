---
name: preflight-check
description: Pre-deployment checklist covering build gates, tests, security, endpoint parity, and health checks. Use when user says "preflight", "ready to deploy", "pre-deploy check", or "/preflight". Do NOT use for full audit (use /audit) or deployment execution (use /deploy).
---

# Skill: Pre-Deploy Preflight Check

> Trigger: /preflight
> Purpose: Run all deployment gates and produce a release readiness report

## Instructions

You are a Senior DevOps Engineer. Verify ALL deployment gates with actual command output. Never assume a gate passes — run it and show evidence. Block deployment if any gate fails.

## Execution

### Run ALL Gates

```bash
# ========== BUILD VERIFICATION ==========
echo "=== BUILD ==="
npm --prefix {{paths.backend}} run build && echo "PASS: Backend build" || echo "FAIL: Backend build"
npm --prefix {{paths.frontend}} run build && echo "PASS: Frontend build" || echo "FAIL: Frontend build"
npm run typecheck && echo "PASS: TypeScript" || echo "FAIL: TypeScript"

# ========== TESTS ==========
echo "=== TESTS ==="
npm --prefix {{paths.backend}} run test && echo "PASS: Tests" || echo "FAIL: Tests"

# ========== SECURITY ==========
echo "=== SECURITY ==="
npm audit --audit-level=high && echo "PASS: No vulnerabilities" || echo "WARN: Vulnerabilities found"

# ========== ENDPOINT PARITY ==========
echo "=== ENDPOINT PARITY ==="
echo "Frontend:" && grep -E "apiClient\.(get|post|patch|delete)" {{paths.api_client}}/*.ts
echo "Backend:" && grep -E "@(Get|Post|Patch|Put|Delete)" {{paths.backend}}/src/modules/*/*.controller.ts

# ========== WEBHOOK VERIFICATION ==========
echo "=== WEBHOOKS ==="
API_URL="${API_URL:-http://localhost:{{project.port}}}"
{{#each integrations}}
{{#if this.has_webhooks}}
echo "{{this.name}}:" $(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/v1/webhooks/{{this.name}}" -d '{}')
{{/if}}
{{/each}}

# ========== HEALTH CHECK ==========
echo "=== HEALTH ==="
curl -s "$API_URL/health"

# ========== MIGRATION STATUS ==========
echo "=== MIGRATIONS ==="
cd {{paths.backend}} && npx prisma migrate status
```

### Smoke Test Checklist

**Auth & Context:**
- [ ] Login works for all roles
- [ ] Dashboard loads with correct data
- [ ] Tenant context displays correctly

**Core Features:**
- [ ] All list pages load
- [ ] Create/edit/delete operations work
- [ ] Billing page accessible (owner only)

**Integration Health:**
- [ ] API health check returns 200
- [ ] Webhook endpoints return 401 (correct without signature)
- [ ] Database connection stable

**Quality:**
- [ ] No console errors in browser
- [ ] No failed network requests
- [ ] Pages load in < 3 seconds

### Report

```markdown
## Preflight Report

### Gates
| Gate | Status |
|------|--------|
| Backend Build | PASS/FAIL |
| Frontend Build | PASS/FAIL |
| TypeScript | PASS/FAIL |
| Tests | PASS/FAIL (X/Y passing) |
| Security Scan | PASS/WARN |
| Endpoint Parity | PASS/FAIL |
| Webhooks | PASS/FAIL |
| Health Check | PASS/FAIL |
| Migrations | PASS/FAIL |

### Rollback Plan
- Frontend: Revert to [previous deployment]
- Backend: Revert to [previous image]
- Database: [rollback SQL if migration applied]

### Status: APPROVED / BLOCKED
### Blockers: [list if any]
```

## Decision Matrix

| Symptom | Severity | Action |
|---------|----------|--------|
| Site completely down | CRITICAL | Immediate rollback < 5 min |
| Auth broken | CRITICAL | Immediate rollback < 5 min |
| Data corruption | CRITICAL | Rollback + restore backup < 15 min |
| Major feature broken | HIGH | Rollback or hotfix < 1 hour |
| Performance degraded > 50% | HIGH | Investigate, rollback if needed |
| Minor bug | MEDIUM | Hotfix next release |
| Cosmetic issue | LOW | Fix in backlog |
