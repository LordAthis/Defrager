# Launcher.ps1 - Kozponti vezerlo (Javitott, dinamikus utvonalakkal)

# 1. Jogosultsag emeles
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2. Dinamikus utvonalak meghatarozasa
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Ellenorizzuk, hogy a Scripts mappaban vagyunk-e, vagy a gyokerben
if ($PSScriptRoot -like "*Scripts") {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
} else {
    $RepoRoot = $PSScriptRoot
}

$ScriptsPath = Join-Path $RepoRoot "Scripts"
$LogDir      = Join-Path $RepoRoot "Logs"
$DataDir     = Join-Path $RepoRoot "data"
$AppsDir     = Join-Path $RepoRoot "Apps"
$TempLogDir  = "C:\Temp\LOG"

# 3. Mappak ellenorzese es letrehozasa (1-es es 2-es pontod)
$RequiredDirs = @($LogDir, $DataDir, $AppsDir, $TempLogDir, $ScriptsPath)
foreach ($Dir in $RequiredDirs) {
    if (!(Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }
}

# 4. Kornyezet es Vedelmek beallitasa
powercfg -requestsoverride driver "System" display system
powercfg /x -standby-timeout-ac 0
if ((Get-WmiObject -Class Win32_Battery) -ne $null) {
    Write-Host "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot!" -ForegroundColor Yellow
}

# 5. Logolas funkcio (Most mar biztosan leteznek a mappak)
$LogPath = Join-Path $LogDir "Launcher.log"
$TempLogPath = Join-Path $TempLogDir "Launcher.log"

function Write-Log($msg, $color = "White") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $msg"
    try {
        $line | Out-File -FilePath $LogPath -Append
        $line | Out-File -FilePath $TempLogPath -Append
    } catch {
        Write-Host "[HIBA] Nem sikerult a logolas: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host $msg -ForegroundColor $color
}

# Menu rendszer
do {
    Clear-Host
    Write-Host "=== DEFRAGER KOZPONTI VEZERLO ===" -ForegroundColor Cyan
    Write-Host "Gyoker konyvtar: $RepoRoot" -ForegroundColor Gray
    Write-Host "--------------------------------"
    Write-Host "1. Rendszerfajlok keresese es ellenorzese (Searching)"
    Write-Host "2. Hianyzo fajlok beszerzese (HardWorkerJack)"
    Write-Host "3. Állapot lekérdezése"
    Write-Host "4. Töredezettség mentesítés indítása"
    Write-Host "5. Lemezellenőrzés"
    Write-Host "6. Körkörös karbantartás - Erősen töredezett, használt meghajtók esetén!"
    Write-Host "7. Automatikus karbantartas beutemezese (SetupTask)"
    Write-Host "8. Logok megtekintese"
    Write-Host "Q. Kilepes"
    Write-Host "--------------------------------"
    $choice = Read-Host "Valassz egy menupontot"

    switch ($choice) {
        "1" {
            $ScriptFile = Join-Path $ScriptsPath "Searching.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] Searching.ps1 inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "2" {
            $ScriptFile = Join-Path $ScriptsPath "HardWorkerJack.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] HardWorkerJack.ps1 inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "3" {
            $ScriptFile = Join-Path $ScriptsPath "xxx3.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] xxx3.ps1 inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "4" {
            $ScriptFile = Join-Path $ScriptsPath "Defrager.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] Toredezettsegmentesites 'Defrager.ps1' inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "5" {
            $ScriptFile = Join-Path $ScriptsPath "xxx5.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] xxx5.ps1 inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "6" {
            $ScriptFile = Join-Path $ScriptsPath "xxx6.ps1"
            if (Test-Path $ScriptFile) {
                Write-Log "[START] xxx6.ps1 inditasa..." Yellow
                & $ScriptFile
            } else {
                Write-Log "[HIBA] Nem talalhato: $ScriptFile" Red
            }
            Pause
        }
        "7" {
            Write-Log "[START] Scheduled Task letrehozasa..." Yellow
            Write-Host "Funkcio hamarosan..."
            Pause
        }
        "8" {
            if (Test-Path $LogPath) { notepad.exe $LogPath }
        }
    }
} while ($choice -ne "Q")

Write-Log "--- LAUNCHER BEZARVA ---"
