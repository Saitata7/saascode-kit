---
name: skill-creator
description: Create custom Claude Code skills with proper YAML frontmatter, trigger phrases, instruction structure, and validation. Use when user says "create a skill", "new skill", "custom skill", "add a slash command", "make a workflow", or "/skill-create". Do NOT use for building app features (use /build) or generating docs (use /docs).
---

# Skill: Custom Skill Creator

> Trigger: /skill-create [name|"from-workflow"]
> Purpose: Walk through creating a custom Claude Code skill with proper structure, frontmatter, triggers, and validation — following Anthropic's skills guide

**What this generates:** A ready-to-use skill file (`.claude/skills/[name].md` or `[name]/SKILL.md` folder) with YAML frontmatter, structured instructions, examples, and troubleshooting.

**Output location:** `.claude/skills/[name].md` (flat) or `skills/[name]/SKILL.md` (folder format)

## Instructions

### Step 1: Define the Use Case

Ask these questions (or infer from user's description):

1. **What does the user want to accomplish?** — the core task
2. **What multi-step workflow does this require?** — the steps in order
3. **Which tools are needed?** — built-in (Read, Write, Bash, Glob, Grep) or MCP?
4. **What domain knowledge should be embedded?** — best practices, patterns, rules

Classify into one of 3 categories:

| Category | Description | Example |
|----------|-------------|---------|
| **Document & Asset Creation** | Generates consistent output (docs, code, designs) | PRD generator, API reference |
| **Workflow Automation** | Multi-step process with consistent methodology | Code review, deployment, migration |
| **MCP Enhancement** | Workflow guidance for MCP tool access | Linear sprint planning, Notion sync |

Identify the primary pattern:

| Pattern | Use When | Our Example |
|---------|----------|-------------|
| **Sequential workflow** | Multi-step in specific order | /build, /deploy, /migrate |
| **Iterative refinement** | Output improves with iteration | /docs, /learn |
| **Context-aware selection** | Different tools based on context | /review (reads manifest), /debug (symptom-based) |
| **Domain intelligence** | Specialized knowledge beyond tools | /audit (OWASP), /prd (entity modeling) |

### Step 2: Generate YAML Frontmatter

```yaml
---
name: [kebab-case-name]
description: [What it does] + [When to use — trigger phrases] + [Key capabilities]. Do NOT use for [negative triggers].
---
```

**Critical rules (from Anthropic guide):**
- `name`: kebab-case only. No spaces, capitals, or underscores. No "claude" or "anthropic".
- `description`: Under 1024 characters. MUST include:
  - What the skill does (1 sentence)
  - When to use it — specific phrases users would say (quoted)
  - What NOT to use it for — prevents over-triggering
- No XML angle brackets (`<` or `>`) in frontmatter — security restriction
- Description structure: `[What it does]. Use when user says "[trigger1]", "[trigger2]", or "/[command]". Do NOT use for [what to avoid] (use /[other-skill] instead).`

**Good description example:**
```
description: Generate implementation-ready Product Brief with entities, relationships, domain rules, state machines, and flows. Use when user says "PRD", "product brief", "product spec", "plan the product", or "/prd". Do NOT use for technical design (use /design) or task planning (use /todo).
```

**Bad description examples:**
```
# Too vague — won't trigger
description: Helps with projects.

# Missing triggers — Claude won't know when to load it
description: Creates sophisticated multi-page documentation systems.

# Too technical, no user triggers
description: Implements the Project entity model with hierarchical relationships.
```

### Step 3: Write the Instruction Body

Use this template structure:

```markdown
# Skill: [Name]

> Trigger: /[command] [arguments]
> Purpose: [One sentence — what this skill does]

## Instructions

### Step 1: [First Major Step]

[Clear explanation. Be specific and actionable.]

[Include bash commands if applicable:]
\```bash
# Example command
command --flag argument
\```

### Step 2: [Second Major Step]

[Instructions with expected output format.]

### Step 3: [Third Major Step]

[Continue as needed.]

## Output Format

\```markdown
## [Expected Output Title]
[Template of what the skill produces]
\```

## Examples

### Example 1: [Common scenario]
User says: "[typical request]"
Actions:
1. [What the skill does]
2. [Next step]
Result: [What user gets]

### Example 2: [Edge case]
User says: "[less common request]"
[Handle differently because...]

## Troubleshooting

### [Common error or unexpected behavior]
**Cause:** [Why this happens]
**Solution:** [How to fix it]

## Rules

1. [Critical rule — what must always be true]
2. [Safety rule — what to never do]
3. [Quality rule — what makes output good]
```

**Best practices for instructions:**
- Be specific: `Run \`python scripts/validate.py --input {filename}\`` not `Validate the data`
- Include verification after each step
- Put critical instructions at the top, use `## Important` or `## Critical` headers
- Keep SKILL.md focused — move long reference docs to `references/` if using folder format
- Add `## Performance Notes` for complex skills: "Take your time. Quality > speed. Don't skip validation."

### Step 4: Define Trigger Test Queries

Create 5 "should trigger" and 3 "should NOT trigger" test queries:

```yaml
should_trigger:
  - "[obvious request using exact trigger phrase]"
  - "[paraphrased request]"
  - "[natural language request]"
  - "[request with specific context]"
  - "[another variant]"

should_not_trigger:
  - "[request that should go to different skill]"  # → [which skill]
  - "[request that seems related but isn't]"        # → [which skill]
  - "[ambiguous request to rule out]"               # → [which skill]
```

### Step 5: Validate

Run through this checklist:

| Check | Rule | Status |
|-------|------|--------|
| Name is kebab-case | No spaces, capitals, underscores | |
| No "claude"/"anthropic" in name | Security restriction | |
| Description under 1024 chars | Frontmatter limit | |
| No XML `<>` in frontmatter | Security restriction | |
| Description has [What] | First sentence explains purpose | |
| Description has [When] | Includes trigger phrases in quotes | |
| Description has [Capabilities] | Lists key features | |
| Description has [NOT for] | Negative triggers prevent over-triggering | |
| Steps are numbered | Clear execution order | |
| Steps are specific | Real commands, not vague instructions | |
| Has examples section | At least 1 scenario | |
| Has troubleshooting | At least 1 common issue | |
| Has rules section | Critical constraints listed | |

### Step 6: Save the Skill

**Flat format** (for Claude Code project skills):
```bash
mkdir -p .claude/skills
# Write to .claude/skills/[name].md
```

**Folder format** (for Claude.ai upload or Skills API):
```bash
mkdir -p skills/[skill-name]
# Write to skills/[skill-name]/SKILL.md
# Optionally add references/ for long documentation
```

### Step 7: Test It

1. **Trigger test:** Ask Claude one of your "should trigger" queries — does the skill load?
2. **Negative test:** Ask a "should NOT trigger" query — does it correctly NOT load?
3. **Functional test:** Run the full workflow — does it produce correct output?
4. **Consistency test:** Run the same request 3 times — are results structurally consistent?

If the skill doesn't trigger: add more keywords to the description.
If the skill triggers too often: add more negative triggers or be more specific.
If instructions aren't followed: put critical rules at the top, use bullet points, reduce verbosity.

## Examples

### Example 1: Create a code formatting skill
User says: "Create a skill that formats code according to our project standards"

Actions:
1. Classify: Workflow Automation, Sequential pattern
2. Generate frontmatter with name `code-formatter`, triggers "format code", "fix formatting", "lint"
3. Write steps: detect formatter (prettier/eslint/black), run format, verify, report changes
4. Add examples for different languages
5. Save to `.claude/skills/code-formatter.md`

Result: Working skill that triggers on formatting requests

### Example 2: Create from an existing workflow
User says: "/skill-create from-workflow" (then describes their manual process)

Actions:
1. Ask user to describe their current workflow step by step
2. Classify the workflow category and pattern
3. Convert manual steps into skill instructions
4. Add triggers based on how users would ask for this workflow
5. Validate and save

Result: Automated version of their manual workflow

## Rules

1. **Always validate against the checklist** — don't skip Step 5
2. **Start with triggers** — a skill that doesn't trigger is useless
3. **Be opinionated** — include specific commands, paths, and patterns, not vague guidance
4. **Include negative triggers** — every skill should say what it's NOT for
5. **Test before declaring done** — at minimum test 1 trigger query
6. **Keep it focused** — one skill per workflow, not a mega-skill that does everything
7. **Match project patterns** — read existing skills in `.claude/skills/` and follow the same style
