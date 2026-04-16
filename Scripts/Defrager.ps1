param ([int]$Cycle = 1)

$LogPath = "..\LOG\Defrag_Engine_Log.txt"
$RecoveryPath = "..\LOG\Recovery"

function Write-Log($msg) {
    $txt = "[Ciklus $Cycle] $(Get-Date -Format 'HH:mm:ss') - $msg"
    Write-Host $txt -ForegroundColor Cyan
    Add-Content -Path $LogPath -Value $txt
}

# --- BIZTONSÁGI MODUL ---
Write-Log "Fizikai allapot ellenorzese (S.M.A.R.T.)..."
$diskHealth = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue
if ($diskHealth -and $diskHealth.PredictFailure) {
    Write-Log "[KRITIKUS] A MEREVLEMEZ MEGHIBASODAST JELZETT! LEALLAS."
    Remove-Item "..\LOG\cycle.tmp" -Force
    exit
}

Write-Log "Kritikus fajlok mentese (Registry & Hosts)..."
if (!(Test-Path $RecoveryPath)) { New-Item -ItemType Directory -Path $RecoveryPath }
# Registry mentés (System hive)
reg export HKLM\SYSTEM "$RecoveryPath\System_Registry_Backup.reg" /y | Out-Null
Copy-Item "C:\Windows\System32\drivers\etc\hosts" "$RecoveryPath\hosts.bak" -Force

# --- DEFRAG MOTOR ---
Write-Log "Defragsvc inditasa..."
Start-Service defragsvc -ErrorAction SilentlyContinue

$drive = "C:"
Write-Log "Toredezettsegmentesites inditasa a(z) $drive meghajton..."

# W7/W10 kompatibilis hívás
$process = Start-Process -FilePath "defrag.exe" -ArgumentList "$drive /U /V /H" -Wait -NoNewWindow -PassThru
if ($process.ExitCode -eq 0) {
    Write-Log "A(z) $drive optimalizalasa sikeres."
} else {
    Write-Log "[HIBA] Defrag hibakod: $($process.ExitCode)"
}

Write-Log "Ciklus vege."
