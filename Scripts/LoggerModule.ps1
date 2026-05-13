# =============================================================================
# LoggerModule.ps1 - RTS (Reparing's - Tuning's - Setting's) Központi Log Kezelő
# =============================================================================

# 1. Globális karakter-helyreállító tábla (Ötleted alapján: á->a, é->e, stb. + krix-krax szűrés)
function Convert-RtsTextClean {
    param([string]$RawText)
    if ([string]::IsNullOrEmpty($RawText)) { return "" }

    $Normalizer = @{
        'á'='a'; 'Á'='A'; 'é'='e'; 'É'='E'; 'í'='i'; 'Í'='I';
        'ó'='o'; 'Ó'='O'; 'ö'='o'; 'Ö'='O'; 'ő'='o'; 'Ő'='O';
        'ú'='u'; 'Ú'='U'; 'ü'='u'; 'Ü'='U'; 'ű'='u'; 'Ű'='U';
        ''='?'; 'â'='a'; 'ã'='a'; 'í'='i'; 'ó'='o'; 'ú'='u'
    }
    foreach ($Key in $Normalizer.Keys) {
        $RawText = $RawText.Replace($Key, $Normalizer[$Key])
    }
    # Minden nem-nyomtatható és sérült krix-krax eltávolítása (.NET regex)
    return $RawText -replace '[^\x09\x0A\x0D\x20-\x7E]', ''
}

# 2. Meglévő LOG fájlok automatikus Refaktorálása / Migrációja (Kompakt .NET motor)
function Repair-AndRefactorLogs {
    param([string]$LogFolder)
    if (-not (Test-Path $LogFolder)) { return }
    
    $LogFiles = Get-ChildItem -Path $LogFolder -Filter "*.log"
    foreach ($File in $LogFiles) {
        try {
            $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
            # Megpróbáljuk UTF-8-ként, ha hibás, Közép-Európai ANSI (1250) kódolással beolvasni
            $Content = [System.Text.Encoding]::UTF8.GetString($Bytes)
            if ($Content -match '' -or $Content -match '[^\x00-\x7F]') {
                $Content = [System.Text.Encoding]::GetEncoding(1250).GetString($Bytes)
            }
            
            # Átalakítás és tisztítás
            $CleanedContent = Convert-RtsTextClean -RawText $Content
            
            # .NET-tel kényszerítjük a tiszta UTF-8-ba való visszaírást (Felülírja a hibás régit)
            [System.IO.File]::WriteAllText($File.FullName, $CleanedContent, [System.Text.Encoding]::UTF8)
        } catch {
            # Ha a fájl zárolt (pl. fut egy folyamat), biztonságosan átugorjuk
        }
    }
}

# 3. Új bejegyzések hozzáírása .NET alapon (Tiszta, krix-krax mentes kimenet a jövőben)
function Write-RtsLog {
    param(
        [string]$FilePath,
        [string]$Message
    )
    $TimeStamp = (Get-Date -Format "yyyy.MM.dd-HH:mm:ss")
    $CleanMessage = Convert-RtsTextClean -RawText $Message
    $FinalLine = "[$TimeStamp] $CleanMessage`r`n"
    
    # Biztosítjuk a mappa meglétét
    $Dir = [System.IO.Path]::GetDirectoryName($FilePath)
    if (-not (Test-Path $Dir)) { [System.IO.Directory]::CreateDirectory($Dir) | Out-Null }
    
    # .NET szálbiztos hozzáfűzés UTF-8 kódolással
    [System.IO.File]::AppendAllText($FilePath, $FinalLine, [System.Text.Encoding]::UTF8)
}
