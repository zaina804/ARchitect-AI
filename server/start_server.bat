@echo off
echo ============================================
echo  Land Detection Server - Starting...
echo ============================================

REM Install / update dependencies
pip install -r requirements.txt --quiet

REM Find this PC's WiFi IP and show it
echo.
echo Your WiFi IP (use this in config.dart):
ipconfig | findstr /i "IPv4" | findstr /v "127.0.0.1"
echo.
echo Server running at  http://0.0.0.0:8000
echo Press Ctrl+C to stop.
echo.

REM Start server - accessible from any device on the same WiFi
uvicorn server:app --host 0.0.0.0 --port 8000

pause
