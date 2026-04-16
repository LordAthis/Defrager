@echo off
setlocal enabledelayedexpansion

:: RTS Könyvtárstruktúra biztosítása
if not exist "..\LOG" mkdir "..\LOG"
if not exist "..\Apps" mkdir "..\Apps"

set LOGFILE=..\LOG\Defrag_Log_%date:~0,4%%date:~5,2%%date:~8,2%.txt
echo [RTS Defrager Start: %date% %time%] > "%LOGFILE%"

:: Rendszergazdai jog ellenőrzése
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [HIBA] Kérlek, futtasd rendszergazdaként! | tee -a "%LOGFILE%"
    pause
    exit
)

:: Verzió detektálás
for /f "tokens=4-5 delims=. " %%i in ('ver') do set OS_VER=%%i.%%j
echo [INFO] Operációs rendszer verzió: %OS_VER% >> "%LOGFILE%"

:: Apps mappa ellenőrzése (W10 defrag portolás támogatása)
if exist "..\Apps\defrag.exe" (
    echo [INFO] Külső (Apps) defrag motor észlelve. >> "%LOGFILE%"
    set DEFRAG_PATH=..\Apps\defrag.exe
) else (
    set DEFRAG_PATH=defrag.exe
)

:: PowerShell motor indítása
powershell -ExecutionPolicy Bypass -File "Defrager.ps1" -LogPath "%LOGFILE%" -EnginePath "%DEFRAG_PATH%"

echo [RTS] Folyamat lefutott. Napló: %LOGFILE%
pause
