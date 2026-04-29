# Searching.ps1
$AppsPath = Join-Path $PSScriptRoot "..\Apps"
$System32Path = "C:\Windows\System32"
$SysWOW64Path = "C:\Windows\SysWOW64" # 32-bit fájlok 64-bit rendszeren

# Célfájlok listája (Ezt később a Compatibility.json-ból is olvashatjuk)
$FilesToFind = @("defrag.exe", "defragres.dll")

Write-Host "--- Defrager Rendszerellenőrzés ---" -ForegroundColor Cyan

foreach ($FileName in $FilesToFind) {
    # 1. Ellenőrizzük a natív rendszerfájlt (x64-en x64, x86-on x86)
    $FilePath = Join-Path $System32Path $FileName
    if (Test-Path $FilePath) {
        $Info = Get-Item $FilePath
        $Ver = $Info.VersionInfo.FileVersion.Replace(" ", "")
        $Arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        
        $TargetName = "$($FileName.Split('.')[0])_v$($Ver)_$($Arch).$($FileName.Split('.')[1])"
        $DestPath = Join-Path $AppsPath $TargetName

        if (-not (Test-Path $DestPath)) {
            Write-Host "[+] Új verzió találva: $TargetName - Másolás..." -ForegroundColor Green
            Copy-Item $FilePath $DestPath
        } else {
            Write-Host "[OK] $TargetName már szerepel a könyvtárban." -ForegroundColor Gray
        }
    }

    # 2. Ha 64 bites rendszeren vagyunk, keressük meg a 32 bites változatot is (SysWOW64)
    if ([Environment]::Is64BitOperatingSystem -and (Test-Path $SysWOW64Path)) {
        $FilePath32 = Join-Path $SysWOW64Path $FileName
        if (Test-Path $FilePath32) {
            $Info32 = Get-Item $FilePath32
            $Ver32 = $Info32.VersionInfo.FileVersion.Replace(" ", "")
            
            $TargetName32 = "$($FileName.Split('.')[0])_v$($Ver32)_x86.$($FileName.Split('.')[1])"
            $DestPath32 = Join-Path $AppsPath $TargetName32

            if (-not (Test-Path $DestPath32)) {
                Write-Host "[+] 32-bites verzió találva: $TargetName32 - Másolás..." -ForegroundColor Green
                Copy-Item $FilePath32 $DestPath32
            }
        }
    }
}
