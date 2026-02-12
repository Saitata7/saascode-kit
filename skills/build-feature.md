# Skill: Build Feature End-to-End

> Trigger: /build [feature-name]
> Purpose: Build a complete feature with self-verification

**FIRST:** Read `.claude/context/project-map.md` AND `.claude/context/golden-reference.md`. Copy patterns from golden reference.

## Phase 1: Discovery

1. What problem? Who uses it? What scope (CRUD, read-only, wizard)?
2. Tenant-scoped or global? New module or extending existing? Third-party integrations?
3. Ask if ambiguous — don't assume.

## Phase 2: Context

Cross-reference project-map.md:
- **Models** — exists? need new one?
- **Endpoints** — route conflicts?
- **Components** — reusable ones available?
- **API Client** — file exists for this feature?

Only read source files if project-map doesn't answer the question.

## Phase 3: Architecture

Present plan, get approval:

```markdown
## Feature: [Name]
### Scope: [Tenant|Admin|Public] — [one sentence goal] — Roles: [who]
### Data Model
| Field | Type | Required | Notes |
### API Endpoints
| Method | Route | Roles | Description |
### UI Pages
| Route | Shows | Components |
### Dependencies: [reusing] + [creating]
```

Wait for approval. If small/obvious, note plan and proceed.

## Phase 4: Implementation (MANDATORY ORDER)

```
1. Schema        → Add/modify models
2. DTOs          → Input validation
3. Service       → Business logic, ALL queries scoped by tenant
4. Controller    → Endpoints with guard chain
5. Module        → Register in app.module
6. API Client    → Typed functions matching every endpoint
7. Components    → Reusable pieces
8. Pages         → Loading/empty/error states
```

Copy from golden-reference.md. Don't generate patterns from scratch.

## Phase 5: Validate (BEFORE showing results)

```bash
# After schema
cd apps/api && npx prisma validate

# After backend
npx --prefix apps/api nest build 2>&1 | head -30

# After frontend
npx --prefix apps/portal tsc --noEmit 2>&1 | grep "error TS" | head -20

# Endpoint parity
grep -cE "apiClient\.(get|post|put|patch|delete)" apps/portal/src/lib/api/[feature].ts
grep -cE "@(Get|Post|Patch|Put|Delete)" apps/api/src/modules/[feature]/*.controller.ts
```

**Security checklist (verify silently):**
- Guard chain: `@UseGuards(ClerkAuthGuard, TenantGuard, RolesGuard)`
- `@Roles()` on every endpoint
- All queries include tenantId
- Ownership verified after findUnique
- Static routes before dynamic
- Module registered in app.module.ts

**Frontend checklist:** loading skeleton, empty state, error+retry, toast on mutations.

Fix errors silently before presenting. Never show code that doesn't compile.

## Phase 6: Summary

```markdown
## Feature Complete: [Name]
### Files: Created X, Modified Y
| Check | Status |
|-------|--------|
| Prisma validate | PASS |
| Backend build | PASS |
| Frontend typecheck | PASS |
| Endpoint parity | X ↔ X |
| Guard chain | Present |
| Tenant scoping | All scoped |
### Manual test: [1. Login as OWNER...] [2. Login as MEMBER...]
```

## Output Rules

- No comments in code unless logic is non-obvious
- No explanations between code blocks
- Use Edit (changes only) over Write (full file) for existing files
- Skip narratives — summary table is enough

## Stop Conditions (ask first)

Schema migrations, auth/permission changes, billing integration, breaking API changes, core model changes, touches 3+ existing modules.
