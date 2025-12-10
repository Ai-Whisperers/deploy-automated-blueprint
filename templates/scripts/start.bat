@echo off
:: Self-Deploy Startup Script (Windows)
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo [START] Loading environment...

:: Load .env file
if not exist .env (
    echo [ERROR] .env file not found. Copy from .env.example
    exit /b 1
)

for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "%%a"=="" set "%%a=%%b"
    )
)

:: Validate required vars
if "%TUNNEL_NAME%"=="" (
    echo [ERROR] TUNNEL_NAME not set
    exit /b 1
)
if "%DOMAIN%"=="" (
    echo [ERROR] DOMAIN not set
    exit /b 1
)

:: Start services
if exist docker-compose.yml (
    echo [START] Starting Docker Compose services...
    docker-compose up -d
) else (
    echo [START] Starting services directly...

    :: Start WSL Docker if needed
    wsl -d Ubuntu-22.04 -e bash -c "sudo service docker start" 2>nul

    :: Add your service start commands here
    :: Example:
    :: start /b cmd /c "cd ..\api && venv\Scripts\activate && uvicorn app.main:app --host 0.0.0.0 --port 8000"
    :: start /b cmd /c "cd ..\web && npm start"
)

:: Start Cloudflare Tunnel
echo [START] Starting Cloudflare Tunnel...
start /b cloudflared tunnel run %TUNNEL_NAME%

echo [START] All services started
echo [START] Access your app at: https://%DOMAIN%

:: Health check
timeout /t 5 /nobreak >nul
curl -s "http://localhost:%PORT_FRONTEND%/health" >nul 2>&1
if %errorlevel%==0 (
    echo [START] Health check passed
) else (
    echo [WARN] Health check failed - services may still be starting
)
