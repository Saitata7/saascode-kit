# Skill: Product Brief Generator

> Trigger: /prd or /prd [idea]
> Purpose: Generate a complete, implementation-ready Product Brief

**What this generates:** A single-file Product Brief — everything needed before writing code. One file. Every entity, rule, state, and flow — traced and connected.

**Output location:** `docs/product/product-brief.md`

## Input

| Command | Source |
|---------|--------|
| `/prd` | **Existing project** — analyze codebase (schemas, routes, models) |
| `/prd "idea"` | **New idea** — generate from description |

**No idea:** Read the project's database schemas, route handlers, models, middleware, and UI pages. Extract entities, relationships, rules, and flows from the actual code.

**With idea:** Generate entities, relationships, rules, and flows from the description. Make reasonable assumptions.

## How It Works

Work through each section IN ORDER. Each section builds on the previous one:

```
idea → Problem & Solution → Entities → Relationships → Domain Rules → State Machines → Core Flow → Build Order
```

**Every entity must appear in relationships. Every status must have a state machine. Nothing orphaned.**

## Execution

### Step 0: Understand the Idea

Before writing anything, determine:

1. **Scale**: Full platform (multiple roles, complex workflows) or focused tool (single purpose)?
2. **Domain**: What industry? (legal, health, fintech, e-commerce, devtools, etc.)
3. **Core actors**: Who are the 2-4 main user types?
4. **Core transaction**: What is the ONE thing that flows through the system? (case, order, booking, project, ticket, etc.)

Do NOT ask questions. Make reasonable assumptions based on the idea and note them in the Problem section. The user will correct anything wrong.

### Step 1: Write the Header

```markdown
# [Product Name] — Product Brief

Everything you need to understand before code. One file.

---
```

### Step 2: Problem & Solution

Write exactly 2 sections:

```markdown
## Problem

[2-4 bullet points. Each states a real pain point for a specific actor. No fluff. No "currently..." — state the pain directly.]

## Solution

[2-4 bullet points. Each directly answers a problem above. Include the core mechanism (AI-matched, escrow-protected, automated, etc.)]
[Last bullet: the full lifecycle in one line — "Full lifecycle: submit → match → deliver → complete"]
```

**Rules:**
- Every solution bullet must map to a problem bullet
- Include the core differentiator (what makes this not just another CRUD app)
- The lifecycle line defines the Core Flow you'll detail in Step 7

### Step 3: Entities & Fields

This is the data model. List EVERY entity the system needs.

```markdown
## 1. Entities & Fields

### [EntityName]
- id, [field]: [type], [field]: [type]
- **[important_field]**: `ENUM_A` | `ENUM_B` | `ENUM_C` — [why this matters]
- [foreignKey] → [RelatedEntity]
- [computed_field] ([how it's calculated])
```

**Rules:**
- Start with User/Account entity (every system has users)
- Group fields: identifiers first, then data fields, then status/state fields, then metadata
- Mark optional fields with `?`
- Mark important/non-obvious fields with `**bold**` and explain WHY
- Include enums inline: `status: \`DRAFT\` | \`ACTIVE\` | \`COMPLETED\``
- Show foreign keys as `fieldName → Entity`
- Add computed/derived fields with calculation note
- Mark v2 entities with `(v2 — data model ready, UI later)` if the idea is complex
- For focused tools: 3-8 entities is normal
- For full platforms: 10-25 entities is normal
- Include supporting entities (auth, audit, logging) in a grouped section at the end

**Quality check:** Can a developer create database tables from this? If not, add more detail.

### Step 4: Relationships

Map how every entity connects.

```markdown
## 2. Relationships

\```
User ──1:1──→ Profile          (if role = X)
User ──1:many→ [CoreEntity]    (as creator)
[CoreEntity] ──1:many→ [SubEntity]
[CoreEntity] ──1:1──→ [LinkedEntity]
[Entity].field ──matches→ [Entity].field  (matching/filtering signal)
\```
```

**Rules:**
- Use exact notation: `──1:1──→`, `──1:many→`, `──many:many→`, `──many:1──→`
- Add context in parentheses: `(if role = X)`, `(optional, null = default)`, `(only 1 active at a time)`
- Show ownership chains: who owns what
- Show matching/filtering relationships (field X is used to find field Y)
- Every entity from Step 3 MUST appear here. If an entity has no relationships, it shouldn't exist.

**Quality check:** Draw this as an ER diagram in your head. Are there orphaned entities? Missing connections?

### Step 5: Domain Rules

These are the business rules — the constraints that make the system correct.

```markdown
## 3. Domain Rules

**[Category]:**
- [Rule in plain English]
- [Rule with specific constraint]: `value <= otherValue`
- [Rule with actor]: Only [ROLE] can [action]
- [Rule with condition]: If [condition] then [consequence]
```

**Rules:**
- Group by entity or domain concept (Users, Cases, Payments, Matching, etc.)
- Write rules as constraints, not features: "X must be true" not "X can do Y"
- Include data constraints: uniqueness, required combos, value limits
- Include access rules: who can do what
- Include timing rules: expiry, auto-actions, windows
- Include financial rules: if applicable (escrow, fees, splits)
- Include compliance rules: if applicable (GDPR, HIPAA, PCI, etc.)
- Every enum value from Step 3 should have rules governing its behavior
- Mark critical rules that affect architecture

**Quality check:** If a junior developer reads only this section, would they know what's NOT allowed?

### Step 6: State Machines

Every entity with a `status` field gets a state machine.

```markdown
## 4. State Machine

### [Entity] Lifecycle
\```
STATE_A ──→ STATE_B ──→ STATE_C ──→ STATE_D (terminal)
  │                         │
  ▼                         ▼
STATE_E (terminal)      STATE_F ──→ STATE_D (via resolution)
\```

| From | To | Who | Trigger |
|------|-----|-----|---------|
| STATE_A | STATE_B | System/User/Admin | [What causes this transition] |
| STATE_B | STATE_C | System | [Auto-trigger or user action] |
```

**Rules:**
- ASCII diagram FIRST (visual), then transition table (precise)
- Show terminal states clearly: `(terminal)` — no transitions out
- Show who triggers each transition (System, User role, Admin, Auto)
- Show pause/hold states if applicable
- Include sub-lifecycles for important sub-entities (milestones, payments, etc.)
- Every status enum from Step 3 MUST appear in a state machine
- If an entity has a status field but no state machine, either add the machine or remove the status

**Quality check:** Can a developer implement a `canTransition(from, to, actor)` function from this?

### Step 7: Core Flow

The happy path — how the system works when everything goes right.

```markdown
## 5. Core Flow

\```
ACTOR_A                   PLATFORM                   ACTOR_B
──────                    ────────                   ──────
Action                →    Process
                           (detail)

                           Action                 →   Receives
                                                  ←   Responds

Next action           →    Process                →   Result
\```
```

**Rules:**
- 3-column format: primary actor | platform/system | secondary actor
- Use arrows: `→` (sends to), `←` (receives from)
- Show the MINIMUM steps from start to completion
- Add sub-flows for important alternative paths (dispute, cancellation, error)
- This flow should match the lifecycle line from Step 2

**Quality check:** If you follow this flow step by step, does the core entity reach its terminal state?

### Step 8: Build Order

Implementation sequence respecting dependencies.

```markdown
## Build Order

\```
1. Auth        →  [what's included]
2. [Entity]    →  [what's included]
3. [Flow]      →  [what's included]
4. [Feature]   →  [what's included]
...
\```
```

**Rules:**
- Each step depends on the previous ones
- Auth is always first
- Core entities before flows that use them
- Backend before frontend for each step
- Admin/dashboard last (it observes everything else)
- 5-8 steps for a focused tool, 7-12 for a platform

### Step 9: Closing Line

```markdown
---

*This is the complete picture. Everything else is detail.*
```

## Output Rules

1. **One file only** — everything in `docs/product/product-brief.md`
2. **Create `docs/product/` directory** if it doesn't exist
3. **No fluff** — every line must be useful for implementation
4. **No "TODO"** — if you're unsure about something, make a reasonable assumption and note it
5. **Use real field names** — camelCase, ready for code (`firstName` not "First Name")
6. **Use real enum values** — UPPER_SNAKE, ready for code (`IN_PROGRESS` not "In Progress")
7. **Consistent references** — if you name an entity `Case`, always call it `Case`, never "case" or "cases"
8. **Supporting entities section** — group auth, audit, logging entities at the end of Step 3
9. **Domain-specific compliance** — if the domain has regulations (legal, health, finance), call them out in Domain Rules

## Optional Section: AI Agents

**Only include if the idea involves AI, automation, matching, classification, or prediction.**

```markdown
## 6. AI Agents

[N] agents power the platform. v1 uses rule-based fallbacks; v2+ adds real AI.

### Agent 1: [Name]
- **Input**: [what it receives]
- **Output**: [what it produces]
- **v1**: [simple/manual approach]
- **v2**: [full AI approach]
```

## Anti-Hallucination Rules

- Do NOT invent industry-specific regulations unless you're certain they exist
- Do NOT add payment/escrow unless the idea involves money exchange
- Do NOT add AI agents unless the idea mentions AI or automation
- Do NOT over-engineer — if the idea is "todo app", don't add multi-tenancy
- DO match the complexity to the idea — a marketplace needs more entities than a tool
- DO use domain-specific terminology — if it's legal, use "case/matter"; if e-commerce, use "order/cart"

## Examples

```
/prd "CLI tool that scans codebases for security issues"
```
→ Focused tool. 3-5 entities, simple flow.

```
/prd "AI-powered legal marketplace with escrow payments and case tracking"
```
→ Full platform. 15+ entities, multiple state machines, compliance rules.
