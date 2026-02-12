# Skill: Prompt Recipes

> Trigger: /recipe [recipe-name]
> Purpose: Pre-built prompt templates for common tasks — fill in the blanks, get working code

## Instructions

Show the user the matching recipe template. If no recipe name given, list all available recipes. The user fills in the blanks, then you execute using the golden-reference patterns.

**FIRST:** Read `.claude/context/project-map.md` to check existing models/endpoints before generating.

## Recipes

### /recipe crud
**Use when:** Adding a full new feature with list, create, read, update, delete

```
Feature: [NAME]
Model fields: [field1:type, field2:type, ...]
Tenant-scoped: yes
Roles:
  - Read: OWNER, ADMIN, MANAGER, MEMBER
  - Write: OWNER, ADMIN
  - Delete: OWNER
UI: list page + create form
```

**Execution:** Read golden-reference.md → Build in order: Schema → Service → Controller → Module → API Client → Page. Validate after each layer.

---

### /recipe endpoint
**Use when:** Adding a new API endpoint to an existing module

```
Module: [existing-module-name]
Method: GET | POST | PUT | PATCH | DELETE
Route: /[path]
Roles: [OWNER, ADMIN, ...]
Input: [DTO fields or "none"]
Returns: [shape]
Tenant-scoped: yes | no
```

**Execution:** Check project-map.md for existing routes on this module → Add to service → Add to controller → Add to API client → Verify parity.

---

### /recipe page
**Use when:** Adding a new frontend page

```
Route: /[dashboard-path]
Data source: [which API client method(s)]
States: loading skeleton, empty "[message]", error with retry
Actions:
  - [action1] → [role restriction]
  - [action2] → [role restriction]
Components: [list what to reuse from project-map, what's new]
```

**Execution:** Check project-map.md Components section → Create page with 3 states → Wire to API client → Add toast notifications.

---

### /recipe connect
**Use when:** Connecting a frontend page to a backend endpoint that already exists

```
Frontend file: [path to .tsx]
API client file: [path to api/*.ts]
Endpoint: [METHOD /route]
Data shape: [what the endpoint returns]
Action: [what triggers the call — button click, page load, form submit]
```

**Execution:** Add method to API client if missing → Import in page → Wire to UI event → Add loading state + error handling + toast.

---

### /recipe form
**Use when:** Adding a form (create or edit)

```
Purpose: create | edit [what]
Fields:
  - [name]: [type] [required?] [validation?]
  - [name]: [type] [required?] [validation?]
Submit endpoint: [METHOD /route]
On success: [redirect to /path | close modal | refresh list]
Roles: [who can see this form]
```

**Execution:** Create form component with controlled inputs → Add validation → Wire to API client → Add loading state on submit button → Toast on success/error.

---

### /recipe modal
**Use when:** Adding a confirmation or action modal

```
Trigger: [what opens it — button click, delete action]
Title: "[modal title]"
Message: "[confirmation message]"
Actions:
  - Confirm: [what happens] → [style: destructive | primary]
  - Cancel: close modal
API call: [METHOD /route] on confirm
```

**Execution:** Use ConfirmDialog component from project-map → Wire trigger → Handle API call → Toast result.

---

### /recipe settings
**Use when:** Adding a new settings section

```
Settings key: [TenantSettingKey value]
Fields:
  - [name]: [type] [default]
  - [name]: [type] [default]
Read endpoint: GET /tenants/:tenantId/settings/[key]
Save endpoint: PATCH /tenants/:tenantId/settings/[key]
Roles: OWNER, ADMIN
```

**Execution:** Check settings.controller.ts for existing pattern → Add to settings service → Add PATCH endpoint → Create settings page section → Wire save with toast.

## Output Rules

- Show the recipe template first, let user fill blanks
- If user provides all info upfront, skip template and execute directly
- Always check project-map.md before creating (avoid duplicates)
- Use Edit tool for existing files, Write only for new files
- Validate after implementation (build check)
