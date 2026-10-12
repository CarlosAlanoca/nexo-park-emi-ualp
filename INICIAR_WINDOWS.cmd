@echo off
cd /d "%~dp0"
echo NEXO PARK EMI UALP - demostracion local
echo Abra http://localhost:4000 cuando termine el arranque.
docker compose up --build
pause
