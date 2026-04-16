param (
    [string]$LogPath = "..\LOG\Defrag_PowerShell.txt",
    [string]$EnginePath = "defrag.exe"
)

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $finalMsg = "[$timestamp] $msg"
    Write-Host $finalMsg -ForegroundColor Green
    Add-Content -Path $LogPath -Value $finalMsg
}

Write-Log "RTS Defrager Engine elindult."

# Szerviz kényszerítés (W7 GUI hiba áthidalása)
Write-Log "Defragsvc szolgáltatás ellenőrzése..."
$svc = Get-Service -Name defragsvc -ErrorAction SilentlyContinue
if ($svc) {
    Set-Service -Name defragsvc -StartupType Manual
    Start-Service -Name defragsvc
}

# Meghajtók listázása
$volumes = Get-WmiObject Win32_Volume | Where-Object { $_.DriveLetter -ne $null -and $_.DriveType -eq 3 }

foreach ($vol in $volumes) {
    $drive = $vol.DriveLetter
    Write-Log "Elemzés: $drive ..."

    # SSD vs HDD (W10+ esetén optimalizált, W7 esetén defrag)
    if ($OS_VER -ge "10.0") {
        Write-Log "W10+ detektálva, Optimize-Volume indítása..."
        Optimize-Volume -DriveLetter $drive.Replace(":","") -ReTrim -Defrag -Verbose 2>&1 >> $LogPath
    } else {
        # Legacy / Windows 7 szakasz
        Write-Log "Hagyományos defrag indítása ($EnginePath) a(z) $drive meghajtón..."
        $process = Start-Process -FilePath $EnginePath -ArgumentList "$drive /U /V" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Log "[!] Hiba a defrag során. Hibakód: $($process.ExitCode)"
        }
    }
}

Write-Log "RTS Defrager Engine befejezte a munkát."
