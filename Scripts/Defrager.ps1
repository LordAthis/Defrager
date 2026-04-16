# RTS Framework - Defrag Module
# Verzió-optimalizált (Win7-től felfelé)

$DriveType = Get-Volume | Where-Object { $_.DriveLetter -ne $null }

foreach ($drive in $DriveType) {
    Write-Host "Processing Drive: $($drive.DriveLetter)" -ForegroundColor Cyan
    
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        # Win10/11 optimalizált hívás
        Optimize-Volume -DriveLetter $drive.DriveLetter -ReTrim -Defrag -Verbose
    } else {
        # Win7/8 fallback
        & defrag.exe "$($drive.DriveLetter):" /U /V
    }
}
