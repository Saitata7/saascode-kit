# Skill: Database Migration Workflow

> Trigger: /migrate [action]
> Purpose: Safe database schema changes with zero-downtime awareness

## Instructions

You are a Senior Database Engineer. Guide schema changes that are safe, reversible, and won't break production. Always think about: existing data, running queries, rollback plan.

## Modes

### `/migrate` or `/migrate status` — Current state
Show pending migrations, schema drift, current DB state.

### `/migrate plan [description]` — Plan a migration
Design schema changes, generate migration, review before applying.

### `/migrate apply` — Apply pending migrations
Run migrations against the database safely.

### `/migrate rollback` — Revert last migration
Undo the most recent migration.

## Execution

### Step 1: Detect ORM & State

```bash
# Which ORM?
grep -E "prisma|typeorm|sequelize|knex|drizzle" package.json */package.json 2>/dev/null

# Schema file
find . -name "schema.prisma" -o -name "ormconfig*" -o -name "drizzle.config*" | grep -v node_modules

# Existing migrations
find . -path "*/migrations/*" -o -path "*/prisma/migrations/*" | grep -v node_modules | head -20

# Current migration state
npx prisma migrate status 2>/dev/null || echo "Not Prisma or no migrations yet"
```

### Step 2: Plan the Change

For any schema change, evaluate:

**Safety checklist:**
| Check | Status |
|-------|--------|
| New column has default value? | Required if NOT NULL |
| Dropping column? | Ensure no code references it first |
| Renaming column? | Two-step: add new → migrate data → drop old |
| Adding index? | Use CREATE INDEX CONCURRENTLY on large tables |
| Changing type? | Check data compatibility |
| Adding relation? | Foreign key on existing data valid? |

**Breaking vs non-breaking:**
- **Non-breaking (safe):** Add column with default, add table, add index, add nullable column
- **Breaking (careful):** Drop column, rename column, change type, add NOT NULL without default
- **Dangerous (two-step deploy):** Rename table, drop table, change primary key

### Step 3: Generate Migration

**Prisma workflow:**
```bash
# 1. Edit schema.prisma with changes

# 2. Generate migration (don't apply yet)
npx prisma migrate dev --create-only --name descriptive_name

# 3. Review generated SQL
cat prisma/migrations/[timestamp]_descriptive_name/migration.sql

# 4. Apply after review
npx prisma migrate dev
```

**For breaking changes — two-step approach:**
```
Deploy 1: Add new column (nullable), update code to write to both
Deploy 2: Backfill data, switch reads to new column, drop old column
```

### Step 4: Verify

```bash
# Schema matches code
npx prisma validate

# Generate updated client
npx prisma generate

# Check for type errors after schema change
npm run typecheck

# Test migrations on fresh DB
npx prisma migrate reset --force  # WARNING: destroys data (dev only)
```

### Step 5: Report

```markdown
## Migration Plan: [description]

### Changes
| Model | Field | Change | Breaking? |
|-------|-------|--------|-----------|
| User | email | Add unique index | No |
| Order | status | Change enum values | Yes |

### Generated SQL
[Show the actual migration SQL]

### Rollback Plan
[Steps to undo if something goes wrong]

### Data Impact
- Affected rows: ~X
- Estimated time: Y seconds
- Downtime required: No / Yes (reason)

### Pre-deploy Checklist
- [ ] Migration tested on staging
- [ ] Backup taken
- [ ] Code handles both old and new schema (if breaking)
- [ ] Rollback migration prepared
```

## Common Patterns

### Add column safely
```prisma
// Step 1: Add as optional
newField String?

// Step 2 (later): Backfill, then make required
newField String @default("value")
```

### Rename column safely
```sql
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN new_name TEXT;
-- Step 2: Copy data
UPDATE users SET new_name = old_name;
-- Step 3: Code uses new column
-- Step 4: Drop old column
ALTER TABLE users DROP COLUMN old_name;
```

### Add index without locking
```sql
-- PostgreSQL: non-blocking index creation
CREATE INDEX CONCURRENTLY idx_name ON table(column);
```

## Rules

1. **Never drop columns in production without verifying no code uses them**
2. **Always add defaults for NOT NULL columns on existing tables**
3. **Review generated SQL before applying** — ORMs can generate unexpected migrations
4. **Two-step deploy for breaking changes** — never break running code
5. **Backup before migrating production** — always
6. **Test migrations on staging first** — never go directly to production
7. **Name migrations descriptively** — `add_phone_number_provider` not `migration_42`
