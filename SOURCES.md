# External Sources & References

Check these when you want to upgrade the kit, find new rules, or explore what's available.

## Claude Code

| Source | What | URL |
|--------|------|-----|
| Official Plugins | 13 plugins (frontend-design, feature-dev, code-review, etc.) | https://github.com/anthropics/claude-code/tree/main/plugins |
| Plugin Marketplace | Browse/install via `/plugins` inside Claude Code | Built into Claude Code |
| Awesome Plugins | Community plugin collections | https://github.com/ComposioHQ/awesome-claude-plugins |
| Claude Cookbooks | Prompting guides, frontend aesthetics | https://github.com/anthropics/claude-cookbooks |

### Recommended Plugins to Install
```
frontend-design     — Production-grade UI generation
feature-dev         — 7-phase feature build with parallel agents
code-review         — PR review with confidence scoring
security-guidance   — Real-time vulnerability detection
commit-commands     — /commit, /commit-push-pr workflow
```

## Cursor

| Source | What | URL |
|--------|------|-----|
| cursor.directory | Largest community hub (71.7k members) | https://cursor.directory |
| awesome-cursorrules | 37.8k stars, 100+ templates | https://github.com/PatrickJS/awesome-cursorrules |
| awesome-cursor-rules-mdc | Auto-generated MDC files | https://github.com/sanjeed5/awesome-cursor-rules-mdc |
| Rule Generator | Upload package.json, get tailored rules | https://cursor.directory/generate |
| dotcursorrules.com | Browseable directory with voting | https://dotcursorrules.com |
| cursorrules.org | AI-powered rule generator | https://cursorrules.org |

## GitHub Copilot

| Source | What | URL |
|--------|------|-----|
| awesome-copilot | Official GitHub collection (20.8k stars) | https://github.com/github/awesome-copilot |
| Agent Skills | Open standard for AI coding skills | https://agentskills.io |
| Copilot Agents | Custom agent (.agent.md) system | https://github.com/github/awesome-copilot |

## Windsurf

| Source | What | URL |
|--------|------|-----|
| Windsurf Workflows | Cascade workflow system | https://docs.windsurf.com/windsurf/cascade/workflows |
| Community Rules | Windsurf-specific rules | https://windsurf.diy |
| Playbooks | Cross-tool rule platform | https://playbooks.com/windsurf-rules |

## When to Check These

- **Monthly:** Browse cursor.directory for new rules matching your stack
- **When adding a tool:** Check if there's a Claude Code plugin for it
- **When starting a new project:** Use cursor.directory/generate with your package.json
- **When the kit feels stale:** Run `/learn review` first (project-specific), then check sources for generic improvements

## How the Kit Self-Improves

The kit's primary improvement comes from YOUR codebase, not external sources:

```
/audit finds bug → /learn captures it → rules/patterns updated → /audit catches it next time
```

External sources are supplements, not replacements. Your real bugs are more valuable than generic community rules.
