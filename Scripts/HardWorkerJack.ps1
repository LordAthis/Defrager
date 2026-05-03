# =============================================================================
# HardWorkerJack.ps1 - Intelligens beszerzo motor
# RTS Keretrendszer - Defrager projekt
# =============================================================================
# Muveleti sorrend (minden Target-fajlhoz):
#   1. Keresés: /Apps (verzios) → /HardWorkerJack (repo) → C:\Temp\HardWorkerJack
#   2. Ha talalt nyers csomagot (.msu/.cab/.exe/.iso) → feldolgoz
#   3. Ha semmit sem talalt → letoltes megkiserlese
#   4. Ha letoltes sem megy → bongeszo + felhasznaloi varakozas
#   5. Feldolgozas: kicsomagol → verziót leker → verziozott nevvel /Apps-ba
#   6. Opcionalis: ISO banyaszat (manualis vagy CD/DVD/Pendrive)
#   7. Temp mappa NEM torolodik automatikusan - felhasznalo donthet
# =============================================================================

#Requires -Version 3.0

# --- JOGOSULTSAG ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- UTVONALAK ---
$ScriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot       = if ($ScriptDir -like "*Scripts") { Split-Path -Parent $ScriptDir } else { $ScriptDir }

$AppsPath       = Join-Path $RepoRoot "Apps"
$DataPath       = Join-Path $RepoRoot "data"
$LogDir         = Join-Path $RepoRoot "Logs"
$RepoWorkPath   = Join-Path $RepoRoot "HardWorkerJack"        # Repo-beli nyers csomagok
$TempWorkPath   = "C:\Temp\HardWorkerJack"                    # Ideiglenes munkamappa
$TempLogDir     = "C:\Temp\LOG"

# --- MAPPAK LETREHOZASA ---
foreach ($Dir in @($AppsPath, $LogDir, $RepoWorkPath, $TempWorkPath, $TempLogDir)) {
    if (!(Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
}

# --- LOGOLAS (duplan: repo + temp) ---
$RepoLog = Join-Path $LogDir "HardWorkerJack.log"
$TempLog = Join-Path $TempLogDir "HardWorkerJack.log"

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Msg"
    try { $Line | Out-File -FilePath $RepoLog -Append -Encoding UTF8 } catch {}
    try { $Line | Out-File -FilePath $TempLog -Append -Encoding UTF8 } catch {}
    Write-Host $Msg -ForegroundColor $Color
}

# --- ALVASGATLO ES LAPTOP FIGYELMEZTES ---
try { powercfg -requestsoverride driver "System" display system 2>$null } catch {}
try { powercfg /x -standby-timeout-ac 0 2>$null } catch {}
if ((Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue) -ne $null) {
    Write-Log "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot!" "Yellow"
}

# --- KONFIG BETOLTESE ---
$JsonFile = Join-Path $DataPath "Compatibility.json"
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

Write-Log "=== HARDWORKER JACK MUNKABA ALL ===" "Cyan"
Write-Log "Repo gyoker: $RepoRoot" "Gray"

# =============================================================================
# SEGÉDFÜGGVÉNYEK
# =============================================================================

function Get-FileVer {
    param([string]$FilePath)
    try {
        $v = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath).FileVersion
        return $v.Trim().Replace(" ","")
    } catch { return "0.0.0.0" }
}

function Get-VersionedName {
    param([string]$FileName, [string]$Version, [string]$Arch)
    $Base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Ext  = [System.IO.Path]::GetExtension($FileName)
    return "${Base}_v${Version}_${Arch}${Ext}"
}

# Masol egyet a RepoWork-bol a TempWork-be (ha meg nincs ott)
function Copy-ToTemp {
    param([string]$SourcePath)
    $Dest = Join-Path $TempWorkPath (Split-Path $SourcePath -Leaf)
    if (!(Test-Path $Dest)) {
        Copy-Item $SourcePath $Dest -Force
        Write-Log "  [MASOLAS] $($Dest | Split-Path -Leaf) → TempWork" "Gray"
    }
    return $Dest
}

# Kinyeri az adott fajlnevet egy CAB-bol a TempWork-be
# Ha a nev nem pontos, az osszes fajlt listazza, es ment mindent ami illik
function Expand-FromCab {
    param([string]$CabPath, [string]$TargetFileName, [string]$DestDir)

    $Extracted = @()

    # Elso probalkozes: pontos nevvel
    $ExactDest = Join-Path $DestDir $TargetFileName
    $Result = & expand.exe -F:$TargetFileName $CabPath $DestDir 2>&1
    if (Test-Path $ExactDest) {
        $Extracted += $ExactDest
        Write-Log "  [CAB] Kinyerve (pontos nev): $TargetFileName" "Green"
        return $Extracted
    }

    # Masodik probalkozes: az osszes fajl kinyerese, majd keresunk
    Write-Log "  [CAB] Pontos nev nem talalhato, osszes fajl kinyerese..." "Yellow"
    & expand.exe -F:* $CabPath $DestDir 2>&1 | Out-Null

    $Base = [System.IO.Path]::GetFileNameWithoutExtension($TargetFileName)
    $Ext  = [System.IO.Path]::GetExtension($TargetFileName).TrimStart(".")

    $Found = Get-ChildItem $DestDir -File | Where-Object {
        $_.Name -like "*${Base}*" -and $_.Extension -like "*.${Ext}"
    }
    foreach ($F in $Found) {
        $Extracted += $F.FullName
        Write-Log "  [CAB] Megtalalt: $($F.Name)" "Green"
    }

    if ($Extracted.Count -eq 0) {
        Write-Log "  [CAB] A keresett fajl ($TargetFileName) nem talalhato a CAB-ban!" "Red"
        Write-Log "  [CAB] Tartalom: $(( Get-ChildItem $DestDir | Select-Object -ExpandProperty Name ) -join ', ')" "Gray"
    }

    return $Extracted
}

# MSU kicsomagolasa: MSU → CAB → celfajl
function Expand-FromMsu {
    param([string]$MsuPath, [string]$TargetFileName, [string]$Arch)

    $WorkSubDir = Join-Path $TempWorkPath "expand_$(Get-Random)"
    New-Item -ItemType Directory -Path $WorkSubDir -Force | Out-Null

    Write-Log "  [MSU] Kicsomagolas: $(Split-Path $MsuPath -Leaf)" "Cyan"
    & expand.exe -F:* $MsuPath $WorkSubDir 2>&1 | Out-Null

    # CAB-ok keresese (legnagrobbat valasszuk, az a hasznos)
    $Cabs = Get-ChildItem $WorkSubDir -Filter "*.cab" | Sort-Object Length -Descending
    if ($Cabs.Count -eq 0) {
        Write-Log "  [MSU] Nem talalhato CAB a kicsomagolt MSU-ban!" "Red"
        Remove-Item $WorkSubDir -Recurse -Force -ErrorAction SilentlyContinue
        return @()
    }

    $AllExtracted = @()
    foreach ($Cab in $Cabs) {
        Write-Log "  [MSU] CAB feldolgozas: $($Cab.Name)" "Gray"
        $CabSubDir = Join-Path $WorkSubDir "cab_$($Cab.BaseName)"
        New-Item -ItemType Directory -Path $CabSubDir -Force | Out-Null
        $Extracted = Expand-FromCab -CabPath $Cab.FullName -TargetFileName $TargetFileName -DestDir $CabSubDir
        $AllExtracted += $Extracted
    }

    Remove-Item $WorkSubDir -Recurse -Force -ErrorAction SilentlyContinue
    return $AllExtracted
}

# Kicsomagolt fajlt verziozan es menti az /Apps-ba (ha jobb mint ami ott van)
function Save-ToApps {
    param([string]$FilePath, [string]$OriginalFileName, [string]$Arch, [string]$MinVersion)

    $Ver = Get-FileVer -FilePath $FilePath
    if ($Ver -eq "0.0.0.0") {
        Write-Log "  [APPS] Nem sikerult verzioszamot lekerdezni: $FilePath" "Yellow"
        $Ver = "unknown"
    }

    $VersionedName = Get-VersionedName -FileName $OriginalFileName -Version $Ver -Arch $Arch
    $Dest = Join-Path $AppsPath $VersionedName

    # Ne irjuk felul, ha mar pontosan ez a verzio ott van
    if (Test-Path $Dest) {
        Write-Log "  [APPS] Mar letezik: $VersionedName - kihagyva." "Gray"
        return $true
    }

    Copy-Item $FilePath $Dest -Force
    if (Test-Path $Dest) {
        Write-Log "  [APPS] Mentve: $VersionedName" "Green"
        return $true
    } else {
        Write-Log "  [APPS] Mentés sikertelen: $VersionedName" "Red"
        return $false
    }
}

# =============================================================================
# KERESÉS MINDEN HELYSZÍNEN - nyers csomagok (.msu, .cab, .exe)
# =============================================================================
function Find-RawPackages {
    param([string]$FileName, [string]$Arch)

    $Results = @()
    $SearchPaths = @($RepoWorkPath, $TempWorkPath)

    foreach ($Dir in $SearchPaths) {
        # Mindenféle csomagot keresünk, névtől függetlenül
        $All = Get-ChildItem $Dir -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Extension -in @(".msu", ".cab", ".exe", ".zip") }
        foreach ($F in $All) {
            $Results += [PSCustomObject]@{ Path = $F.FullName; Dir = $Dir; Name = $F.Name; Ext = $F.Extension }
        }
    }

    Write-Log "  [KERESES] Talalt nyers csomagok ($($Results.Count) db): $(($Results | Select-Object -ExpandProperty Name) -join ', ')" "Gray"
    return $Results
}

# =============================================================================
# CD / DVD / PENDRIVE DETEKTÁLÁS (Windows telepítőre)
# =============================================================================
function Find-WindowsInstallMedia {
    $Drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -in @(3, 5) }
    $Found = @()
    foreach ($D in $Drives) {
        $Letter = $D.DeviceID
        $WimPath = Join-Path $Letter "sources\install.wim"
        $EsdPath = Join-Path $Letter "sources\install.esd"
        if (Test-Path $WimPath) { $Found += [PSCustomObject]@{ Drive = $Letter; WimPath = $WimPath } }
        elseif (Test-Path $EsdPath) { $Found += [PSCustomObject]@{ Drive = $Letter; WimPath = $EsdPath } }
    }
    return $Found
}

# =============================================================================
# ISO BÁNYÁSZAT (manuális választás vagy automata észlelés)
# =============================================================================
function Invoke-IsoBanyaszat {
    param([string[]]$TargetFileNames)

    Write-Log "" "White"
    Write-Log "[ISO] ISO banyaszat indul..." "Cyan"

    # 1. CD/DVD/Pendrive detektálás
    $Media = Find-WindowsInstallMedia
    $WimPath = $null
    $MountedIso = $null

    if ($Media.Count -gt 0) {
        Write-Log "[ISO] Telepito media eszlelve:" "Green"
        for ($i = 0; $i -lt $Media.Count; $i++) {
            Write-Log "  [$($i+1)] $($Media[$i].Drive) - $($Media[$i].WimPath)" "Green"
        }
        $Sel = Read-Host "Valassz meghajto-szamot, vagy [M] manualisan valaszts ISO-t"
        if ($Sel -match '^\d+$' -and [int]$Sel -le $Media.Count) {
            $WimPath = $Media[[int]$Sel - 1].WimPath
        }
    }

    # 2. Manualis ISO valasztas ha nem volt media / felhasznalo azt kerte
    if (!$WimPath) {
        Write-Log "[ISO] Kerem valasszon ISO fajlt..." "Yellow"
        Add-Type -AssemblyName System.Windows.Forms
        $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
        $FileBrowser.Filter = "ISO / WIM fajlok (*.iso;*.wim;*.esd)|*.iso;*.wim;*.esd"
        $FileBrowser.Title  = "Windows telepito ISO valasztasa"

        if ($FileBrowser.ShowDialog() -ne "OK") {
            Write-Log "[ISO] ISO valasztas megszakitva." "Yellow"
            return
        }

        $ISOFile = $FileBrowser.FileName
        if ($ISOFile -like "*.iso") {
            Write-Log "[ISO] Felcsatolas: $ISOFile" "Gray"
            $Mount   = Mount-DiskImage -ImagePath $ISOFile -PassThru
            $Drive   = ($Mount | Get-Volume).DriveLetter + ":"
            $WimPath = Join-Path $Drive "sources\install.wim"
            if (!(Test-Path $WimPath)) { $WimPath = Join-Path $Drive "sources\install.esd" }
            $MountedIso = $ISOFile
        } else {
            $WimPath = $ISOFile   # Kozvetlenul WIM/ESD lett kivalasztva
        }
    }

    if (!(Test-Path $WimPath)) {
        Write-Log "[ISO] WIM/ESD nem talalhato: $WimPath" "Red"
        if ($MountedIso) { Dismount-DiskImage -ImagePath $MountedIso -ErrorAction SilentlyContinue }
        return
    }

    # 3. DISM mount
    $MountDir = Join-Path $TempWorkPath "dism_mount"
    if (!(Test-Path $MountDir)) { New-Item -ItemType Directory -Path $MountDir -Force | Out-Null }

    Write-Log "[ISO] DISM mount: $WimPath → $MountDir" "Gray"
    & dism.exe /mount-image /imagefile:$WimPath /index:1 /mountdir:$MountDir /readonly 2>&1 | Out-Null

    # 4. Fajlok kinyerese
    $AnyFound = $false
    foreach ($TargetFn in $TargetFileNames) {
        # Keresunk a tipikus helyeken a mounton belul
        $SearchRoots = @(
            (Join-Path $MountDir "Windows\System32"),
            (Join-Path $MountDir "Windows\SysWOW64")
        )
        foreach ($SRoot in $SearchRoots) {
            $SrcFile = Join-Path $SRoot $TargetFn
            if (Test-Path $SrcFile) {
                $Ver  = Get-FileVer -FilePath $SrcFile
                # Architektura SysWOW64 = x86, System32 = x64 (64bit rendszeren)
                $Arch = if ($SRoot -like "*SysWOW64*") { "x86" } else { "x64" }
                $VName = Get-VersionedName -FileName $TargetFn -Version $Ver -Arch $Arch
                $Dest  = Join-Path $AppsPath $VName
                if (!(Test-Path $Dest)) {
                    Copy-Item $SrcFile $Dest -Force
                    Write-Log "[ISO] Kimentve: $VName" "Green"
                    $AnyFound = $true
                } else {
                    Write-Log "[ISO] Mar letezik: $VName" "Gray"
                }
            }
        }
    }
    if (!$AnyFound) { Write-Log "[ISO] Egyik keresett fajl sem volt a WIM-ben." "Yellow" }

    # 5. DISM unmount
    & dism.exe /unmount-image /mountdir:$MountDir /discard 2>&1 | Out-Null
    Remove-Item $MountDir -Recurse -Force -ErrorAction SilentlyContinue

    if ($MountedIso) { Dismount-DiskImage -ImagePath $MountedIso -ErrorAction SilentlyContinue }
    Write-Log "[ISO] Banyaszat befejezve." "Cyan"
}

# =============================================================================
# FŐ FELDOLGOZÓ LOGIKA - egy Target (FileName+Arch) feldolgozása
# =============================================================================
function Invoke-ProcessTarget {
    param(
        [string]$FileName,
        [string]$Arch,
        [string]$MinVersion,
        [string]$UpdateURL
    )

    Write-Log "" "White"
    Write-Log "--- [ $FileName | $Arch | min. v$MinVersion ] ---" "White"

    # 1. Van-e mar jo verzio az /Apps-ban?
    $Base    = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Ext     = [System.IO.Path]::GetExtension($FileName).TrimStart(".")
    $Pattern = "${Base}_v*_${Arch}.${Ext}"
    $Existing = Get-ChildItem $AppsPath -Filter $Pattern -ErrorAction SilentlyContinue |
                Sort-Object { [version](($_.BaseName -split '_v')[1] -split '_')[0] } -Descending |
                Select-Object -First 1

    if ($Existing) {
        $ExVer = Get-FileVer -FilePath $Existing.FullName
        try {
            if ([version]$ExVer -ge [version]$MinVersion) {
                Write-Log "  [OK] /Apps-ban megfelelo verzio megvan: $($Existing.Name) (v$ExVer)" "Green"
                return $true
            } else {
                Write-Log "  [INFO] /Apps-ban regi verzio van (v$ExVer < v$MinVersion), frissites szukseges." "Yellow"
            }
        } catch {
            Write-Log "  [INFO] Verzio osszehasonlitas sikertelen, folytatjuk." "Yellow"
        }
    } else {
        Write-Log "  [INFO] /Apps-ban nincs $FileName ($Arch)" "Yellow"
    }

    # 2. Nyers csomagok keresese minden helyszinen
    $RawPackages = Find-RawPackages -FileName $FileName -Arch $Arch
    $ProcessedOK = $false

    # 3. Meglevő csomagok feldolgozása (ha Repo-ban van, masoljuk Temp-be)
    foreach ($Pkg in $RawPackages) {
        # Ha Repo-ban van, masoljuk Temp-be is
        if ($Pkg.Dir -eq $RepoWorkPath) {
            $Pkg.Path = Copy-ToTemp -SourcePath $Pkg.Path
        }

        Write-Log "  [CSOMAG] Feldolgozas: $($Pkg.Name)" "Cyan"

        $Extracted = @()
        switch ($Pkg.Ext) {
            ".msu" { $Extracted = Expand-FromMsu -MsuPath $Pkg.Path -TargetFileName $FileName -Arch $Arch }
            ".cab" {
                $SubDir = Join-Path $TempWorkPath "cab_$(Get-Random)"
                New-Item -ItemType Directory -Path $SubDir -Force | Out-Null
                $Extracted = Expand-FromCab -CabPath $Pkg.Path -TargetFileName $FileName -DestDir $SubDir
            }
            ".exe" {
                # Verziozott exe koznetlen mentes
                $Extracted = @($Pkg.Path)
            }
        }

        foreach ($ExFile in $Extracted) {
            if (Test-Path $ExFile) {
                $OK = Save-ToApps -FilePath $ExFile -OriginalFileName $FileName -Arch $Arch -MinVersion $MinVersion
                if ($OK) { $ProcessedOK = $true }
            }
        }
        if ($ProcessedOK) { break }
    }

    if ($ProcessedOK) { return $true }

    # 4. Nincs feldolgozható csomag → letöltés
    Write-Log "  [LETOLTES] Megkiserlom a letoltest: $UpdateURL" "Cyan"

    if ($UpdateURL -like "https://windowsupdate.com*" -or $UpdateURL -eq "") {
        Write-Log "  [LETOLTES] Generikus URL, automatikus letoltes nem lehetseges." "Yellow"
        Write-Log "  Kerem manualisan toltse le a fajlt ($FileName $Arch) a munkamappaba:" "Yellow"
        Write-Log "    $TempWorkPath" "Yellow"
        Start-Process explorer.exe $TempWorkPath
        $Continue = Read-Host "  Ha a fajl ott van, nyomj Entert az ujrafeldolgozashoz [Enter=ujra / S=kihagyas]"
        if ($Continue -ne "S") {
            return Invoke-ProcessTarget -FileName $FileName -Arch $Arch -MinVersion $MinVersion -UpdateURL $UpdateURL
        }
        return $false
    }

    $DownloadFile = Join-Path $TempWorkPath (Split-Path $UpdateURL -Leaf)
    try {
        Write-Log "  [LETOLTES] Folyamatban..." "Gray"
        Invoke-WebRequest -Uri $UpdateURL -OutFile $DownloadFile -ErrorAction Stop
        Write-Log "  [LETOLTES] Kész: $DownloadFile" "Green"

        # Ujrafeldolgozas az iment letoltott fajllal
        return Invoke-ProcessTarget -FileName $FileName -Arch $Arch -MinVersion $MinVersion -UpdateURL $UpdateURL

    } catch {
        Write-Log "  [LETOLTES] Sikertelen ($($_.Exception.Message))" "Red"
        Write-Log "  Bongeszo megnyitasa: $UpdateURL" "Yellow"
        Start-Process $UpdateURL
        Write-Log "  Kerem mentse a letoltott fajlt ide: $TempWorkPath" "Yellow"
        Start-Process explorer.exe $TempWorkPath
        $Continue = Read-Host "  Ha a fajl ott van, nyomj Entert [Enter=ujra / S=kihagyas]"
        if ($Continue -ne "S") {
            return Invoke-ProcessTarget -FileName $FileName -Arch $Arch -MinVersion $MinVersion -UpdateURL $UpdateURL
        }
        return $false
    }
}

# =============================================================================
# FŐPROGRAM
# =============================================================================

# Egyedi FileName+Arch kombinaciok osszeszedese a JSON-bol
$UniqueTargets = $Config.TargetFiles |
    Group-Object { "$($_.FileName)|$($_.Architecture)" } |
    ForEach-Object {
        # A legjobb (legmagasabb MinVersion) URL-t hasznaljuk
        $Best = $_.Group | Sort-Object { [version]$_.MinVersion } -Descending | Select-Object -First 1
        [PSCustomObject]@{
            FileName   = $Best.FileName
            Arch       = $Best.Architecture
            MinVersion = $Best.MinVersion
            UpdateURL  = $Best.UpdateURL
        }
    }

$Results = @{}
foreach ($T in $UniqueTargets) {
    $Key = "$($T.FileName)|$($T.Arch)"
    $Results[$Key] = Invoke-ProcessTarget -FileName $T.FileName -Arch $T.Arch -MinVersion $T.MinVersion -UpdateURL $T.UpdateURL
}

# Osszesito
Write-Log "" "White"
Write-Log "=== EREDMENY ===" "Cyan"
$OK  = ($Results.Values | Where-Object { $_ -eq $true }).Count
$NOK = ($Results.Values | Where-Object { $_ -ne $true }).Count
Write-Log "  Sikeres: $OK / $($Results.Count)" "Green"
if ($NOK -gt 0) { Write-Log "  Hianyos: $NOK / $($Results.Count)" "Red" }

# ISO felajanlasa ha hianyoznak fajlok
if ($NOK -gt 0) {
    Write-Log "" "White"
    Write-Log "[?] $NOK fajl meg hianyzik. Szeretne ISO-bol kinyerni?" "Yellow"
    $IsoChoice = Read-Host "[I]gen / [N]em"
    if ($IsoChoice -eq "I" -or $IsoChoice -eq "i") {
        $MissingFiles = $UniqueTargets |
            Where-Object { $Results["$($_.FileName)|$($_.Arch)"] -ne $true } |
            Select-Object -ExpandProperty FileName -Unique
        Invoke-IsoBanyaszat -TargetFileNames $MissingFiles
    }
}

# Temp mappa - felhasznalo donthet
Write-Log "" "White"
Write-Log "[?] Szeretne megnyitni a munkamappat ellenorzesre?" "Cyan"
$OpenChoice = Read-Host "[I]gen / [N]em"
if ($OpenChoice -eq "I" -or $OpenChoice -eq "i") {
    Start-Process explorer.exe $TempWorkPath
}

Write-Log "" "White"
Write-Log "[?] Torolje a TempWork tartalmat (csak a feldolgozott csomagokat)?" "Yellow"
Write-Log "  (Az /Apps-ba mar mentett fajlok biztonsagban vannak!)" "Gray"
$CleanChoice = Read-Host "[I]gen / [N]em"
if ($CleanChoice -eq "I" -or $CleanChoice -eq "i") {
    Get-ChildItem $TempWorkPath -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".msu", ".cab", ".zip") } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Log "[TAKARITAS] Ideiglenes csomagfajlok torolve." "Gray"
}

Write-Log "=== HARDWORKER JACK VEGZETT ===" "Cyan"
