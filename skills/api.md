# Skill: API Documentation

> Trigger: /api [module-name|"all"|"postman"]
> Purpose: Generate API reference from controllers

## Modes

- `/api` or `/api all` — Full API reference
- `/api [module]` — Single module endpoints
- `/api postman` — Postman-importable JSON collection

## Step 1: Discover

```bash
find . -name "*.controller.ts" -not -path "*/node_modules/*"
grep -rn "@\(Get\|Post\|Put\|Patch\|Delete\)\|@Controller" --include="*.controller.ts"
find . -name "*.dto.ts" -not -path "*/node_modules/*"
```

## Step 2: Extract Per Controller

For each controller, read and extract:
1. `@Controller('path')` → base route
2. Each `@Get/@Post/@Patch/@Delete` → method + sub-route
3. `@UseGuards(...)` → auth requirements
4. `@Roles(...)` → required roles
5. `@Param/@Body/@Query` → parameters
6. DTO type → read DTO file for fields, types, validation

## Step 3: Format Per Endpoint

```markdown
### Create Phone Number
`POST /v1/phone-numbers`
**Auth:** ClerkAuthGuard + TenantGuard | **Roles:** OWNER, ADMIN

**Request Body:**
| Field | Type | Required | Validation |
|-------|------|----------|------------|
| phoneNumber | string | Yes | E.164 format |

**Response:** `201`
```json
{ "success": true, "data": { "id": "uuid", "phoneNumber": "+15551234567" } }
```

**Errors:** 400 (invalid input), 401 (no auth), 403 (wrong role), 409 (duplicate)
```

## Step 4: Full Reference

```markdown
# API Reference
Base URL: `http://localhost:4000/v1`
Auth: `Authorization: Bearer <clerk-session-token>`

## [Module Name]
| Method | Route | Description | Roles |
|--------|-------|-------------|-------|
[Detailed docs per endpoint below]
```

Write to `docs/api-reference.md`.

## Step 5: Postman (`/api postman`)

Generate valid JSON with auth variables and all endpoints. Save to `docs/api/postman-collection.json`.

## Report

```markdown
| Module | Endpoints | Roles Used |
|--------|-----------|------------|
| phone-numbers | 8 | OWNER, ADMIN |
Total: X endpoints across Y modules
Missing: [endpoints without DTOs or return types]
```

## Rules

1. Extract from code — never guess fields or types
2. Include auth + roles on every endpoint
3. Show realistic example values
4. Document error responses (400/401/403/404/409)
5. Group by module matching backend structure
