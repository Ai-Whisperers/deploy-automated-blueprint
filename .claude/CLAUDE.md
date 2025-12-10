# Deploy Automated Blueprint

**Project-Level Configuration** · Version 1.0 · December 2025

---

## Purpose

This repository provides a Claude handoff system for making any codebase self-deployable using Cloudflare Tunnel and Docker.

---

## Key Files

| File | Purpose |
|------|---------|
| `/CLAUDE.md` | Main handoff - Claude follows this to deploy projects |
| `/templates/*` | Config templates adapted per project |
| `/docs/*` | Reference documentation |

---

## Working With This Repo

**If editing the blueprint:**
- Keep root `CLAUDE.md` as authoritative handoff document
- Templates must remain stack-agnostic with `${VARIABLE}` placeholders
- Test changes by applying to a sample project

**If using the blueprint:**
- Copy `/CLAUDE.md` to target project
- Tell Claude: "make this self-deployable"

---

## Standards

| Area | Convention |
|------|------------|
| Templates | `${VARIABLE}` substitution syntax |
| Scripts | Both `.sh` (Linux) and `.bat` (Windows) |
| Dockerfiles | Multi-stage builds, non-root users |
| Documentation | Concise, table-driven |

---

## Commit Convention

```
<type>: <subject>

Types: feat, fix, docs, refactor, chore
```

---

**Version:** 1.0.0
