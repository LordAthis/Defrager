@echo off
if "%~1"=="" (echo Huzz ra egy .ps1 fajlt! & pause & exit)
set SCRIPT_PATH=%~f1
if not exist "..\LOG" mkdir "..\LOG"
set PS_LOG=..\LOG\PS_Runner_History.txt

echo [%date% %time%] Inditas: %~n1 >> "%PS_LOG%"

:: Fájl feloldása és futtatás kényszerített Bypass módban
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {Unblock-File -Path '%SCRIPT_PATH%'; & '%SCRIPT_PATH%'}" >> "%PS_LOG%" 2>&1

if %errorlevel% neq 0 (
    echo [!] Hiba tortent. Ellenorizd a LOG mappat!
    pause
)
