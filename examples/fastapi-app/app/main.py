"""
FastAPI Example
Demonstrates self-deploy patterns with health checks, graceful shutdown
"""

import time
import asyncio
from contextlib import asynccontextmanager
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import select, String, DateTime
from redis.asyncio import Redis
import os

# ===========================================
# Configuration
# ===========================================

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://app:secret@localhost:5432/app")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# ===========================================
# Database Models
# ===========================================

class Base(DeclarativeBase):
    pass

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[Optional[str]] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

# ===========================================
# Pydantic Schemas
# ===========================================

class UserCreate(BaseModel):
    email: EmailStr
    name: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    email: str
    name: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

class HealthCheck(BaseModel):
    status: str
    timestamp: str
    uptime: float

class ReadinessCheck(BaseModel):
    status: str
    timestamp: str
    checks: dict

# ===========================================
# Database & Redis Setup
# ===========================================

engine = create_async_engine(DATABASE_URL, echo=False)
async_session = async_sessionmaker(engine, expire_on_commit=False)
redis: Optional[Redis] = None
start_time = time.time()

async def get_db():
    async with async_session() as session:
        yield session

async def get_redis():
    return redis

# ===========================================
# Lifespan Management
# ===========================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    global redis

    # Startup
    print("Starting up...")

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Connect Redis
    redis = Redis.from_url(REDIS_URL, decode_responses=True)
    await redis.ping()
    print("Redis connected")

    yield

    # Shutdown
    print("Shutting down...")
    if redis:
        await redis.close()
    await engine.dispose()
    print("Cleanup complete")

# ===========================================
# FastAPI App
# ===========================================

app = FastAPI(
    title="FastAPI Example",
    description="Self-deploy FastAPI example with health checks",
    version="1.0.0",
    lifespan=lifespan
)

# ===========================================
# Health Endpoints
# ===========================================

@app.get("/health", response_model=HealthCheck)
async def health():
    """Basic liveness probe"""
    return HealthCheck(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        uptime=time.time() - start_time
    )

@app.get("/health/ready", response_model=ReadinessCheck)
async def readiness():
    """Readiness probe with dependency checks"""
    checks = {}

    # Database check
    try:
        start = time.time()
        async with async_session() as session:
            await session.execute(select(1))
        checks["database"] = {"status": "healthy", "latency_ms": int((time.time() - start) * 1000)}
    except Exception as e:
        checks["database"] = {"status": "unhealthy", "error": str(e)}

    # Redis check
    try:
        start = time.time()
        await redis.ping()
        checks["redis"] = {"status": "healthy", "latency_ms": int((time.time() - start) * 1000)}
    except Exception as e:
        checks["redis"] = {"status": "unhealthy", "error": str(e)}

    all_healthy = all(c["status"] == "healthy" for c in checks.values())

    return ReadinessCheck(
        status="healthy" if all_healthy else "unhealthy",
        timestamp=datetime.utcnow().isoformat(),
        checks=checks
    )

# ===========================================
# API Routes
# ===========================================

@app.get("/api/users", response_model=List[UserResponse])
async def list_users(db: AsyncSession = Depends(get_db)):
    """List all users"""
    result = await db.execute(select(User))
    return result.scalars().all()

@app.post("/api/users", response_model=UserResponse, status_code=201)
async def create_user(user: UserCreate, db: AsyncSession = Depends(get_db)):
    """Create a new user"""
    db_user = User(email=user.email, name=user.name)
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    return db_user

@app.get("/api/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    """Get a user by ID"""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# ===========================================
# Run with: uvicorn app.main:app --host 0.0.0.0 --port 8000
# ===========================================
