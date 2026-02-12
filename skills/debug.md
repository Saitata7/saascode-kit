# Skill: Debug & Investigate

> Trigger: /debug [error-message|symptom|"crash"|"slow"|"404"|"500"]
> Purpose: Systematically investigate and resolve issues

## Step 1: Classify

| Symptom | Category | Start From |
|---------|----------|------------|
| 404 | Endpoint mismatch | Frontend API call → Controller route |
| 500 | Backend crash | Error logs → Service → DB query |
| 401/403 | Auth/permission | Guard chain → Roles → Token |
| Data wrong | Query/scope | Service → Prisma query → DB |
| Page blank | Frontend render | Component → API response → State |
| Slow | Performance | DB query → N+1 → Missing index |
| Build fail | Compilation | TS errors → Imports → Types |
| CORS | Config | Backend CORS → Allowed origins |
| Webhook fail | Integration | Signature → Payload → Handler |

## Step 2: Trace

**API errors (404/500/401/403):**
```bash
grep -rn "[keyword]" --include="*.ts" --include="*.tsx" [frontend]/src/lib/api/
grep -rn "[keyword]" --include="*.controller.ts" [backend]/src/modules/
grep -A10 "@Controller\|@Get\|@Post\|@Patch\|@Delete" [controller-file]
grep -A20 "[method-name]" [service-file]
grep -n "prisma\." [service-file]
```

**Data issues:**
```bash
grep -n "findMany\|findFirst\|findUnique" [service-file] | head -20
grep -A5 "findMany" [service-file]
grep -B5 -A10 "[model-name]" [schema-file]
```

**Frontend issues:**
```bash
cat [page-file]
grep -A10 "[function-name]" [api-client-file]
grep -n "response\.\|\.data" [page-file]
grep -n "useState\|useEffect\|loading\|error" [page-file]
```

**Build failures:**
```bash
npm run typecheck 2>&1 | head -50
grep -n "import" [error-file]
grep -rn "[missing-symbol]" --include="*.ts" --include="*.tsx" -l
```

## Step 3: Common Root Causes (80% of SaaS bugs)

1. **Endpoint parity (404)** — Frontend calls endpoint that doesn't exist in backend
2. **@Roles without RolesGuard** — Roles decorator silently ignored
3. **Unscoped query (data leak)** — findMany without tenantId
4. **Response unwrap** — `response` vs `response.data` (backend wraps in `{ success, data }`)
5. **Static vs dynamic route order** — `@Get('config')` must be BEFORE `@Get(':id')`
6. **Missing module registration** — New module not in app.module.ts imports

## Step 4: Verify Fix

```bash
npm run typecheck
npm --prefix [backend] run build
npm --prefix [backend] run test 2>/dev/null || echo "No tests"
```

## Step 5: Report

```markdown
## Debug Report
**Issue:** [original error]
**Root Cause:** [one sentence]
**Category:** [from table above]
**Trace:** [file:line] → [file:line] → [file:line]
**Fix:** [file:line] — before → after
**Verification:** TypeScript: PASS | Build: PASS
**Prevention:** [what check/rule would have caught this]
```

## Escalation

If root cause not found: check `git log --oneline -10`, try different branch, verify env vars, check external service status, ask user for repro steps.
