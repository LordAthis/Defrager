# Launcher.ps1
# (Admin check es PowerConfig itt is szerepel, mint fent...)

$LogPath = Join-Path $PSScriptRoot "..\Logs\Launcher.log"
function Write-Log($msg, $color = "White") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $LogPath -Append
    Write-Host $msg -ForegroundColor $color
}

Write-Log "--- DEFRAGER LAUNCHER INDITASA ---" -color Cyan

# 1. Searching meghivasa
$SearchingScript = Join-Path $PSScriptRoot "Searching.ps1"
if (Test-Path $SearchingScript) {
    Write-Log "[FOLYAMAT] Rendszerfajlok keresese..."
    & $SearchingScript
}

# 2. Statusz check az Apps mappaban
$Files = Get-ChildItem (Join-Path $PSScriptRoot "..\Apps") -Filter "defrag_v*"
Write-Log "`n--- ELERHETO FAJLOK LISTAJA ---" -color Yellow

if ($Files.Count -eq 0) {
    Write-Log "[!] HIANY: Nincs hasznalhato fajl az /Apps mappaban!" Red
} else {
    foreach ($f in $Files) {
        # Zold szin a meglévőnek
        Write-Log "[OK] $($f.Name)" Green
    }
}

# Itt lehet majd a jövőben választani a Defrager.ps1 vagy Scandisker.ps1 közül
Write-Log "`n--- KESZ ---" -color Cyan
