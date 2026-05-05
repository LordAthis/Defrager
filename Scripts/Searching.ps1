# =============================================================================
# Searching.ps1 - Fajl-allapot ellenorzo es kereso modul
# RTS Keretrendszer - Defrager projekt
# =============================================================================
# Keresesi prioritas-sorrend:
#   1. /Apps           - verzios fajlok (vegleges, hasznalatra kesz)
#   2. /HardWorkerJack - repo-beli nyers letoltesek / csomagok
#   3. C:\Temp\HardWorkerJack - ideiglenes nyers letoltesek / csomagok
# =============================================================================

#Requires -Version 3.0

# --- UTVONALAK ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot  = if ($ScriptDir -like "*Scripts") { Split-Path -Parent $ScriptDir } else { $ScriptDir }

$AppsPath       = Join-Path $RepoRoot "Apps"
$RepoWorkPath   = Join-Path $RepoRoot "HardWorkerJack"
$TempWorkPath   = "C:\Temp\HardWorkerJack"
$DataPath       = Join-Path $RepoRoot "data"
$LogDir         = Join-Path $RepoRoot "Logs"
$JsonFile       = Join-Path $DataPath "Compatibility.json"

# --- MAPPAK ---
foreach ($Dir in @($AppsPath, $RepoWorkPath, $TempWorkPath, $LogDir)) {
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
}

# --- LOGOLAS ---
$LogPath    = Join-Path $LogDir "Searching.log"
$TempLogDir = "C:\Temp\LOG"
$TempLogPath = Join-Path $TempLogDir "Searching.log"
if (!(Test-Path $TempLogDir)) { New-Item -ItemType Directory -Path $TempLogDir -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Msg"
    try { $Line | Out-File -FilePath $LogPath -Append -Encoding UTF8 } catch {}
    try { $Line | Out-File -FilePath $TempLogPath -Append -Encoding UTF8 } catch {}
    Write-Host $Msg -ForegroundColor $Color
}

# --- KONFIG BETOLTESE ---
if (!(Test-Path $JsonFile)) {
    Write-Log "[HIBA] Compatibility.json nem talalhato: $JsonFile" "Red"
    exit 1
}
try {
    $Config = Get-Content $JsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Log "[HIBA] JSON feldolgozhatatlan: $($_.Exception.Message)" "Red"
    exit 1
}

# =============================================================================
# SEGEDFUGGVENYEK
# =============================================================================

# Verzios nev keszitese (pl. defrag_v10.0.19041.0_x64.exe)
function Get-VersionedName {
    param([string]$FileName, [string]$Version, [string]$Arch)
    $Base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Ext  = [System.IO.Path]::GetExtension($FileName)
    return "${Base}_v${Version}_${Arch}${Ext}"
}

# Verzioszam lekerdezese egy fajlbol - csak a szamjegyeket es pontokat tartja meg
function Get-FileVer {
    param([string]$FilePath)
    try {
        $v = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath).FileVersion
        if (!$v) { return "0.0.0.0" }
        $v = $v.Trim()
        # Csak az elso "szam.szam..." reszt tartjuk meg, a zarojelest levagjuk
        if ($v -match "^(\d+\.\d+[\.\d]*)") { $v = $Matches[1] }
        # Max 4 komponens kell a [version]-hoz
        $parts = $v.Split(".")
        if ($parts.Count -gt 4) { $v = ($parts[0..3] -join ".") }
        return $v
    } catch { return "0.0.0.0" }
}

# Biztonsagos verzio-osszehasonlitas - nem dob hibat ervenytelen stringre
function Compare-Version {
    param([string]$Current, [string]$Minimum)
    try {
        return ([version]$Current -ge [version]$Minimum)
    } catch {
        return ($Current -ge $Minimum)
    }
}

# MD5 hash lekerdezese
function Get-MD5 {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm MD5).Hash
}

# Keresesi helyek vegigpasztazasa egy adott nev/architektura-mintara
# Visszaad egy [PSCustomObject] listat: @{Path, Location, VersionedName}
function Find-TargetInAllLocations {
    param(
        [string]$FileName,
        [string]$Arch
    )

    $Base    = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Ext     = [System.IO.Path]::GetExtension($FileName).TrimStart(".")
    $Results = @()

    # 1. /Apps - verzios nevek
    $Pattern = "${Base}_v*_${Arch}.${Ext}"
    $Found = Get-ChildItem $AppsPath -Filter $Pattern -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending
    foreach ($F in $Found) {
        $Results += [PSCustomObject]@{
            Path          = $F.FullName
            Location      = "Apps"
            VersionedName = $F.Name
        }
    }

    # 2. /HardWorkerJack (repo) - eredeti neveken es verzios neveken is
    foreach ($SearchName in @($FileName, "${Base}_v*_${Arch}.${Ext}")) {
        $Found = Get-ChildItem $RepoWorkPath -Filter $SearchName -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending
        foreach ($F in $Found) {
            $Results += [PSCustomObject]@{
                Path          = $F.FullName
                Location      = "RepoWork"
                VersionedName = $F.Name
            }
        }
    }

    # 3. C:\Temp\HardWorkerJack - ugyanugy
    foreach ($SearchName in @($FileName, "${Base}_v*_${Arch}.${Ext}")) {
        $Found = Get-ChildItem $TempWorkPath -Filter $SearchName -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending
        foreach ($F in $Found) {
            $Results += [PSCustomObject]@{
                Path          = $F.FullName
                Location      = "TempWork"
                VersionedName = $F.Name
            }
        }
    }

    return $Results
}

# =============================================================================
# FO LOGIKA
# =============================================================================

Clear-Host
Write-Log "=== SEARCHING - FAJL ALLAPOT ELLENORZES ===" "Cyan"
Write-Log "Repo gyoker: $RepoRoot" "Gray"
Write-Log "--------------------------------------------" "Gray"

# Csoportositunk FileName+Architecture alapjan (JSON-ban tobb URL lehet egyhez)
$UniqueTargets = $Config.TargetFiles |
    Sort-Object FileName, Architecture -Unique |
    Group-Object { "$($_.FileName)|$($_.Architecture)" }

# Osszesito szamlalok
$CountOK      = 0
$CountOld     = 0
$CountMissing = 0
$CountRaw     = 0   # nyers, meg nem Apps-ban levo

foreach ($Group in $UniqueTargets) {
    $Target = $Group.Group[0]   # Az elso elem hordozza a MinVersion, MD5 stb. adatokat
    $FileName = $Target.FileName
    $Arch     = $Target.Architecture
    $MinVer   = $Target.MinVersion
    $ExpMD5   = $Target.MD5

    Write-Log "" "White"
    Write-Log "[ $FileName | $Arch | min. v$MinVer ]" "White"

    $AllFound = Find-TargetInAllLocations -FileName $FileName -Arch $Arch

    if ($AllFound.Count -eq 0) {
        Write-Log "  [HIANY] Sehol nem talalhato - letoltes szukseges!" "Yellow"
        $CountMissing++
        continue
    }

    # Kiirjuk az osszes talalt peldanyt, helyszin szerint
    $AppsFiles    = $AllFound | Where-Object { $_.Location -eq "Apps" }
    $RepoFiles    = $AllFound | Where-Object { $_.Location -eq "RepoWork" }
    $TempFiles    = $AllFound | Where-Object { $_.Location -eq "TempWork" }

    # --- /Apps ellenorzese ---
    if ($AppsFiles.Count -gt 0) {
        $BestApps = $AppsFiles | Select-Object -First 1
        $CurVer   = Get-FileVer -FilePath $BestApps.Path
        $CurMD5   = Get-MD5 -FilePath $BestApps.Path

        $VerOK  = Compare-Version -Current $CurVer -Minimum $MinVer
        $HashOK = ($ExpMD5 -eq "FeltoltesUtanFrissitendo") -or ($CurMD5 -eq $ExpMD5)

        if ($VerOK -and $HashOK) {
            Write-Log "  [OK]    /Apps: $($BestApps.VersionedName) (v$CurVer)" "Green"
            $CountOK++
        } elseif (!$VerOK) {
            Write-Log "  [REGI]  /Apps: $($BestApps.VersionedName) (v$CurVer < v$MinVer) - frissites ajanlott!" "Red"
            $CountOld++
        } else {
            Write-Log "  [HASH!] /Apps: $($BestApps.VersionedName) - hash elteres! Ujratoltes ajanlott." "Red"
            $CountOld++
        }

        # Tobbi Apps-ban levo verzio listazasa
        foreach ($F in ($AppsFiles | Select-Object -Skip 1)) {
            $V = Get-FileVer -FilePath $F.Path
            Write-Log "          (regi verzio) /Apps: $($F.VersionedName) v$V" "DarkGray"
        }
    } else {
        Write-Log "  [INFO]  /Apps-ban nem talalhato verzios peldany." "Gray"
        $CountMissing++
    }

    # --- /HardWorkerJack (repo) ---
    if ($RepoFiles.Count -gt 0) {
        Write-Log "  [NYERS] /HardWorkerJack (repo) - feldolgozatlan csomagok:" "Cyan"
        foreach ($F in $RepoFiles) {
            $V = Get-FileVer -FilePath $F.Path
            Write-Log "          $($F.VersionedName)  (v$V)" "Cyan"
        }
        $CountRaw++
    }

    # --- C:\Temp\HardWorkerJack ---
    if ($TempFiles.Count -gt 0) {
        Write-Log "  [NYERS] C:\Temp\HardWorkerJack - feldolgozatlan csomagok:" "DarkCyan"
        foreach ($F in $TempFiles) {
            $V = Get-FileVer -FilePath $F.Path
            Write-Log "          $($F.VersionedName)  (v$V)" "DarkCyan"
        }
        $CountRaw++
    }
}

# --- OSSZESITO ---
Write-Log "" "White"
Write-Log "============================================" "Gray"
Write-Log " OSSZESITO:" "White"
Write-Log "  [OK]    Megfelelo fajlok (Apps): $CountOK"     "Green"
Write-Log "  [REGI]  Elavult / hash hiba:     $CountOld"    "Red"
Write-Log "  [HIANY] Sehol sem talalhato:     $CountMissing" "Yellow"
Write-Log "  [NYERS] Feldolgozando csomagok:  $CountRaw"    "Cyan"
Write-Log "============================================" "Gray"
Write-Log "Log mentve: $LogPath" "Gray"
