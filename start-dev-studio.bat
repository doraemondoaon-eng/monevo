@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Starting MONEVO Local Dev Studio...
start "" http://127.0.0.1:4321
node dev-studio\local-server.mjs
pause
