# Reszlet a telepito logikabol
$WinScriptPath = "C:\Windows\Scripts\Defrager"
if (!(Test-Path $WinScriptPath)) {
    New-Item -ItemType Directory -Path $WinScriptPath -Force
    Write-Log "[SIKER] Rendszer mappa letrehozva: $WinScriptPath"
}
# Ide masoljuk majd a szukseges scripteket a veglegesiteskor
