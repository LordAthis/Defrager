# Reszlet a telepito logikabol
$WinScriptPath = "C:\Windows\Scripts\Defrager"
if (!(Test-Path $WinScriptPath)) {
    New-Item -ItemType Directory -Path $WinScriptPath -Force
    Write-Log "[SIKER] Rendszer mappa letrehozva: $WinScriptPath"
}
# Ide masoljuk majd a szukseges scripteket a veglegesiteskor

# Feladat letrehozasa a Windows-ban
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$PSScriptRoot\Launcher.ps1`""
$Trigger = New-ScheduledTaskTrigger -Monthly -DaysOfWeek Sunday -WeeksOfMonth First -At 3am
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "Defrager_AutoMaintenance" -Action $Action -Trigger $Trigger -Settings $Settings -Force
