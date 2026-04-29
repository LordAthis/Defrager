# HardWorkerJack.ps1 - Beszerzo motor
# Jogosultsag ellenorzes
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Dinamikus utvonalak meghatarozasa
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = if ($PSScriptRoot -like "*Scripts") { Split-Path -Parent $PSScriptRoot } else { $PSScriptRoot }

$AppsPath   = Join-Path $RepoRoot "Apps"
$DataPath   = Join-Path $RepoRoot "data"
$LogDir      = Join-Path $RepoRoot "Logs"
$WorkingDir = "C:\Temp\Defrager_Work"
$TempLogDir  = "C:\Temp\LOG"

# Mappak letrehozasa ha hianyoznak
foreach ($Path in @($WorkingDir, $TempLogDir, $AppsPath, $LogDir)) {
    if (!(Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

$RepoLog    = Join-Path $LogDir "HardWorkerJack.log"
$TempLog    = Join-Path $TempLogDir "HardWorkerJack.log"

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $msg"
    $line | Out-File -FilePath $RepoLog -Append
    $line | Out-File -FilePath $TempLog -Append
    Write-Host $msg
}

# Alvasgatlo es Laptop figyelemztetes
powercfg -requestsoverride driver "System" display system
powercfg /x -standby-timeout-ac 0
if ((Get-WmiObject -Class Win32_Battery) -ne $null) {
    Write-Log "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot!"
}

# Konfiguracio betoltese
$JsonFile = Join-Path $DataPath "Compatibility.json"
if (!(Test-Path $JsonFile)) { Write-Log "[HIBA] Konfig hianyzik: $JsonFile"; return }
$Config = Get-Content $JsonFile | ConvertFrom-Json

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
            Write-Log "[!] Automatikus letoltes sikertelen. Bongeszo megnyitasa..."
            Start-Process $Target.UpdateURL
            Read-Host "Ha letoltotted a fajlt a '$WorkingDir' mappaba '$(Split-Path $LocalMSU -Leaf)' neven, nyomj Entert!"
            if (Test-Path $LocalMSU) { $Success = $true }
        }

        if ($Success) {
            Write-Log "[SIKER] Csomag megvan, kinyeres folyamatban..."
            expand.exe -F:* $LocalMSU $WorkingDir | Out-Null
            $CabFile = Get-ChildItem $WorkingDir -Filter "*.cab" | Select-Object -First 1
            if ($CabFile) {
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
    Write-Host "`n[!] Update hianyzik. ISO banyaszat szukseges!" -ForegroundColor Yellow
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
            Write-Log "[FOLYAMAT] Fajlok kinyerese DISM-mel..."
            if (!(Test-Path "$WorkingDir\mount")) { New-Item -ItemType Directory -Path "$WorkingDir\mount" | Out-Null }
            dism.exe /mount-image /imagefile:$WimPath /index:1 /mountdir:"$WorkingDir\mount" /readonly
            
            foreach ($Target in $Config.TargetFiles) {
                $SourcePath = Join-Path "$WorkingDir\mount" ($Target.InternalWIMPath.Replace("_", "\"))
                if (Test-Path $SourcePath) {
                    $Ver = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($SourcePath).FileVersion.Replace(" ", "")
                    $FinalName = "$($Target.FileName.Split('.')[0])_v$($Ver)_$($Target.Architecture).$($Target.FileName.Split('.')[1])"
                    Copy-Item $SourcePath (Join-Path $AppsPath $FinalName) -Force
                    Write-Log "[SIKER] ISO-bol kimentve: $FinalName"
                }
            }
            dism.exe /unmount-image /mountdir:"$WorkingDir\mount" /discard
        }
        Dismount-DiskImage -ImagePath $ISOPath
    }
}

# Vegrehajtas
Get-FilesByUpdate

$CheckFiles = Get-ChildItem $AppsPath -Filter "defrag_v*"
if ($CheckFiles.Count -lt 2) { Get-FilesByISO }

# Tesztelesi megallitas
if (Test-Path $WorkingDir) {
    Write-Log "[TESZT] Munkamappa megnyitasa ellenorzeshez..."
    Start-Process explorer.exe $WorkingDir
    Read-Host "Ellenorizd a tartalmat, majd nyomj Entert a takaritashoz!"
}

# Takaritas
if (Test-Path $WorkingDir) { 
    dism.exe /unmount-image /mountdir:"$WorkingDir\mount" /discard 2>$null
    Remove-Item $WorkingDir -Recurse -Force -ErrorAction SilentlyContinue 
    Write-Log "[INFO] Munkamappa feltakaritva."
}

Write-Log "--- HARDWORKER JACK VEGZETT ---"
