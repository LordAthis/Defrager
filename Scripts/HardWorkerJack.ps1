# HardWorkerJack.ps1
# (Admin check, PowerConfig, Laptop figyelmeztetes ide is jon...)

$RepoLog = Join-Path $PSScriptRoot "..\Logs\HardWorkerJack.log"
$TempLog = "C:\Temp\LOG\HardWorkerJack.log"
$AppsPath = Join-Path $PSScriptRoot "..\Apps"
$DataPath = Join-Path $PSScriptRoot "..\Data"
$WorkingDir = "C:\Temp\Defrager_Work"

if (!(Test-Path "C:\Temp\LOG")) { New-Item -ItemType Directory -Path "C:\Temp\LOG" | Out-Null }
if (!(Test-Path $WorkingDir)) { New-Item -ItemType Directory -Path $WorkingDir | Out-Null }

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $msg"
    $line | Out-File -FilePath $RepoLog -Append
    $line | Out-File -FilePath $TempLog -Append
    Write-Host $msg
}

Write-Log "--- HARDWORKER JACK MUNKABA ALL ---"

# Adatok betoltese
$Config = Get-Content (Join-Path $DataPath "Compatibility.json") | ConvertFrom-Json

# PELDA: Letoltesi logika (W10 kumulativ frissitesbol kinyeres)
# Megjegyzes: A pontos URL-eket a Compatibility.json-bol vesszuk
foreach ($Target in $Config.TargetFiles) {
    $DestFile = Join-Path $AppsPath $Target.FileName
    
    if (!(Test-Path $DestFile)) {
        Write-Log "[FOLYAMAT] Letoltes inditasa: $($Target.FileName)..."
        
        # Itt a tényleges letöltés és kicsomagolás helye
        # Expand-WindowsImage vagy expand.exe használatával a CAB fájlokból
        
        Write-Log "[INFO] Ez a resz a letoltesi URL-ek tisztazasa utan lesz veglegesitve."
    }
}

# Tisztitas a vegen
# Remove-Item $WorkingDir -Recurse -Force
Write-Log "--- HARDWORKER JACK VEGZETT ---"
