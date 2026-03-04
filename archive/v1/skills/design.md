---
name: design-document
description: Generate design documents for features, system architecture, UI wireframes, or API contracts. Use when user says "design doc", "architecture", "wireframe", "system design", or "/design". Do NOT use for product requirements (use /prd) or task breakdown (use /todo).
---

# Skill: Design Document Generator

> Trigger: /design [feature|"system"|"ui"|"api"]
> Purpose: Generate implementation-ready design documents — system architecture, UI wireframes, or API contracts

**What this generates:** A structured design document that bridges the gap between PRD and code. Covers architecture decisions, component breakdown, data flow, and UI structure.

**Output location:** `docs/designs/[feature]-design.md`

## Input

| Command | What It Produces |
|---------|-----------------|
| `/design [feature]` | Feature design doc (architecture + UI + API) |
| `/design system` | Full system architecture doc (services, data flow, infra) |
| `/design ui [feature]` | UI-focused design (wireframes, components, states) |
| `/design api [feature]` | API contract design (endpoints, schemas, versioning) |

## Step 1: Gather Context

Before designing, understand what exists:

1. **Read the codebase** — check existing patterns, modules, shared components
2. **Read PRD** — check `docs/product/product-brief.md` if it exists
3. **Read manifest** — check `saascode-kit.yaml` for stack, paths, patterns
4. **Identify constraints** — auth model, tenancy, existing API patterns, UI framework

Do NOT ask questions unless genuinely blocked. Make reasonable assumptions and note them.

## Step 2: Write the Design Doc

### For Feature Design (`/design [feature]`)

```markdown
# [Feature Name] — Design Document

> Status: Draft | Review | Approved
> Author: [auto]
> Date: [today]

## Overview

[1-2 sentences: what this feature does and why]

## Requirements

- [Functional requirement 1]
- [Functional requirement 2]
- [Non-functional: performance, scale, security]

## Architecture

### Data Model

| Entity | Fields | Relationships |
|--------|--------|---------------|
| [Name] | [key fields] | [references] |

### API Design

| Method | Endpoint | Auth | Request | Response |
|--------|----------|------|---------|----------|
| POST | /api/[resource] | [Role] | `{ field: type }` | `{ success, data }` |

### Component Tree

\```
[PageName]
├── [LayoutComponent]
│   ├── [HeaderComponent]
│   └── [ContentArea]
│       ├── [ListComponent]
│       │   └── [ItemCard] (repeating)
│       └── [EmptyState]
└── [ModalComponent] (conditional)
\```

### State Management

| State | Type | Source | Used By |
|-------|------|--------|---------|
| [items] | [Type[]] | API fetch | [Component] |
| [isLoading] | boolean | Derived | [Component] |

## Data Flow

\```
User Action → Component → API Client → Backend → Database
                                     ← Response ← Query
              Re-render ← State Update
\```

## Security Considerations

- [Auth requirements]
- [Tenant scoping]
- [Input validation]

## Edge Cases

- [What happens when X is empty?]
- [What happens when Y fails?]
- [What happens with concurrent Z?]

## Implementation Plan

| Order | Task | Files | Depends On |
|-------|------|-------|------------|
| 1 | Schema | [path] | — |
| 2 | Backend | [path] | Schema |
| 3 | API Client | [path] | Backend |
| 4 | UI | [path] | API Client |
```

### For System Design (`/design system`)

Include all of the above PLUS:

```markdown
## System Architecture

### Service Map

\```
[Client] → [CDN/Edge] → [Frontend Server]
                          ↓
                       [API Gateway/Backend]
                        ↓         ↓         ↓
                     [Database] [Cache]  [Queue]
                                          ↓
                                       [Workers]
\```

### Infrastructure

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Frontend | [from manifest] | [purpose] |
| Backend | [from manifest] | [purpose] |
| Database | [from manifest] | [purpose] |
| Cache | [from manifest] | [purpose] |

### Scaling Strategy

- [Horizontal: what can scale out]
- [Vertical: what needs bigger instances]
- [Caching: what to cache and where]

### Failure Modes

| Component | Failure | Impact | Mitigation |
|-----------|---------|--------|------------|
| Database | Down | Full outage | Replicas, health checks |
| Cache | Down | Slow responses | Fallback to DB |
```

### For UI Design (`/design ui [feature]`)

```markdown
## UI Design: [Feature]

### Screen Inventory

| Screen | Route | Purpose | Key Actions |
|--------|-------|---------|-------------|
| List | /[feature] | Browse all items | Create, Filter, Sort |
| Detail | /[feature]/[id] | View single item | Edit, Delete |
| Create | /[feature]/new | Add new item | Submit, Cancel |

### Wireframes (ASCII)

\```
┌─────────────────────────────────┐
│ Header                    [+New]│
├─────────────────────────────────┤
│ [Search...]  [Filter ▾] [Sort ▾]│
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ Item Title           Status │ │
│ │ Description...    [Actions] │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ Item Title           Status │ │
│ │ Description...    [Actions] │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ ← Prev    Page 1 of N   Next → │
└─────────────────────────────────┘
\```

### Component Breakdown

| Component | Props | States | Reusable? |
|-----------|-------|--------|-----------|
| [Name] | [key props] | loading, error, empty | Yes/No |

### User Flows

1. **Happy path**: [step → step → step → done]
2. **Error path**: [step → error → recovery]
3. **Empty state**: [what user sees when no data]
```

## Step 3: Review Checklist

Before finalizing, verify:

- [ ] Every API endpoint has auth specified
- [ ] Every data query is tenant-scoped (if multi-tenant)
- [ ] Every UI state is covered (loading, empty, error, success)
- [ ] Every edge case is documented
- [ ] Implementation order respects dependencies
- [ ] Design matches existing codebase patterns

## Output Rules

1. **Create `docs/designs/` directory** if it doesn't exist
2. **Use real names** — actual component names, route paths, field names from the codebase
3. **Match existing patterns** — if the project uses React Query, design with React Query; if it uses Redux, use Redux
4. **ASCII wireframes** — no external tools needed, readable in any editor
5. **Link to PRD** — reference product-brief.md if it exists
6. **No speculation** — if unsure about a technical choice, list options with trade-offs and recommend one
