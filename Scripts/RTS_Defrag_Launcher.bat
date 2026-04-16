@echo off
setlocal enabledelayedexpansion

:: RTS Könyvtárstruktúra biztosítása
if not exist "..\LOG" mkdir "..\LOG"
if not exist "..\LOG\Recovery" mkdir "..\LOG\Recovery"
if not exist "..\Apps" mkdir "..\Apps"

set MASTERLOG=..\LOG\RTS_Master_Log.txt
set CYCLEFILE=..\LOG\cycle.tmp

:: Rendszergazdai jog ellenőrzése
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [HIBA] Kérlek, futtasd rendszergazdaként!
    pause & exit
)

:: Ciklus ellenőrzése újraindítás után
if exist "%CYCLEFILE%" (
    set /p CYCLE=<"%CYCLEFILE%"
    echo [%date% %time%] Rendszer ujraindult. Folytatas: !CYCLE!. ciklus... >> "%MASTERLOG%"
    goto RUN_ENGINE
)

:MENU
cls
echo =======================================================
echo [RTS Defrager Master - Biztonsagi Modullal]
echo =======================================================
echo 1. Mely-karbantartas (3x Defrag + 2x Scandisk + S.M.A.R.T. check)
echo 2. Heti utemezes beallitasa (Automatizalas)
echo 3. Grafikus felulet (GUI) es Szolgaltatas javitas
echo 4. Kilepes
echo -------------------------------------------------------
set /p opt="Valasztas: "

if "%opt%"=="1" (
    echo 3 > "%CYCLEFILE%"
    goto RUN_ENGINE
)
if "%opt%"=="2" (
    schtasks /create /tn "RTS_Weekly_Defrag" /tr "%~f0" /sc weekly /d MON /st 01:00 /rl highest /f
    echo [RTS] Heti utemezes beallitva. >> "%MASTERLOG%"
    pause & goto MENU
)
if "%opt%"=="3" (
    call :FIX_GUI
    pause & goto MENU
)
exit

:RUN_ENGINE
set /p CYCLE=<"%CYCLEFILE%"

:: 1. Lepes: W10 Motor frissitese (ha van az Apps-ban)
if exist "..\Apps\defrag.exe" (
    echo [INFO] W10 motor masolasa a rendszerbe... >> "%MASTERLOG%"
    takeown /f C:\Windows\System32\defrag.exe >nul
    icacls C:\Windows\System32\defrag.exe /grant %username%:F >nul
    copy /y "..\Apps\defrag.exe" "C:\Windows\System32\defrag.exe"
    copy /y "..\Apps\defragres.dll" "C:\Windows\System32\defragres.dll"
)

:: 2. Lepes: PowerShell Motor inditasa
powershell -ExecutionPolicy Bypass -File "Defrager.ps1" -Cycle !CYCLE!

:: 3. Lepes: Cikluskezeles és Scandisk utemezes
set /a NEXT_CYCLE=!CYCLE!-1
if !NEXT_CYCLE! leq 0 (
    del "%CYCLEFILE%"
    echo [KESZ] Minden ciklus sikeresen lefutott. >> "%MASTERLOG%"
    echo Karbantartas befejezve.
    pause & exit
)

echo !NEXT_CYCLE! > "%CYCLEFILE%"
echo [RTS] Scandisk utemezese es ujrainditas... >> "%MASTERLOG%"
echo y | chkdsk C: /f
shutdown /r /t 15 /c "RTS Karbantartas: Ujrainditas a kovetkezo ciklushoz..."
exit

:FIX_GUI
echo [RTS] Szolgaltatasok es registry helyreallitasa...
sc config defragsvc start= demand
net start defragsvc
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dfrgui.exe" /ve /t REG_SZ /d "C:\Windows\System32\dfrgui.exe" /f
echo [KESZ] GUI javitas elvegezve.
goto :eof
