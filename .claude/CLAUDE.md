# Deploy Automated Blueprint

**Project-Level Configuration** · Version 1.0 · December 2025

---

## Purpose

This repository is a **Claude handoff system** - it provides instructions and templates that enable Claude to make any codebase self-deployable using Cloudflare Tunnel and Docker.

---

## Repository Structure

```
deploy-automated-blueprint/
├── CLAUDE.md                    # THE PRODUCT: Handoff document users copy to their projects
├── README.md                    # Repo documentation for humans
├── .gitignore
├── .claude/                     # THIS: Config for working on the blueprint itself
│   ├── CLAUDE.md
│   └── README.md
├── templates/                   # Scaffolding templates Claude adapts
│   ├── env.example
│   ├── cloudflare-config.yml
│   ├── docker-compose.yml
│   ├── dockerfiles/
│   │   ├── node.Dockerfile
│   │   ├── python.Dockerfile
│   │   └── go.Dockerfile
│   └── scripts/
│       ├── start.sh / start.bat
│       └── stop.sh / stop.bat
└── docs/                        # Reference documentation
    ├── deployment-guide.md
    └── market-context.md
```

---

## Key Distinction

| File | What It Is |
|------|------------|
| `/CLAUDE.md` | **The product** - Users copy this to their projects, Claude follows it |
| `/.claude/CLAUDE.md` | **Meta-config** - Instructions for editing this blueprint repo |

---

## Working on This Repository

### When Editing the Root CLAUDE.md

The root `CLAUDE.md` is the **authoritative handoff document**. When modifying:

- Maintain the 4-phase structure (Assess → Generate → Instruct → Validate)
- Keep questions in 1.1 minimal but sufficient
- Decision tree in 1.3 must cover all orchestration levels
- Templates in Phase 2 must use `${VARIABLE}` syntax
- Test changes by applying to a real project

### When Editing Templates

Templates in `/templates/` are **starting points** Claude adapts:

- Must remain stack-agnostic
- Use `${VARIABLE}` for all configurable values
- Include comments explaining what to customize
- Support both Linux and Windows where applicable

### When Editing Documentation

Files in `/docs/` are **reference material**:

- `deployment-guide.md` - Manual step-by-step (for users who don't use Claude)
- `market-context.md` - Strategic rationale (why self-deploy matters)

---

## Standards

| Area | Convention |
|------|------------|
| Variables | `${VARIABLE_NAME}` - uppercase, underscores |
| Scripts | Provide both `.sh` and `.bat` versions |
| Dockerfiles | Multi-stage builds, non-root users, alpine base |
| Documentation | Tables over prose, concise |
| Comments | Explain "what to change", not "what it does" |

---

## Testing Changes

Before committing changes to the blueprint:

1. Copy modified `CLAUDE.md` to a test project
2. Tell Claude: "make this self-deployable"
3. Verify Claude:
   - Asks appropriate questions
   - Detects stack correctly
   - Generates valid configs
   - Provides working instructions

---

## Commit Convention

```
<type>: <subject>

Types:
- feat: New capability in handoff
- fix: Bug in templates/instructions
- docs: Documentation updates
- refactor: Restructure without changing behavior
- chore: Maintenance tasks
```

---

## What NOT to Do

- Don't add stack-specific logic to root CLAUDE.md (keep it generic)
- Don't hardcode values in templates (use variables)
- Don't assume specific project structure (detect it)
- Don't require user to understand internals (Claude handles complexity)

---

## File Purposes Quick Reference

| File | Purpose | Who Reads It |
|------|---------|--------------|
| `/CLAUDE.md` | Handoff instructions | Claude (in user's project) |
| `/README.md` | Repo overview | Humans browsing GitHub |
| `/templates/*` | Config scaffolding | Claude (adapts per project) |
| `/docs/deployment-guide.md` | Manual deployment | Users without Claude |
| `/docs/market-context.md` | Why self-deploy | Decision makers |
| `/.claude/CLAUDE.md` | Blueprint dev guide | Claude (editing this repo) |

---

**Version:** 1.0.0 | **Updated:** December 2025
