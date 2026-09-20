@echo off
REM Starts the self-hosted Supermemory server inside WSL.
REM Change WSL_DISTRO below if your distro is not Ubuntu-24.04
REM   (run  wsl -l -v  to see your distro name).

set WSL_DISTRO=Ubuntu-24.04

title Supermemory Server
echo ================================================
echo   Supermemory server
echo   URL: http://localhost:6767
echo   Close this window (or Ctrl+C) to stop it.
echo ================================================
echo.
echo Stopping any old copy still running...
wsl -d %WSL_DISTRO% -- bash -lc "pkill -f 'bin/supermemory-server' 2>/dev/null; sleep 1; exit 0"
echo.
wsl -d %WSL_DISTRO% -- bash -lc "set -a; . ~/.supermemory/env; set +a; exec ~/.supermemory/bin/supermemory-server"
echo.
echo Server stopped.
pause
