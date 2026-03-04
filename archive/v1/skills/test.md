---
name: test-writer
description: Write unit and integration tests with Jest, Vitest, or Mocha, run test suite, and generate coverage reports with tenant isolation verification. Use when user says "write tests", "test this", "add tests", "coverage", or "/test". Do NOT use for test planning or QA strategy (manual process) or debugging (use /debug).
---

# Skill: Test Generator & Runner

> Trigger: /test [feature-name|"all"|"coverage"]
> Purpose: Write and run tests for features

## Modes

- `/test [feature]` — Write unit + integration tests
- `/test all` — Run full test suite
- `/test coverage` — Coverage report + untested code

## Step 1: Detect Setup

```bash
grep -E "jest|vitest|mocha|cypress|playwright" package.json */package.json 2>/dev/null
find . -name "jest.config*" -o -name "vitest.config*" | grep -v node_modules | head -5
find . \( -name "*.spec.ts" -o -name "*.test.ts" \) -not -path "*/node_modules/*" | head -10
```

Read 2-3 existing test files to match patterns, naming, imports.

## Step 2: Find What to Test

```bash
find . -name "[feature]*.service.ts" | grep -v node_modules
find . -name "[feature]*.controller.ts" | grep -v node_modules
find . -name "[feature]*.dto.ts" | grep -v node_modules
find . -name "[feature]*.tsx" -path "*/components/*" | grep -v node_modules
```

## Step 3: Write Tests

**Priority (test what breaks most):**

1. **Service unit tests** — happy path, error cases, edge cases, tenant isolation (verify tenantId in queries)
2. **Controller integration tests** — status codes, auth rejection, input validation, response shape
3. **Frontend component tests** — loading/error/data states, user interactions

**Naming:** `[name].service.spec.ts`, `[name].controller.spec.ts`, `[name].test.tsx`
**Placement:** co-located next to source files

## Step 4: Patterns

**Service test:**
```typescript
describe('FeatureService', () => {
  let service: FeatureService;
  let prisma: DeepMockProxy<PrismaClient>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        FeatureService,
        { provide: PrismaService, useValue: mockDeep<PrismaClient>() },
      ],
    }).compile();
    service = module.get(FeatureService);
    prisma = module.get(PrismaService);
  });

  it('should create with correct tenantId', async () => { /* ... */ });
  it('should throw on duplicate', async () => { /* ... */ });
});
```

**Controller test:**
```typescript
describe('FeatureController', () => {
  it('GET /feature → 200 with data', () =>
    request(app.getHttpServer()).get('/feature').set('Authorization', `Bearer ${token}`).expect(200));
  it('GET /feature → 401 without auth', () =>
    request(app.getHttpServer()).get('/feature').expect(401));
});
```

## Step 5: Run

```bash
if grep -q "vitest" package.json; then npx vitest run
elif grep -q "jest" package.json; then npx jest; fi

# Coverage
npx jest --coverage  # or npx vitest run --coverage
```

## Report

```markdown
| File | Tests | Pass | Fail |
|------|-------|------|------|
| feature.service.spec.ts | 8 | 8 | 0 |

| File | Statements | Branches | Lines |
|------|-----------|----------|-------|
| feature.service.ts | 92% | 85% | 91% |

Untested: [lines/branches not covered]
Failures: [test name → error → fix]
```

## Rules

1. Test behavior, not implementation
2. Mock external services (Prisma/HTTP), not internal logic
3. Tenant isolation mandatory — verify tenantId in every service test
4. Match existing test patterns in the project
5. Name tests as sentences: `it('should throw when tenant not found')`
