# HardWorkerJack.ps1 - Beszerzo motor
# Adminisztratori jogok ellenorzese
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Alvasgatlo es Laptop figyelemztetes
powercfg -requestsoverride driver "System" display system
powercfg /x -standby-timeout-ac 0
if ((Get-WmiObject -Class Win32_Battery) -ne $null) {
    Write-Host "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot!" -ForegroundColor Yellow
}

# Utvonalak beallitasa
$WorkingDir = "C:\Temp\Defrager_Work"
$AppsPath   = Join-Path $PSScriptRoot "..\Apps"
$DataPath   = Join-Path $PSScriptRoot "..\Data"
$RepoLog    = Join-Path $PSScriptRoot "..\Logs\HardWorkerJack.log"
$TempLog    = "C:\Temp\LOG\HardWorkerJack.log"

# Mappak letrehozasa ha hianyoznak
foreach ($Path in @($WorkingDir, "C:\Temp\LOG", $AppsPath)) {
    if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $msg"
    $line | Out-File -FilePath $RepoLog -Append
    $line | Out-File -FilePath $TempLog -Append
    Write-Host $msg
}

# Konfiguracio betoltese
$Config = Get-Content (Join-Path $DataPath "Compatibility.json") | ConvertFrom-Json

Write-Log "--- HARDWORKER JACK MUNKABA ALL ---"

# --- FUNKCIO: Letoltes es kinyeres ---
function Get-FilesByUpdate {
    foreach ($Target in $Config.TargetFiles) {
        $LocalMSU = Join-Path $WorkingDir "update_$($Target.Architecture).msu"
        Write-Log "[FOLYAMAT] Probalom letolteni: $($Target.FileName) ($($Target.Architecture))"
        
        $Success = $false
        try {
            Invoke-WebRequest -Uri $Target.UpdateURL -OutFile $LocalMSU -ErrorAction Stop
            $Success = $true
        } catch {
            Write-Log "[!] Automatikus letoltes sikertelen: $($Target.UpdateURL)"
            Write-Log "[?] Bongeszo megnyitasa manualis letolteshez..."
            Start-Process $Target.UpdateURL
            Read-Host "Ha letoltotted a fajlt a '$WorkingDir' mappaba '$($LocalMSU)' neven, nyomj Entert!"
            if (Test-Path $LocalMSU) { $Success = $true }
        }

        if ($Success) {
            Write-Log "[SIKER] Csomag megvan, kinyeres folyamatban..."
            expand.exe -F:* $LocalMSU $WorkingDir | Out-Null
            $CabFile = Get-ChildItem $WorkingDir -Filter "*.cab" | Select-Object -First 1
            if ($CabFile) {
                # Kinyerjük a specifikus fájlt (defrag.exe vagy defragres.dll)
                expand.exe -F:$($Target.FileName) $CabFile.FullName $WorkingDir | Out-Null
                $ExtractedFile = Join-Path $WorkingDir $Target.FileName
                
                if (Test-Path $ExtractedFile) {
                    $Ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExtractedFile).FileVersion.Replace(" ", "")
                    $FinalName = "$($Target.FileName.Split('.')[0])_v$($Ver)_$($Target.Architecture).$($Target.FileName.Split('.')[1])"
                    Move-Item $ExtractedFile (Join-Path $AppsPath $FinalName) -Force
                    Write-Log "[KESZ] Elmentve: $FinalName"
                }
            }
        }
    }
}

# --- FUNKCIO: ISO Banyaszat (B terv) ---
function Get-FilesByISO {
    Write-Host "`n[!] Update-bol nem sikerult mindent beszerezni. ISO banyaszat szukseges!" -ForegroundColor Yellow
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Filter = "ISO Fajlok (*.iso)|*.iso"
    
    if ($FileBrowser.ShowDialog() -eq "OK") {
        $ISOPath = $FileBrowser.FileName
        Write-Log "[FOLYAMAT] ISO felcsatolasa: $ISOPath"
        $Mount = Mount-DiskImage -ImagePath $ISOPath -PassThru
        $Drive = ($Mount | Get-Volume).DriveLetter
        
        $WimPath = Join-Path "$($Drive):" "sources\install.wim"
        if (!(Test-Path $WimPath)) { $WimPath = Join-Path "$($Drive):" "sources\install.esd" }

        if (Test-Path $WimPath) {
            Write-Log "[FOLYAMAT] Fajlok kinyerese a WIM/ESD kontenerbol (Index: 1)..."
            # Itt a 7-Zip-et is hasznalhatnank, de a DISM a beepitett:
            dism.exe /mount-image /imagefile:$WimPath /index:1 /mountdir:$WorkingDir /readonly
            
            foreach ($Target in $Config.TargetFiles) {
                $SourcePath = Join-Path $WorkingDir ($Target.InternalWIMPath.Replace("_", "\"))
                if (Test-Path $SourcePath) {
                    $Ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($SourcePath).FileVersion.Replace(" ", "")
                    $FinalName = "$($Target.FileName.Split('.')[0])_v$($Ver)_$($Target.Architecture).$($Target.FileName.Split('.')[1])"
                    Copy-Item $SourcePath (Join-Path $AppsPath $FinalName) -Force
                    Write-Log "[SIKER] ISO-bol kimentve: $FinalName"
                }
            }
            dism.exe /unmount-image /mountdir:$WorkingDir /discard
        }
        Dismount-DiskImage -ImagePath $ISOPath
    }
}

# Vegrehajtas
Get-FilesByUpdate

# Ellenorzes: ha meg mindig hianyzik valami, jöhet az ISO
$CheckFiles = Get-ChildItem $AppsPath -Filter "defrag_v*"
if ($CheckFiles.Count -lt 2) {
    Get-FilesByISO
}


# Ellenorzes: Mappa megnyitasa takaritas elott (Teszteleshez)
if (Test-Path $WorkingDir) {
    Write-Log "[TESZT] Ideiglenes mappa megnyitasa ellenorzeshez..."
    Start-Process explorer.exe $WorkingDir
    Read-Host "Ellenorizd a mappat, majd nyomj Entert a takaritashoz és befejezéshez!"
}

# Takaritas
if (Test-Path $WorkingDir) { 
    # Biztonsagi unmount ha az ISO fázisban megszakadt volna
    dism.exe /unmount-image /mountdir:$WorkingDir /discard 2>$null
    
    # Itt töröljük a munkamappát
    Remove-Item $WorkingDir -Recurse -Force -ErrorAction SilentlyContinue 
    Write-Log "[INFO] Munkamappa feltakaritva."
}

Write-Log "--- HARDWORKER JACK VEGZETT ---"
