# Searching.ps1 (Rövid, stabil verzió)
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = if ($PSScriptRoot -like "*Scripts") { Split-Path -Parent $PSScriptRoot } else { $PSScriptRoot }

$AppsPath = Join-Path $RepoRoot "Apps"
$DataPath = Join-Path $RepoRoot "data"
$JsonFile = Join-Path $DataPath "Compatibility.json"

if (!(Test-Path $JsonFile)) { Write-Host "[HIBA] Konfig hianyzik!" -ForegroundColor Red; return }
$Config = Get-Content $JsonFile | ConvertFrom-Json

Write-Host "--- FAJLOK ELLENORZESE ---" -ForegroundColor Cyan

foreach ($Target in $Config.TargetFiles) {
    $Pattern = "$($Target.FileName.Split('.')[0])_v*_$($Target.Architecture).$($Target.FileName.Split('.')[1])"
    $ExistingFile = Get-ChildItem $AppsPath -Filter $Pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($ExistingFile) {
        $CurrentVer = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExistingFile.FullName).FileVersion
        $CurrentMD5 = (Get-FileHash $ExistingFile.FullName -Algorithm MD5).Hash

        if ([version]$CurrentVer -lt [version]$Target.MinVersion) {
            Write-Host "[!] $Pattern - ELAVULT ($CurrentVer)" -ForegroundColor Red
        } elseif ($Target.MD5 -ne "FeltoltesUtanFrissitendo" -and $CurrentMD5 -ne $Target.MD5) {
            Write-Host "[!] $Pattern - HASH HIBA!" -ForegroundColor Red
        } else {
            Write-Host "[OK] $Pattern - MEGFELELO ($CurrentVer)" -ForegroundColor Green
        }
    } else {
        Write-Host "[HIANY] $($Target.FileName) ($($Target.Architecture)) hianyzik!" -ForegroundColor Yellow
    }
}
