# Searching.ps1
# Jogosultsag es kornyezet beallitasa
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Alvasgatlo aktivalasa
powercfg -requestsoverride driver "System" display system
powercfg /x -standby-timeout-ac 0

# Laptop figyelemztetes
if ((Get-WmiObject -Class Win32_Battery) -ne $null) {
    Write-Host "FIGYELEM: Laptop uzemmod! Csatlakoztassa a toltot a folyamat megkezdese elott!" -ForegroundColor Yellow
}

# Utvonalak es Logolas
$LogPath = Join-Path $PSScriptRoot "..\Logs\Searching.log"
$AppsPath = Join-Path $PSScriptRoot "..\Apps"
if (!(Test-Path ".. \Logs")) { New-Item -ItemType Directory -Path "..\Logs" | Out-Null }

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $LogPath -Append
    Write-Host $msg
}

Write-Log "--- KERESES ES MENTES INDITASA ---"

$FilesToFind = @("defrag.exe", "defragres.dll")
$Systems = @("C:\Windows\System32", "C:\Windows\SysWOW64")

foreach ($SysDir in $Systems) {
    if (Test-Path $SysDir) {
        foreach ($FileName in $FilesToFind) {
            $Source = Join-Path $SysDir $FileName
            if (Test-Path $Source) {
                $Info = Get-Item $Source
                $Ver = $Info.VersionInfo.FileVersion.Replace(" ", "")
                $Arch = if ($SysDir -like "*WOW64*") { "x86" } else { "x64" }
                
                $TargetName = "$($FileName.Split('.')[0])_v$($Ver)_$($Arch).$($FileName.Split('.')[1])"
                $Dest = Join-Path $AppsPath $TargetName

                if (!(Test-Path $Dest)) {
                    Copy-Item $Source $Dest -Force
                    # Visszaellenorzes
                    if (Test-Path $Dest) {
                        Write-Log "[SIKER] Masolva: $TargetName"
                    } else {
                        Write-Log "[HIBA] Nem sikerult a masolas: $TargetName"
                    }
                } else {
                    Write-Log "[INFO] Mar letezik: $TargetName"
                }
            }
        }
    }
}
Write-Log "--- KERESES BEFEJEZVE ---"
