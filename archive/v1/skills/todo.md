---
name: task-planner
description: Break down features into ordered implementation tasks with acceptance criteria, dependencies, and estimates. Use when user says "break this down", "task list", "plan tasks", "sprint plan", "todo", or "/todo". Do NOT use for product requirements (use /prd) or design decisions (use /design).
---

# Skill: Task Breakdown & Planning

> Trigger: /todo [feature|milestone|"sprint"]
> Purpose: Break down work into actionable, ordered tasks with estimates and dependencies — from feature spec to implementation checklist

**What this generates:** A structured task list ready for a project board (Linear, GitHub Issues, Jira). Each task has clear scope, acceptance criteria, and dependency links.

**Output location:** `docs/tasks/[feature]-tasks.md` or direct output for quick breakdowns

## Input

| Command | What It Produces |
|---------|-----------------|
| `/todo [feature]` | Break a feature into implementation tasks |
| `/todo sprint` | Plan a sprint from existing TODOs, issues, or PRD |
| `/todo [milestone]` | Break a milestone into feature-sized chunks |
| `/todo estimate` | Add effort estimates to existing task list |

## Step 1: Understand the Scope

1. **Read PRD** — check `docs/product/product-brief.md` for requirements
2. **Read design doc** — check `docs/designs/` for architecture decisions
3. **Read codebase** — understand existing patterns, what exists vs what's new
4. **Read manifest** — check stack, paths, build order conventions

If no PRD or design doc exists, ask the user to describe what needs to be built (or suggest running `/prd` or `/design` first).

## Step 2: Break Down Tasks

### For Feature Breakdown (`/todo [feature]`)

```markdown
# [Feature Name] — Task Breakdown

> Total tasks: [N]
> Estimated effort: [X days/hours]
> Dependencies: [list any blockers]

## Tasks

### Phase 1: Data Layer
- [ ] **[FEAT-001] Create [Entity] schema** — [S]
  - Add model to schema file with fields: [list]
  - Add migration
  - Acceptance: `prisma validate` / `migrate dev` passes
  - Depends on: —

- [ ] **[FEAT-002] Create [Entity] DTOs** — [S]
  - Create/Update/Response DTOs with validation
  - Acceptance: All fields validated, types match schema
  - Depends on: FEAT-001

### Phase 2: Backend
- [ ] **[FEAT-003] Create [Entity] service** — [M]
  - CRUD operations, tenant-scoped queries
  - Business logic: [specific rules]
  - Acceptance: All queries scoped by tenantId, ownership verified
  - Depends on: FEAT-002

- [ ] **[FEAT-004] Create [Entity] controller** — [M]
  - REST endpoints with auth guards
  - Acceptance: Guard chain on every endpoint, roles specified
  - Depends on: FEAT-003

- [ ] **[FEAT-005] Register module** — [S]
  - Add to app.module.ts imports
  - Acceptance: `nest build` passes
  - Depends on: FEAT-004

### Phase 3: Frontend
- [ ] **[FEAT-006] Create API client functions** — [S]
  - Typed functions for each endpoint
  - Acceptance: Types match backend DTOs, all endpoints covered
  - Depends on: FEAT-004

- [ ] **[FEAT-007] Create [Feature] list page** — [M]
  - Loading, empty, error states
  - Pagination/filtering if needed
  - Acceptance: All 3 states render correctly
  - Depends on: FEAT-006

- [ ] **[FEAT-008] Create [Feature] detail/form page** — [M]
  - Create and edit modes
  - Form validation matching backend DTOs
  - Acceptance: Form submits successfully, validation errors shown
  - Depends on: FEAT-006

### Phase 4: Polish
- [ ] **[FEAT-009] Add tests** — [M]
  - Unit tests for service logic
  - Integration test for API endpoints
  - Acceptance: `npm test` passes, critical paths covered
  - Depends on: FEAT-005

- [ ] **[FEAT-010] Endpoint parity check** — [S]
  - Run `saascode parity`
  - Acceptance: Every frontend call has matching backend endpoint
  - Depends on: FEAT-008
```

### For Sprint Planning (`/todo sprint`)

```markdown
# Sprint [N] — Task Plan

> Sprint goal: [one sentence]
> Capacity: [X story points / days]
> Duration: [start] → [end]

## Priorities

### Must Have (P0)
- [ ] **[ID]** [Task name] — [S/M/L] — [assignee]
- [ ] **[ID]** [Task name] — [S/M/L] — [assignee]

### Should Have (P1)
- [ ] **[ID]** [Task name] — [S/M/L] — [assignee]

### Nice to Have (P2)
- [ ] **[ID]** [Task name] — [S/M/L] — [assignee]

## Dependency Graph

\```
[Task A] ──→ [Task B] ──→ [Task D]
                 ↓
[Task C] ──→ [Task E]
\```

## Risk Items

| Risk | Impact | Mitigation |
|------|--------|------------|
| [risk] | [high/medium/low] | [plan] |

## Carry-over from Last Sprint

- [ ] [Incomplete task from previous sprint]
```

### For Milestone Breakdown (`/todo [milestone]`)

```markdown
# [Milestone Name] — Feature Breakdown

> Target date: [date]
> Features: [N]

## Features (ordered by dependency)

### 1. [Feature A] — [effort estimate]
- [1-2 sentence scope]
- Key tasks: [3-5 high-level tasks]
- Depends on: —

### 2. [Feature B] — [effort estimate]
- [1-2 sentence scope]
- Key tasks: [3-5 high-level tasks]
- Depends on: Feature A (schema)

### 3. [Feature C] — [effort estimate]
- [1-2 sentence scope]
- Key tasks: [3-5 high-level tasks]
- Depends on: Feature A, Feature B

## Timeline

\```
Week 1: [Feature A - data layer + backend]
Week 2: [Feature A - frontend] + [Feature B - data layer]
Week 3: [Feature B - full] + [Feature C - start]
Week 4: [Feature C - complete] + [Testing + Polish]
\```
```

## Step 3: Estimate (if requested)

Use T-shirt sizes mapped to hours:

| Size | Meaning | Hours | Example |
|------|---------|-------|---------|
| **S** | Single file, clear scope | 1-2h | Add a DTO, create API client function |
| **M** | Multiple files, some decisions | 3-6h | Build a service with business logic, create a page |
| **L** | Cross-cutting, needs design | 6-12h | New module end-to-end, complex UI flow |
| **XL** | Multi-day, risky | 12-24h | New auth system, major refactor |

## Output Rules

1. **Create `docs/tasks/` directory** if it doesn't exist
2. **Every task must be independently implementable** — clear inputs and outputs
3. **Every task must have acceptance criteria** — how to know it's done
4. **Dependencies must be explicit** — no hidden ordering assumptions
5. **Use the project's build order** — schema → backend → frontend (from manifest conventions)
6. **Match task granularity to team** — solo dev gets bigger tasks, team gets smaller ones
7. **Include verification tasks** — `saascode review`, `saascode parity`, tests
8. **Prefix task IDs** — use feature abbreviation for easy filtering (FEAT-001, AUTH-001, etc.)

## Anti-Patterns

- Do NOT create tasks like "Set up project" — too vague
- Do NOT create 50 micro-tasks for a simple CRUD — group logically
- Do NOT skip acceptance criteria — every task needs a "done" definition
- Do NOT ignore dependencies — a task that blocks 5 others should be first
- Do NOT estimate without understanding the codebase — read first, estimate second
