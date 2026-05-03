# =============================================================================
# Launcher.ps1 - Kozponti vezerlo
# RTS Keretrendszer - Defrager projekt
# =============================================================================
# Indulaskor:
#   - Log vizsgalat: volt-e mar futtatva? Ha igen, melyik muvelet volt utoljara?
#   - Elso inditas: automatikus allapotfelmeres (Searching)
#   - Minden muvelet utan: visszaellenorzes, eredmeny LOG-ba
#   - Kepernyo: "Clear-Host do {" sorrend -> muvelet kimenete olvashato
# =============================================================================

#Requires -Version 3.0

# --- JOGOSULTSAG ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- UTVONALAK ---
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot    = if ($ScriptDir -like "*Scripts") { Split-Path -Parent $ScriptDir } else { $ScriptDir }

$ScriptsPath = Join-Path $RepoRoot "Scripts"
$LogDir      = Join-Path $RepoRoot "Logs"
$DataDir     = Join-Path $RepoRoot "data"
$AppsDir     = Join-Path $RepoRoot "Apps"
$RepoWorkDir = Join-Path $RepoRoot "HardWorkerJack"
$TempLogDir  = "C:\Temp\LOG"
$TempWorkDir = "C:\Temp\HardWorkerJack"

# --- MAPPAK LETREHOZASA ---
foreach ($Dir in @($LogDir, $DataDir, $AppsDir, $ScriptsPath, $RepoWorkDir, $TempLogDir, $TempWorkDir)) {
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
}

# --- ALVASGATLO ES LAPTOP FIGYELMEZTES ---
try { powercfg -requestsoverride driver "System" display system 2>$null } catch {}
try { powercfg /x -standby-timeout-ac 0 2>$null } catch {}

# --- LOGOLAS (duplan) ---
$LogPath     = Join-Path $LogDir "Launcher.log"
$TempLogPath = Join-Path $TempLogDir "Launcher.log"

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Msg"
    try { $Line | Out-File -FilePath $LogPath -Append -Encoding UTF8 } catch {}
    try { $Line | Out-File -FilePath $TempLogPath -Append -Encoding UTF8 } catch {}
    Write-Host $Msg -ForegroundColor $Color
}

# =============================================================================
# LOG-ALAPU ALLAPOT KEZELES
# =============================================================================

# Az utolso befejezett muvelet kiolvasasa a LOG-bol
function Get-LastCompletedAction {
    if (!(Test-Path $LogPath)) { return $null }
    $Lines = Get-Content $LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
    # Az utolso "[KESZ]" vagy "[MUVELET_KESZ]" sort keressuk
    $Last = $Lines | Where-Object { $_ -match "\[MUVELET_KESZ\]" } | Select-Object -Last 1
    if ($Last) {
        if ($Last -match "\[MUVELET_KESZ\]\s+(.+)$") { return $Matches[1].Trim() }
    }
    return $null
}

# Elso inditas detektalasa: nincs LOG, vagy a LOG ures/csak fejlec
function Test-IsFirstRun {
    if (!(Test-Path $LogPath)) { return $true }
    $Lines = Get-Content $LogPath -Encoding UTF8 -ErrorAction SilentlyContinue
    $Meaningful = $Lines | Where-Object { $_ -match "\[MUVELET_KESZ\]|\[START\]|\[HIBA\]" }
    return ($Meaningful.Count -eq 0)
}

# Muvelet elvegzese + visszaellenorzese + LOG-olas
function Invoke-Action {
    param(
        [string]$ActionName,
        [string]$ScriptFile,
        [string]$ActionKey
    )

    if (!(Test-Path $ScriptFile)) {
        Write-Log "[HIBA] Script nem talalhato: $ScriptFile" "Red"
        return $false
    }

    Write-Log "[START] $ActionName indul..." "Yellow"
    try {
        & $ScriptFile
        $ExitOK = $true
    } catch {
        Write-Log "[HIBA] $ActionName hibara futott: $($_.Exception.Message)" "Red"
        $ExitOK = $false
    }

    if ($ExitOK) {
        Write-Log "[MUVELET_KESZ] $ActionKey" "Green"
        Write-Log "[OK] $ActionName sikeresen befejezodott." "Green"
    } else {
        Write-Log "[MUVELET_HIBA] $ActionKey" "Red"
    }
    return $ExitOK
}

# =============================================================================
# INDULASI LOGIKA
# =============================================================================

$IsFirstRun  = Test-IsFirstRun
$LastAction  = Get-LastCompletedAction

# Laptop ellenorzes - figyelmeztes megjelenitese
$OnBattery = (Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue) -ne $null
$BatteryStatus = if ($OnBattery) {
    $Bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    $Bat.BatteryStatus   # 2 = feltoltes alatt, 1 = akksi
} else { 0 }

# =============================================================================
# MENU
# =============================================================================

Clear-Host
do {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     DEFRAGER - KOZPONTI VEZERLO          ║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  Gyoker: $($RepoRoot.PadRight(33))║" -ForegroundColor Gray
    if ($LastAction) {
        Write-Host "║  Utolso muvelet: $($LastAction.PadRight(24))║" -ForegroundColor DarkGreen
    }
    if ($IsFirstRun) {
        Write-Host "║  *** ELSO INDITAS - Allapotfelmeres ajanl. ***  ║" -ForegroundColor Yellow
    }
    if ($OnBattery -and $BatteryStatus -eq 1) {
        Write-Host "║  ⚠ FIGYELEM: Akkumulator! Csatlakoztasson toltot!  ║" -ForegroundColor Red
    }
    Write-Host "╠══════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  1. Rendszerfajlok keresese + ellenorzese (Searching)    ║" -ForegroundColor White
    Write-Host "║  2. Hianyzo fajlok beszerzese (HardWorkerJack)           ║" -ForegroundColor White
    Write-Host "║  3. Rendszer defrag verzio lekerdezese / frissitese      ║" -ForegroundColor White
    Write-Host "║  4. Toredezettsegmentesites                              ║" -ForegroundColor White
    Write-Host "║  5. Lemezellenorzes (Scandisk/chkdsk)                    ║" -ForegroundColor White
    Write-Host "║  6. Korkoros karbantartas (Defrag+Scandisk+Defrag)       ║" -ForegroundColor White
    Write-Host "║  7. Automatikus karbantartas utemezese                   ║" -ForegroundColor White
    Write-Host "║  8. Logok megtekintese                                   ║" -ForegroundColor White
    Write-Host "║  Q. Kilepes                                              ║" -ForegroundColor DarkGray
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Elso inditas: automatikus javaslat
    if ($IsFirstRun) {
        Write-Host "[JAVASLAT] Elso inditas eszlelve. Ajanlott: 1 (Allapotfelmeres)" -ForegroundColor Yellow
    }

    $choice = Read-Host "Valassz menupontot"

    switch ($choice.ToUpper()) {

        "1" {
            $SF = Join-Path $ScriptsPath "Searching.ps1"
            Invoke-Action -ActionName "Searching - Allapotfelmeres" -ScriptFile $SF -ActionKey "Searching"
            $IsFirstRun = $false
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "2" {
            if ($OnBattery -and $BatteryStatus -eq 1) {
                Write-Host "[FIGYELEM] Akkumulatoros uzemmod! Folytassuk? [I/N]" -ForegroundColor Red
                $Confirm = Read-Host
                if ($Confirm -ne "I" -and $Confirm -ne "i") { break }
            }
            $SF = Join-Path $ScriptsPath "HardWorkerJack.ps1"
            Invoke-Action -ActionName "HardWorkerJack - Beszerzo" -ScriptFile $SF -ActionKey "HardWorkerJack"
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "3" {
            # Rendszer defrag verzio lekerdezese + frissites ajanlat
            Write-Log "[START] Rendszer defrag verzio ellenorzese..." "Yellow"
            $SysDefrag = "$env:SystemRoot\System32\defrag.exe"
            if (Test-Path $SysDefrag) {
                $SysVer = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($SysDefrag).FileVersion.Trim()
                Write-Host ""
                Write-Host "  Rendszer defrag.exe verzioja: $SysVer" -ForegroundColor Cyan

                # Keresunk jobb verziot az /Apps-ban
                $Better = Get-ChildItem $AppsDir -Filter "defrag_v*_x64.exe" -ErrorAction SilentlyContinue |
                          Sort-Object { [version](($_.BaseName -split '_v')[1] -split '_')[0] } -Descending |
                          Select-Object -First 1

                if ($Better) {
                    $AppsVer = (($Better.BaseName -split '_v')[1] -split '_')[0]
                    try {
                        if ([version]$AppsVer -gt [version]$SysVer) {
                            Write-Host "  /Apps-ban frissebb verzio talalhato: $AppsVer ($($Better.Name))" -ForegroundColor Green
                            Write-Host "  Frissites a SystemUpgrade.ps1 segitsegevel vegezheto el." -ForegroundColor Yellow
                            Write-Log "[INFO] Frissitheto: rendszer v$SysVer -> Apps v$AppsVer" "Yellow"
                        } else {
                            Write-Host "  A rendszeren mar a legjobb elerheto verzio fut." -ForegroundColor Green
                            Write-Log "[OK] Rendszer defrag versio aktualis: v$SysVer" "Green"
                        }
                    } catch {
                        Write-Host "  Verzio osszehasonlitas sikertelen (v$SysVer vs v$AppsVer)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  Az /Apps mappaban nincs frissebb defrag.exe verzio." -ForegroundColor Gray
                    Write-Host "  Futtasd a 2. menupontot a beszerzeshez!" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [HIBA] defrag.exe nem talalhato: $SysDefrag" -ForegroundColor Red
            }
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "4" {
            $SF = Join-Path $ScriptsPath "Defrager.ps1"
            Invoke-Action -ActionName "Toredezettsegmentesites" -ScriptFile $SF -ActionKey "Defrag"
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "5" {
            $SF = Join-Path $ScriptsPath "Scandisk.ps1"
            if (!(Test-Path $SF)) {
                # Ha meg nincs Scandisk.ps1, chkdsk kozvetlenul
                Write-Log "[INFO] Scandisk.ps1 meg nem keszult, chkdsk kozvetlenul indul..." "Yellow"
                $DriveLetter = Read-Host "Melyik meghajton? (pl. C)"
                Write-Log "[START] chkdsk $DriveLetter`: /f /r - kovetkezo ujraindulaskor fut le" "Yellow"
                & chkdsk.exe "$($DriveLetter):" /f /r /x
                Write-Log "[MUVELET_KESZ] Scandisk_chkdsk" "Green"
            } else {
                Invoke-Action -ActionName "Lemezellenorzes (Scandisk)" -ScriptFile $SF -ActionKey "Scandisk"
            }
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "6" {
            Write-Host ""
            Write-Host "[FIGYELEM] Korkoros karbantartas: Defrag -> Scandisk (reboot) -> Defrag -> Allapot" -ForegroundColor Yellow
            Write-Host "A gep tobb alkalommal ujra fog indulni!" -ForegroundColor Yellow
            if ($OnBattery -and $BatteryStatus -eq 1) {
                Write-Host "[STOP] Akkumulatoros uzemmodban ez a muvelet NEM indithato!" -ForegroundColor Red
                Read-Host "Nyomj Entert..."
                break
            }
            $Confirm = Read-Host "Biztosan folytatod? Ments el minden nyitott munkat! [I/N]"
            if ($Confirm -eq "I" -or $Confirm -eq "i") {
                $SF = Join-Path $ScriptsPath "Circular.ps1"
                if (Test-Path $SF) {
                    Invoke-Action -ActionName "Korkoros karbantartas" -ScriptFile $SF -ActionKey "Circular"
                } else {
                    Write-Log "[INFO] Circular.ps1 meg nem keszult - kesobbi fazis!" "Yellow"
                    Write-Host "Ez a funkcio (6. fazis) meg fejlesztes alatt all." -ForegroundColor DarkGray
                }
            }
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "7" {
            Write-Host ""
            Write-Host "Automatikus karbantartas utemezese" -ForegroundColor Cyan
            Write-Host "Valassz gyakorisagot:" -ForegroundColor White
            Write-Host "  1. Heti"
            Write-Host "  2. Ketheti"
            Write-Host "  3. Havi"
            Write-Host "  4. 3 havonta"
            Write-Host "  5. 6 havonta"
            $FreqChoice = Read-Host "Valasztas"
            $FreqMap = @{ "1"="Weekly"; "2"="WEEKLY"; "3"="Monthly"; "4"="Monthly"; "5"="Monthly" }
            $FreqLabel = @{ "1"="Heti"; "2"="Ketheti"; "3"="Havi"; "4"="3 havonta"; "5"="6 havonta" }
            if ($FreqMap.ContainsKey($FreqChoice)) {
                $SF = Join-Path $ScriptsPath "Defrager.ps1"
                $TriggerArgs = switch ($FreqChoice) {
                    "2" { "/SC WEEKLY /D MON,THU" }
                    "4" { "/SC MONTHLY /M 1,4,7,10 /D 1" }
                    "5" { "/SC MONTHLY /M 1,7 /D 1" }
                    default { "/SC $($FreqMap[$FreqChoice])" }
                }
                $TaskCmd = "schtasks /Create /TN ""Defrager_Auto"" /TR ""powershell.exe -NoProfile -ExecutionPolicy Bypass -File '$SF'"" $TriggerArgs /F"
                Write-Log "[START] Scheduled Task letrehozasa: $($FreqLabel[$FreqChoice])" "Yellow"
                try {
                    Invoke-Expression $TaskCmd
                    Write-Log "[MUVELET_KESZ] ScheduledTask_$($FreqLabel[$FreqChoice])" "Green"
                    Write-Host "Utemezett feladat letrehozva: $($FreqLabel[$FreqChoice])" -ForegroundColor Green
                } catch {
                    Write-Log "[HIBA] Task letrehozas sikertelen: $($_.Exception.Message)" "Red"
                }
            }
            $LastAction = Get-LastCompletedAction
            Write-Host ""
            Read-Host "Nyomj Entert a menuhoz..."
        }

        "8" {
            Write-Host ""
            Write-Host "Melyik logot szeretne megnyitni?" -ForegroundColor Cyan
            Write-Host "  1. Launcher.log (Repo)"
            Write-Host "  2. HardWorkerJack.log (Repo)"
            Write-Host "  3. Searching.log (Repo)"
            Write-Host "  4. Launcher.log (Temp: C:\Temp\LOG)"
            $LogChoice = Read-Host "Valasztas"
            $LogFiles = @{
                "1" = $LogPath
                "2" = Join-Path $LogDir "HardWorkerJack.log"
                "3" = Join-Path $LogDir "Searching.log"
                "4" = $TempLogPath
            }
            if ($LogFiles.ContainsKey($LogChoice)) {
                $LF = $LogFiles[$LogChoice]
                if (Test-Path $LF) { Start-Process notepad.exe $LF }
                else { Write-Host "Log fajl meg nem letezik: $LF" -ForegroundColor Yellow }
            }
            # Nem pauzalunk itt, mert a Notepad hatterben nyilik
        }

        "Q" {
            Write-Log "--- LAUNCHER BEZARVA ---" "Gray"
            break
        }

        default {
            Write-Host "Ervenytelen valasztas: $choice" -ForegroundColor Red
        }
    }

    Clear-Host

} while ($choice.ToUpper() -ne "Q")
