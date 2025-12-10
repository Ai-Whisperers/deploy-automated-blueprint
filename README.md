# self-deploy

Make any codebase self-deployable with Claude.

## Quick Start

1. Copy `CLAUDE.md` to your project root
2. Tell Claude: **"make this self-deployable"**
3. Claude will assess your stack, ask questions, and generate deployment configs

## What This Does

Claude reads `CLAUDE.md` and follows a structured process to:

- Detect your stack (Node, Python, Go, etc.)
- Select appropriate orchestration level
- Generate Cloudflare Tunnel + Docker configs
- Create startup/shutdown scripts
- Output setup instructions

## Repository Structure

```
self-deploy/
├── CLAUDE.md                    # Handoff document (copy this)
├── README.md                    # This file
├── .gitignore
├── templates/
│   ├── env.example              # Environment template
│   ├── cloudflare-config.yml    # Tunnel configuration
│   ├── docker-compose.yml       # Container orchestration
│   ├── dockerfiles/
│   │   ├── node.Dockerfile
│   │   ├── python.Dockerfile
│   │   └── go.Dockerfile
│   └── scripts/
│       ├── start.sh / start.bat
│       └── stop.sh / stop.bat
└── docs/
    ├── deployment-guide.md      # Manual reference
    └── market-context.md        # Strategic context
```

## Usage

### Option A: Full Handoff

Copy entire repo to your project:
```bash
cp -r self-deploy/.  your-project/
```

### Option B: Minimal Handoff

Copy only the instruction file:
```bash
cp self-deploy/CLAUDE.md your-project/
```

Then reference templates as needed.

## Orchestration Levels

| Level | Tool | When to Use |
|-------|------|-------------|
| 0 | Direct runtime | Single service |
| 1 | Shell scripts | 2-3 services |
| 2 | Supervisord | 3-5 services, auto-restart |
| 3 | Docker Compose | 5+ services |
| 4 | Swarm/Nomad | Auto-scaling |
| 5 | Kubernetes | Enterprise compliance |

## Architecture

```
Internet → Cloudflare → cloudflared → Your Services → Redis/DB
```

- **Cloudflare Tunnel**: HTTPS ingress, DDoS protection, zero exposed ports
- **Docker**: Containerization without vendor lock-in
- **WSL2**: Windows compatibility layer

## Requirements

- Cloudflare account (free tier works)
- Docker 20.10+
- cloudflared CLI
- Domain with Cloudflare DNS

## License

MIT

---

**Version:** 1.0.0 | **Author:** AI Whisperers
