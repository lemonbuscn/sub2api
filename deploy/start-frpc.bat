@echo off
title frpc
cd /d "%~dp0"
echo Starting frpc ...
frpc.exe -c frpc.toml
pause
