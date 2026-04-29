# Defrag_Launcher.ps1
$AppsPath = Join-Path $PSScriptRoot "..\Apps"

# Futtassuk a keresést/begyűjtést
. (Join-Path $PSScriptRoot "Searching.ps1")

Write-Host "`n--- Állapotjelentés ---" -ForegroundColor Yellow

# Ellenőrizzük az Apps mappát a lista alapján
$AvailableFiles = Get-ChildItem $AppsPath -Filter "defrag_v*"

if ($AvailableFiles.Count -eq 0) {
    Write-Host "[!] HIÁNYZIK: Nincs használható fájl az /Apps mappában!" -ForegroundColor Red
    Write-Host "[?] Tipp: Futasd a HardWorkerJack-et a beszerzéshez." -ForegroundColor Cyan
} else {
    foreach ($file in $AvailableFiles) {
        Write-Host "[MEGLÉVŐ] $($file.Name)" -ForegroundColor Green
    }
    
    # Itt jönne a döntési logika: melyik a legfrissebb?
    $BestVersion = $AvailableFiles | Sort-Object Name -Descending | Select-Object -First 1
    Write-Host "`nLegjobb elérhető opció: $($BestVersion.Name)" -ForegroundColor Magenta
}

# Itt folytatódna a tényleges töredezettségmentesítő hívása...
