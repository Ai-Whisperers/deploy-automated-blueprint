# Gap Analysis: Self-Deploy Blueprint

**Doc-Type:** Roadmap · Version 1.0 · December 2025

---

## Current State

**Overall Readiness:** 75% for general use

The blueprint successfully handles simple Node/Python/Go projects with Docker Compose orchestration. Gaps exist for complex architectures, alternative stacks, and edge cases.

---

## Critical Gaps (P0)

Must fix before claiming "any project" support.

| Gap | Description | Effort |
|-----|-------------|--------|
| Missing Supervisord template | CLAUDE.md promises Level 2 orchestration but no `supervisord.conf` exists | 30 min |
| No NGINX/reverse proxy template | Detected in Phase 1.2 but never provided | 30 min |
| No health endpoint examples | Referenced in validation checklist but no sample code | 1 hr |
| Inconsistent port variables | `env.example` uses different naming than `docker-compose.yml` | 15 min |

---

## Structural Gaps (P1)

Should have for production-quality handoffs.

| Gap | Impact | Effort |
|-----|--------|--------|
| No Rust Dockerfile | `Cargo.toml` detected but no template | 30 min |
| No PHP Dockerfile | Still common stack, completely unsupported | 30 min |
| No static site Dockerfile | SPAs/JAMstack need NGINX-based serving | 30 min |
| No database init scripts | PostgreSQL/MongoDB referenced but no setup | 1 hr |
| Missing SSL/TLS guidance | Cloudflare handles it, but not documented | 30 min |
| No secrets management pattern | Only "don't commit .env" - no Vault/SOPS patterns | 2 hr |
| No monorepo handling | Single approach may fail complex projects | 2 hr |

---

## Detection vs Template Mismatch

CLAUDE.md Phase 1.2 detects these but provides no templates:

| Detected Marker | Template Status | Priority |
|-----------------|-----------------|----------|
| `nginx.conf` | Missing | P0 |
| `redis` in dependencies | Partial (commented in compose) | P1 |
| `celery` | Missing worker template | P1 |
| `bull` | Missing worker template | P1 |
| `sidekiq` | Missing (Ruby unsupported) | P2 |
| `Cargo.toml` | Missing Rust Dockerfile | P1 |

---

## Architecture Coverage Matrix

| Stack | Dockerfile | Compose | Scripts | Health | Migrations | Status |
|-------|------------|---------|---------|--------|------------|--------|
| Node.js | Yes | Yes | Yes | No | No | 70% |
| Python | Yes | Yes | Yes | No | No | 70% |
| Go | Yes | Yes | Yes | No | No | 70% |
| Rust | No | No | No | No | No | 0% |
| Static/SPA | No | No | No | N/A | N/A | 0% |
| PHP | No | No | No | No | No | 0% |
| Ruby | No | No | No | No | No | 0% |
| Java/Kotlin | No | No | No | No | No | 0% |
| .NET | No | No | No | No | No | 0% |

---

## Missing Edge Cases

| Scenario | Current Coverage | Required Addition |
|----------|------------------|-------------------|
| Static site (no server) | None | S3/Cloudflare Pages alternative path |
| SPA with separate API | Partial | CORS handling template |
| WebSocket services | None | Cloudflare tunnel WS config |
| Background jobs (cron) | None | Cron/scheduler templates |
| Database migrations | None | Migration runner patterns |
| Multi-domain setup | Mentioned only | Concrete subdomain example |
| Existing Kubernetes | None | Detection + defer logic |
| Serverless preference | None | Suggest alternatives path |
| Desktop app with web UI | None | Electron/Tauri patterns |

---

## Documentation Gaps

### Branding Issues

- `deployment-guide.md` contains `ai-whisperers.org` hardcoded references
- Should use `${DOMAIN}` placeholder or generic examples

### Missing Guides

| Guide | Purpose | Priority |
|-------|---------|----------|
| Troubleshooting | Common issues and fixes | P1 |
| Real project walkthrough | Concrete example, not abstract | P1 |
| WSL2 networking | Windows-specific issues | P2 |
| Docker Desktop limits | Memory/CPU configuration | P2 |
| Tunnel reconnection | Cloudflare stability | P2 |
| Port conflict resolution | Debugging steps | P2 |

---

## CLAUDE.md Logic Gaps

Decision tree (Phase 1.3) missing branches:

| Scenario | Current Behavior | Should Do |
|----------|------------------|-----------|
| Already has Kubernetes | Proceeds anyway | Detect and defer/enhance |
| Serverless preferred | Forces containers | Suggest alternatives |
| Hybrid setup | Not considered | Allow partial containerization |
| Desktop app | Not addressed | Branch to Electron/Tauri path |
| CI/CD integration | Not mentioned | GitHub Actions/GitLab CI templates |

---

## File Additions Required

### Priority 0 (Critical)

```
templates/
├── supervisord.conf              # Level 2 orchestration
├── nginx-proxy.conf              # Reverse proxy template
└── health/
    ├── health.js                 # Node health endpoint
    ├── health.py                 # Python health endpoint
    └── health.go                 # Go health endpoint
```

### Priority 1 (High Value)

```
templates/
├── dockerfiles/
│   ├── rust.Dockerfile           # Rust support
│   ├── static.Dockerfile         # NGINX serving static files
│   └── php.Dockerfile            # PHP-FPM support
├── workers/
│   ├── celery.py                 # Python background jobs
│   └── bull.js                   # Node background jobs
├── databases/
│   ├── postgres-init.sql         # PostgreSQL initialization
│   └── mongo-init.js             # MongoDB initialization
└── cloudflare-websocket.yml      # WebSocket tunnel config
```

### Priority 2 (Extended Support)

```
templates/
├── dockerfiles/
│   ├── ruby.Dockerfile           # Ruby/Rails support
│   ├── java.Dockerfile           # Java/Spring support
│   └── dotnet.Dockerfile         # .NET support
├── ci/
│   ├── github-actions.yml        # GitHub Actions deploy
│   └── gitlab-ci.yml             # GitLab CI deploy
└── migrations/
    ├── node-migrations.sh        # Prisma/Knex patterns
    └── python-migrations.sh      # Alembic/Django patterns
```

### Priority 3 (Polish)

```
examples/
├── express-api/                  # Complete working example
├── fastapi-app/                  # Complete working example
├── next-fullstack/               # SSR + API example
└── static-spa/                   # React/Vue static build

docs/
├── troubleshooting.md            # Common issues guide
└── walkthroughs/
    ├── node-api.md               # Step-by-step Node deployment
    └── python-fastapi.md         # Step-by-step Python deployment
```

---

## Implementation Phases

### Phase 1: Core Completeness (Week 1)

- [ ] Add `supervisord.conf` template
- [ ] Add `nginx-proxy.conf` template
- [ ] Add health endpoint snippets (Node, Python, Go)
- [ ] Fix port variable inconsistencies
- [ ] Remove org-specific branding from docs

### Phase 2: Stack Expansion (Week 2)

- [ ] Add Rust Dockerfile
- [ ] Add PHP Dockerfile
- [ ] Add static site Dockerfile
- [ ] Add Celery worker template
- [ ] Add Bull worker template
- [ ] Add WebSocket tunnel config

### Phase 3: Database & Migrations (Week 3)

- [ ] Add PostgreSQL init script
- [ ] Add MongoDB init script
- [ ] Add migration runner patterns
- [ ] Document secrets management options

### Phase 4: CI/CD & Examples (Week 4)

- [ ] Add GitHub Actions template
- [ ] Add GitLab CI template
- [ ] Create express-api example
- [ ] Create fastapi-app example
- [ ] Write troubleshooting guide

### Phase 5: Extended Stacks (Future)

- [ ] Ruby/Rails support
- [ ] Java/Spring support
- [ ] .NET support
- [ ] Desktop app patterns
- [ ] Kubernetes detection/defer

---

## Success Criteria

Blueprint is complete when:

1. **Any common web stack** can be deployed (Node, Python, Go, Rust, PHP, Ruby, Java, .NET)
2. **All orchestration levels** have templates (0-5 as promised)
3. **All detected markers** have corresponding templates
4. **Edge cases** documented with alternative paths
5. **Real examples** prove the system works end-to-end
6. **Zero org-specific** references in templates/docs

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep to Kubernetes | High | Medium | Keep Level 5 as "defer to K8s docs" |
| Template maintenance burden | Medium | High | Generate from single source of truth |
| Stack-specific bugs | High | Medium | Community testing on real projects |
| Cloudflare API changes | Low | High | Abstract tunnel commands |

---

## Metrics

Track these to measure blueprint quality:

| Metric | Target | Current |
|--------|--------|---------|
| Stack coverage | 8+ stacks | 3 stacks |
| Successful deploys (tested) | 10+ projects | 0 projects |
| Avg questions asked by Claude | < 5 | Unknown |
| Time to first deploy | < 30 min | Unknown |
| Template files | 25+ | 12 |

---

**Next Action:** Begin Phase 1 - Core Completeness

**Owner:** Claude (with user validation)

**Review Date:** After each phase completion
