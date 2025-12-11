"""
Celery Worker Template
Background task processing for Python applications

Setup:
    pip install celery redis

Usage:
    # Start worker
    celery -A workers.celery worker --loglevel=info

    # Start beat scheduler (for periodic tasks)
    celery -A workers.celery beat --loglevel=info

    # Start both (development only)
    celery -A workers.celery worker --beat --loglevel=info

Docker Compose service:
    worker:
      build: .
      command: celery -A workers.celery worker --loglevel=info
      env_file: .env
      depends_on:
        - redis
"""

import os
from celery import Celery
from kombu import Queue

# ===========================================
# Configuration
# ===========================================

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CELERY_BROKER_URL = os.getenv("CELERY_BROKER_URL", REDIS_URL)
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", REDIS_URL)

# Initialize Celery
app = Celery(
    "tasks",
    broker=CELERY_BROKER_URL,
    backend=CELERY_RESULT_BACKEND,
    include=["workers.tasks"]  # Module containing task definitions
)

# ===========================================
# Celery Configuration
# ===========================================

app.conf.update(
    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,

    # Task execution
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    task_time_limit=3600,  # 1 hour hard limit
    task_soft_time_limit=3300,  # 55 min soft limit

    # Worker settings
    worker_prefetch_multiplier=1,
    worker_concurrency=4,
    worker_max_tasks_per_child=1000,

    # Result backend
    result_expires=86400,  # 24 hours

    # Queue configuration
    task_default_queue="default",
    task_queues=(
        Queue("default", routing_key="default"),
        Queue("high_priority", routing_key="high"),
        Queue("low_priority", routing_key="low"),
    ),

    # Retry settings
    task_default_retry_delay=60,
    task_max_retries=3,
)

# ===========================================
# Beat Schedule (Periodic Tasks)
# ===========================================

app.conf.beat_schedule = {
    # Example: Run every 5 minutes
    # "cleanup-expired-sessions": {
    #     "task": "workers.tasks.cleanup_sessions",
    #     "schedule": 300.0,
    # },

    # Example: Run daily at midnight UTC
    # "generate-daily-report": {
    #     "task": "workers.tasks.generate_report",
    #     "schedule": crontab(hour=0, minute=0),
    # },
}


# ===========================================
# Example Tasks (move to workers/tasks.py)
# ===========================================

@app.task(bind=True, max_retries=3)
def example_task(self, data: dict) -> dict:
    """
    Example task with retry logic.

    Usage:
        from workers.celery import example_task
        result = example_task.delay({"key": "value"})
        print(result.get(timeout=30))
    """
    try:
        # Your task logic here
        return {"status": "success", "data": data}
    except Exception as exc:
        # Retry with exponential backoff
        self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))


@app.task(bind=True, queue="high_priority")
def high_priority_task(self, data: dict) -> dict:
    """Task that runs on high priority queue."""
    return {"status": "processed", "data": data}


@app.task(bind=True, queue="low_priority", rate_limit="10/m")
def rate_limited_task(self, data: dict) -> dict:
    """Task with rate limiting (10 per minute)."""
    return {"status": "processed", "data": data}


# ===========================================
# Health Check Task
# ===========================================

@app.task
def health_check() -> dict:
    """
    Health check task for monitoring.

    Usage:
        result = health_check.delay()
        if result.get(timeout=5):
            print("Worker is healthy")
    """
    return {"status": "healthy", "worker": "celery"}


# ===========================================
# Signals (Lifecycle Hooks)
# ===========================================

from celery.signals import worker_ready, worker_shutdown, task_failure

@worker_ready.connect
def on_worker_ready(**kwargs):
    """Called when worker is ready to accept tasks."""
    print("Celery worker is ready")


@worker_shutdown.connect
def on_worker_shutdown(**kwargs):
    """Called when worker is shutting down."""
    print("Celery worker is shutting down")


@task_failure.connect
def on_task_failure(task_id, exception, **kwargs):
    """Called when a task fails."""
    print(f"Task {task_id} failed: {exception}")
    # Add alerting/logging here
