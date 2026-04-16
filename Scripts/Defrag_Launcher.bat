@echo off
setlocal enabledelayedexpansion

:: Könyvtárstruktúra biztosítása
if not exist "..\LOG" mkdir "..\LOG"
if not exist "..\LOG\Recovery" mkdir "..\LOG\Recovery"
if not exist "..\Apps" mkdir "..\Apps"

set MASTERLOG=..\LOG\Master_Log.txt
set CYCLEFILE=..\LOG\cycle.tmp

:: Rendszergazda és Nyelv detektálása
net session >nul 2>&1
if %errorLevel% neq 0 (echo [HIBA] Futtasd rendszergazdakent! & pause & exit)

for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v InstallLanguage 2^>nul') do set LANG_HEX=%%a
if "%LANG_HEX%"=="040e" (set "SYS_LANG=hu-HU") else (set "SYS_LANG=en-US")

if exist "%CYCLEFILE%" (
    set /p CYCLE=<"%CYCLEFILE%"
    echo [%date% %time%] Folytatas: !CYCLE!. ciklus... >> "%MASTERLOG%"
    goto RUN_ENGINE
)

:MENU
cls
echo =======================================================
echo [Defrager Master - Biztonsagi Modullal]
echo =======================================================
echo 1. Mely-karbantartas (3x Defrag + 2x Scandisk + S.M.A.R.T.)
echo 2. Heti utemezes beallitasa
echo 3. Grafikus felulet (GUI) es Szolgaltatas javitas
echo 4. Kilepes
echo -------------------------------------------------------
set /p opt="Valasztas: "

if "%opt%"=="1" (echo 3 > "%CYCLEFILE%" & goto RUN_ENGINE)
if "%opt%"=="2" (
    schtasks /create /tn "Weekly_Defrag" /tr "%~f0" /sc weekly /d MON /st 01:00 /rl highest /f
    pause & goto MENU
)
if "%opt%"=="3" (call :FIX_GUI & pause & goto MENU)
exit


:RUN_ENGINE
set /p CYCLE=<"%CYCLEFILE%"

:: Akkumulátor ellenőrzése
for /f "tokens=2 delims==" %%a in ('wmic path Win32_Battery get BatteryStatus /value 2^>nul') do set BATTERY_STATUS=%%a
if "%BATTERY_STATUS%"=="1" (
    echo [FIGYELEM] A gep akkumulatorrol uzemel! A folyamat megszakadt.
    del "%CYCLEFILE%" & pause & goto MENU
)

:: Verzió-kontrollált és erőszakos frissítés
if exist "..\Apps\defrag.exe" (
    echo [INFO] Verzio-ellenorzes folyamatban... >> "%MASTERLOG%"
    
    for /f "usebackq" %%v in (`powershell "(Get-Item 'C:\Windows\System32\defrag.exe').VersionInfo.FileVersion"`) do set "CUR_VER=%%v"
    for /f "usebackq" %%v in (`powershell "(Get-Item '..\Apps\defrag.exe').VersionInfo.FileVersion"`) do set "NEW_VER=%%v"

    if "!NEW_VER!" GTR "!CUR_VER!" (
        echo [INFO] Ujabb verzio talalva (!NEW_VER!). Kenyszeritett frissites... >> "%MASTERLOG%"
        
        :: Registry javítás alkalmazása (ha van)
        if exist "GUI_Fix.reg" regedit.exe /s "GUI_Fix.reg"

        set "FILES=defrag.exe defragres.dll dfrgui.exe"
        for %%f in (!FILES!) do (
            if exist "..\Apps\%%f" (
                :: Erőszakos jogátvétel és attribútum törlés
                attrib -r -s -h "C:\Windows\System32\%%f" >nul 2>&1
                takeown /f "C:\Windows\System32\%%f" /a >nul 2>&1
                icacls "C:\Windows\System32\%%f" /grant administrators:F >nul 2>&1
                
                :: Próba: Törlés és másolás a System32-be
                del /f /q "C:\Windows\System32\%%f" >nul 2>&1
                copy /y "..\Apps\%%f" "C:\Windows\System32\%%f" >nul

                :: Nyelvi mappa kezelése
                if not exist "C:\Windows\System32\!SYS_LANG!" mkdir "C:\Windows\System32\!SYS_LANG!"
                if exist "..\Apps\!SYS_LANG!\%%f" (
                    copy /y "..\Apps\!SYS_LANG!\%%f" "C:\Windows\System32\!SYS_LANG!\%%f" >nul
                )
            )
        )
    ) else (
        echo [INFO] A rendszer mar a legfrissebb verziot hasznalja. >> "%MASTERLOG%"
    )
)


powershell -ExecutionPolicy Bypass -File "Defrager.ps1" -Cycle !CYCLE!

set /a NEXT_CYCLE=!CYCLE!-1
if !NEXT_CYCLE! leq 0 (
    del "%CYCLEFILE%"
    echo [KESZ] Karbantartas befejezve. >> "%MASTERLOG%"
    pause & exit
)
echo !NEXT_CYCLE! > "%CYCLEFILE%"
echo y | chkdsk C: /f
shutdown /r /t 15 /c "Karbantartas: Ujrainditas..."
exit

:FIX_GUI
sc config defragsvc start= demand
net start defragsvc
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\dfrgui.exe" /ve /t REG_SZ /d "C:\Windows\System32\dfrgui.exe" /f
goto :eof
