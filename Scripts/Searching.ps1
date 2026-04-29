# Scripts_Searching.ps1
# Admin check, PowerConfig, Logolas (Repo + C:\Temp\LOG) ...

$AppsPath = Join-Path $PSScriptRoot "..\Apps"
$DataPath = Join-Path $PSScriptRoot "..\Data"
$Config = Get-Content (Join-Path $DataPath "Compatibility.json") | ConvertFrom-Json

Write-Host "--- FAJLOK ELLENORZESE ---" -ForegroundColor Cyan

foreach ($Target in $Config.TargetFiles) {
    # Keresesi minta az Apps mappaban: defrag_v*_x64.exe
    $Pattern = "$($Target.FileName.Split('.')[0])_v*_$($Target.Architecture).$($Target.FileName.Split('.')[1])"
    $ExistingFile = Get-ChildItem $AppsPath -Filter $Pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($ExistingFile) {
        $CurrentVer = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExistingFile.FullName).FileVersion
        $CurrentMD5 = (Get-FileHash $ExistingFile.FullName -Algorithm MD5).Hash

        if ([version]$CurrentVer -lt [version]$Target.MinVersion) {
            Write-Host "[!] $Pattern - ELAVULT (Verzió: $CurrentVer)" -ForegroundColor Red
        } elseif ($Target.MD5 -ne "FeltoltesUtanFrissitendo" -and $CurrentMD5 -ne $Target.MD5) {
            Write-Host "[!] $Pattern - HASH HIBA!" -ForegroundColor Red
        } else {
            Write-Host "[OK] $Pattern - MEGFELELO ($CurrentVer)" -ForegroundColor Green
        }
    } else {
        Write-Host "[HIANY] $($Target.FileName) nem talalhato az Apps mappaban!" -ForegroundColor Yellow
    }
}
