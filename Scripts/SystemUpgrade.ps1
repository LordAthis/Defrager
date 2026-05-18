# SystemUpgrade.ps1 (.NET alapú, univerzális verzió)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[HIBA] A frissiteshez RENDSZERGAZDAI JOGOK szuksegesek!" -ForegroundColor Red
    Exit
}

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = if ($PSScriptRoot -like "*Scripts") { Split-Path -Parent $PSScriptRoot } else { $PSScriptRoot }

$AppsPath = Join-Path $RepoRoot "Apps"
$TargetSystemExe = "C:\Windows\System32\defrag.exe"

$NewExe = Get-ChildItem $AppsPath -Filter "defrag_v*_x64.exe" -ErrorAction SilentlyContinue | 
          Sort-Object LastWriteTime -Descending | 
          Select-Object -First 1

if (!$NewExe) {
    Write-Host "[HIBA] Nem talalhato frissites az Apps mappaban!" -ForegroundColor Red
    Exit
}

Write-Host "--- RENDSZER DEFRAG FRISSITESE (.NET) ---" -ForegroundColor Cyan

if (Test-Path $TargetSystemExe) {
    try {
        # 1. Tulajdonjog átvétele .NET-tel (Rendszergazdák csoport mint új tulajdonos)
        $TargetFile = Get-Item $TargetSystemExe
        $Acl = $TargetFile.GetAccessControl()
        $AdminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $Acl.SetOwner($AdminSid)
        $TargetFile.SetAccessControl($Acl)

        # 2. Teljes hozzáférés biztosítása a Rendszergazdák számára a másoláshoz
        $Acl = $TargetFile.GetAccessControl()
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdminSid, "FullControl", "Allow")
        $Acl.ResetAccessRule($AccessRule)
        $TargetFile.SetAccessControl($Acl)

        # 3. Biztonsági mentés (.bak), ha még nincs
        $BackupExe = "$TargetSystemExe.bak"
        if (!(Test-Path $BackupExe)) {
            [System.IO.File]::Copy($TargetSystemExe, $BackupExe, $true)
            Write-Host "[OK] Biztonsagimentes keszult (.bak)" -ForegroundColor Green
        }

        # 4. Új fájl bemásolása .NET I/O segítségével
        [System.IO.File]::Copy($NewExe.FullName, $TargetSystemExe, $true)
        Write-Host "[SIKER] A rendszer defrag sikeresen frissitve lett!" -ForegroundColor Green

    } catch {
        Write-Host "[HIBA] .NET hiba lepett fel: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[HIBA] A gyari defrag.exe nem talalhato!" -ForegroundColor Red
}
