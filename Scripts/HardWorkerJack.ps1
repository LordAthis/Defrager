# HardWorkerJack.ps1
# Jogosultsag es kornyezet (Admin, PowerConfig, Logolas) beallitasa...

$WorkingDir = "C:\Temp\Defrager_Work"
$AppsPath = Join-Path $PSScriptRoot "..\Apps"
$DataPath = Join-Path $PSScriptRoot "..\Data"
$RepoLog = Join-Path $PSScriptRoot "..\Logs\HardWorkerJack.log"
$TempLog = "C:\Temp\LOG\HardWorkerJack.log"

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $msg"
    $line | Out-File -FilePath $RepoLog -Append
    $line | Out-File -FilePath $TempLog -Append
    Write-Host $msg
}

# --- A TERV: Letoltes az MS Update-rol ---
function Try-UpdateDownload {
    Write-Log "[FOLYAMAT] Probalom a frissitesi csomag letolteset..."
    $Config = Get-Content (Join-Path $DataPath "Compatibility.json") | ConvertFrom-Json
    
    foreach ($Source in $Config.UpdateSources) {
        $LocalMSU = Join-Path $WorkingDir "update.msu"
        try {
            Invoke-WebRequest -Uri $Source.URL -OutFile $LocalMSU -ErrorAction Stop
            Write-Log "[SIKER] Letoltes kesz, kicsomagolas..."
            
            # MSU -> CAB -> Fajlok kinyerese
            expand.exe -F:* $LocalMSU $WorkingDir | Out-Null
            $CabFile = Get-ChildItem $WorkingDir -Filter "*.cab" | Select-Object -First 1
            expand.exe -F:defrag.exe $CabFile.FullName $AppsPath | Out-Null
            
            if (Test-Path (Join-Path $AppsPath "defrag.exe")) {
                Write-Log "[KESZ] Fajlok beszerezve frissitesbol."
                return $true
            }
        } catch {
            Write-Log "[HIBA] Letoltes vagy kicsomagolas sikertelen: $($_.Exception.Message)"
        }
    }
    return $false
}

# --- B TERV: ISO Banyaszat ---
function Try-ISOMining {
    Write-Host "`n[!] A terv sikertelen. Kerlek, tallozz be egy Windows ISO-t!" -ForegroundColor Yellow
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Filter = "ISO Fajlok (*.iso)|*.iso"
    
    if ($FileBrowser.ShowDialog() -eq "OK") {
        $ISOPath = $FileBrowser.FileName
        Write-Log "[FOLYAMAT] ISO felcsatolasa: $ISOPath"
        $Drive = (Mount-DiskImage -ImagePath $ISOPath -PassThru | Get-Volume).DriveLetter
        
        $WimPath = "$($Drive):\sources\install.wim" # Vagy install.esd
        if (Test-Path $WimPath) {
            Write-Log "[FOLYAMAT] Fajl banyaszata a WIM kontenerbol..."
            # Itt a 7-Zip vagy Mount-WindowsImage parancs jon
            # Pelda: Expand-WindowsImage -ImagePath $WimPath -Index 1 -OutputPath $WorkingDir
            Write-Log "[INFO] ISO-bol valo kinyeres folyamatban..."
        }
        Dismount-DiskImage -ImagePath $ISOPath
    }
}

# Foprogram
if (!(Test-Path $WorkingDir)) { New-Item $WorkingDir -ItemType Directory }

if (-not (Try-UpdateDownload)) {
    Try-ISOMining
}

# Takaritas
if (Test-Path $WorkingDir) { Remove-Item $WorkingDir -Recurse -Force }
Write-Log "--- HARDWORKER JACK VEGZETT ---"
