@echo off
setlocal enabledelayedexpansion

:: Mappa ellenőrzés
if not exist "..\LOG" mkdir "..\LOG"
set LOGFILE=..\LOG\RTS_Master_Log.txt

:: Ciklus ellenőrzése (Újraindítás utáni folytatáshoz)
if exist "..\LOG\cycle.tmp" (
    set /p CYCLE=<"..\LOG\cycle.tmp"
    echo [RTS] Folytatás: !CYCLE!. ciklus... >> "%LOGFILE%"
    goto AUTO_RUN
)

:MENU
cls
echo [RTS Defrager Master]
echo 1. Alapos karbantartás (3x Defrag + 2x Scandisk ciklus)
echo 2. Ütemezés (Heti rendszeresség beállítása)
echo 3. Grafikus felület (GUI) javítása
echo 4. Kilépés
set /p opt="Választás: "

if "%opt%"=="1" (
    echo 3 > "..\LOG\cycle.tmp"
    goto AUTO_RUN
)
if "%opt%"=="2" (
    schtasks /create /tn "RTS_Weekly_Defrag" /tr "%~f0" /sc weekly /d MON /st 01:00 /rl highest
    echo [RTS] Heti ütemezés hétfő 01:00-ra beállítva.
    pause & goto MENU
)
if "%opt%"=="3" (
    echo [RTS] GUI javítása folyamatban...
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dfrgui.exe" /ve /t REG_SZ /d "C:\Windows\System32\dfrgui.exe" /f
    sc config defragsvc start= demand
    net start defragsvc
    echo [RTS] Kész. Próbáld megnyitni a Grafikus felületet.
    pause & goto MENU
)
exit

:AUTO_RUN
set /p CYCLE=<"..\LOG\cycle.tmp"
echo [%date% %time%] Ciklus !CYCLE! indítása... >> "%LOGFILE%"

:: W10 Motor frissítése/beállítása
if exist "..\Apps\defrag.exe" (
    echo [INFO] W10 motor használata... >> "%LOGFILE%"
    copy /y "..\Apps\defrag.exe" "C:\Windows\System32\defrag.exe" >nul
)

:: PowerShell Motor hívása
powershell -ExecutionPolicy Bypass -File "Defrager.ps1" -Cycle !CYCLE!

:: Ciklus léptetés és Scandisk
set /a NEXT_CYCLE=!CYCLE!-1
if !NEXT_CYCLE! leq 0 (
    del "..\LOG\cycle.tmp"
    echo [FINISH] Karbantartás kész! >> "%LOGFILE%"
    pause & exit
)

echo !NEXT_CYCLE! > "..\LOG\cycle.tmp"
echo [RTS] Scandisk ütemezése és újraindítás...
echo y | chkdsk C: /f
shutdown /r /t 10 /c "RTS: Karbantartási ciklus miatt újraindítás 10mp múlva..."
