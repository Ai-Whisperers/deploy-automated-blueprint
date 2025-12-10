# .claude Directory

Project-specific Claude Code configuration for the deploy-automated-blueprint repository.

## Purpose

This directory contains instructions for Claude when **working on this blueprint repo itself** - not when using the blueprint in other projects.

## Contents

```
.claude/
├── CLAUDE.md    # Development guidelines for this repo
└── README.md    # This file
```

## Key Distinction

| Location | Purpose |
|----------|---------|
| `/CLAUDE.md` | The product - handoff document copied to user projects |
| `/.claude/CLAUDE.md` | Meta-config - how to edit the blueprint itself |

## When Claude Reads What

- **User copies `/CLAUDE.md` to their project** → Claude follows it to make that project deployable
- **Developer works on this repo** → Claude reads `/.claude/CLAUDE.md` for contribution guidelines

---

**Version:** 1.0.0
