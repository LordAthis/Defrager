@echo off
:: OS verzió detektálása (ver parancs alapján)
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j

if "%VERSION%"=="4.10" goto WIN98
if "%VERSION%"=="5.1" goto WINXP
if "%VERSION%"=="10.0" goto WIN10

:WIN10
:: Modern Windows: Minden meghajtó, optimalizálás (SSD+HDD), magas prioritás
defrag.exe /C /O /V /H
goto END

:WINXP
:: XP: Kényszerített mód, mert gyakran elutasítja a kevés hely miatt
defrag.exe C: -f -v
goto END

:END
pause
