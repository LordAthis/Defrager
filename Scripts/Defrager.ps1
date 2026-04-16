param ([int]$Cycle = 1)

$LogPath = "..\LOG\Defrag_Engine_Log.txt"
function Write-RTSLog($msg) {
    $txt = "[Ciklus $Cycle] $(Get-Date) - $msg"
    Add-Content -Path $LogPath -Value $txt
    Write-Host $txt -ForegroundColor Yellow
}

Write-RTSLog "Motor indítása..."

# Service Fix (W7 specifikus)
Get-Service defragsvc | Set-Service -StartupType Manual
Start-Service defragsvc -ErrorAction SilentlyContinue

# Defrag futtatása
$drive = "C:"
Write-RTSLog "Töredezettségmentesítés futtatása a(z) $drive meghajtón..."
& defrag.exe $drive /U /V /H | Out-File -FilePath $LogPath -Append

Write-RTSLog "Ciklus kész."
