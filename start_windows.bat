@echo off
TITLE System Monitor - Auto Launcher
cd /d "%~dp0"
if not exist "data" mkdir "data"
if not exist "data\stats.json" echo {"cpu":{"usage":0,"name":"Loading..."},"ram":{"usage":0},"network":{"usage":0},"disks":[],"gpus":[]} > "data\stats.json"
echo [1/2] Starting Web Server...
start "Docker Host" docker compose up --build
echo [2/2] Starting Spy Agent...
timeout /t 3 >nul
net session >nul 2>&1
if %errorLevel% == 0 ( powershell -NoProfile -ExecutionPolicy Bypass -File ".\spy.ps1" ) else ( powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0spy.ps1""' -Verb RunAs" )