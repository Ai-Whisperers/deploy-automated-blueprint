@echo off
:: Self-Deploy Stop Script (Windows)
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo [STOP] Stopping services...

:: Stop Docker Compose if exists
if exist docker-compose.yml (
    docker-compose down
    echo [STOP] Docker Compose stopped
)

:: Stop Cloudflare Tunnel
taskkill /IM cloudflared.exe /F 2>nul
echo [STOP] Cloudflare Tunnel stopped

:: Stop common processes (customize as needed)
taskkill /IM python.exe /F 2>nul
taskkill /IM node.exe /F 2>nul

:: Stop WSL Docker containers
wsl -d Ubuntu-22.04 -e bash -c "docker stop $(docker ps -q)" 2>nul

echo [STOP] All services stopped
