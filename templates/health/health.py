"""
Health Check Endpoint - Python / FastAPI

Add to your FastAPI app:
    from health import router as health_router
    app.include_router(health_router)

Endpoints:
    GET /health       - Basic liveness check
    GET /health/ready - Readiness check with dependencies
"""

import time
import psutil
from datetime import datetime
from fastapi import APIRouter, Response
from pydantic import BaseModel
from typing import Optional, Dict

router = APIRouter()

# Track start time for uptime calculation
START_TIME = time.time()


class HealthCheck(BaseModel):
    status: str
    timestamp: str
    uptime: float


class ReadinessCheck(BaseModel):
    status: str
    timestamp: str
    checks: Dict[str, dict]
    error: Optional[str] = None


@router.get("/health", response_model=HealthCheck)
async def health():
    """Basic liveness probe - returns 200 if process is running."""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        uptime=round(time.time() - START_TIME, 2)
    )


@router.get("/health/ready", response_model=ReadinessCheck)
async def readiness(response: Response):
    """Readiness probe - checks all dependencies."""
    checks = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {}
    }

    try:
        # Database check (uncomment and adapt)
        # start = time.time()
        # await database.execute("SELECT 1")
        # checks["checks"]["database"] = {
        #     "status": "healthy",
        #     "latency": round((time.time() - start) * 1000)
        # }

        # Redis check (uncomment and adapt)
        # start = time.time()
        # await redis.ping()
        # checks["checks"]["redis"] = {
        #     "status": "healthy",
        #     "latency": round((time.time() - start) * 1000)
        # }

        # Memory check
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        checks["checks"]["memory"] = {
            "status": "healthy" if memory_percent < 90 else "warning",
            "used_percent": memory_percent,
            "available_mb": round(memory.available / 1024 / 1024)
        }

        # CPU check
        cpu_percent = psutil.cpu_percent(interval=0.1)
        checks["checks"]["cpu"] = {
            "status": "healthy" if cpu_percent < 90 else "warning",
            "used_percent": cpu_percent
        }

        return ReadinessCheck(**checks)

    except Exception as e:
        checks["status"] = "unhealthy"
        checks["error"] = str(e)
        response.status_code = 503
        return ReadinessCheck(**checks)


# Standalone usage (for testing)
# uvicorn health:app --port 8000
if __name__ == "__main__":
    from fastapi import FastAPI
    import uvicorn

    app = FastAPI()
    app.include_router(router)

    print("Health check running on http://localhost:8000/health")
    uvicorn.run(app, host="0.0.0.0", port=8000)
