# Launcher.ps1 - Kozponti vezerlo
# 1. Jogosultsag emeles
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2. Kornyezet es Vedelmek beallitasa
powercfg -requestsoverride driver "System" display system
powercfg /x -standby-timeout-ac 0
if ((Get-WmiObject -Class Win32_Battery) -ne $null) {
    Write-Host "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot!" -ForegroundColor Yellow
}

# Utvonalak
$ScriptsPath = Join-Path $PSScriptRoot "..\Scripts"
$LogPath     = Join-Path $PSScriptRoot "..\Logs\Launcher.log"
$TempLog     = "C:\Temp\LOG\Launcher.log"

function Write-Log($msg, $color = "White") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $LogPath -Append
    "$timestamp - $msg" | Out-File -FilePath $TempLog -Append
    Write-Host $msg -ForegroundColor $color
}

# Menu rendszer
do {
    Clear-Host
    Write-Host "=== DEFRAGER KOZPONTI VEZERLO ===" -ForegroundColor Cyan
    Write-Host "1. Rendszerfajlok keresese es ellenorzese (Searching)"
    Write-Host "2. Hianyzo fajlok beszerzese (HardWorkerJack)"
    Write-Host "3. Automatikus karbantartas beutemezese (SetupTask)"
    Write-Host "4. Logok megtekintese"
    Write-Host "Q. Kilepes"
    Write-Host "--------------------------------"
    $choice = Read-Host "Valassz egy menupontot"

    switch ($choice) {
        "1" {
            Write-Log "[START] Searching.ps1 inditasa..." -color Yellow
            & "$ScriptsPath\Searching.ps1"
            Pause
        }
        "2" {
            Write-Log "[START] HardWorkerJack.ps1 inditasa..." -color Yellow
            & "$ScriptsPath\HardWorkerJack.ps1"
            Pause
        }
        "3" {
            Write-Log "[START] Scheduled Task letrehozasa..." -color Yellow
            # Ide jön majd a beütemező rész, amit korábban írtunk
            Write-Host "Funkcio hamarosan..."
            Pause
        }
        "4" {
            if (Test-Path $LogPath) { notepad.exe $LogPath }
        }
    }
} while ($choice -ne "Q")

Write-Log "--- LAUNCHER BEZARVA ---"
