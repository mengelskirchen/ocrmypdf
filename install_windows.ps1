#Requires -Version 5.1
#Requires -RunAsAdministrator
# Native 64-Bit-Windows-Installation. Ghostscript-Setup ggf. bestaetigen.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Find-Tesseract {
    $cmd = Get-Command tesseract.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $standard = Join-Path $env:ProgramFiles "Tesseract-OCR\tesseract.exe"
    if (Test-Path $standard) { return $standard }
}

function Find-Ghostscript {
    $cmd = Get-Command gswin64c.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $root = Join-Path $env:ProgramFiles "gs"
    if (Test-Path $root) {
        $file = Get-ChildItem $root -Filter gswin64c.exe -File -Recurse |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($file) { return $file.FullName }
    }
}

function Add-SystemPath([string]$Directory) {
    $old = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $entries = @($old -split ";" | ForEach-Object { $_.TrimEnd("\") })
    if ($entries -notcontains $Directory.TrimEnd("\")) {
        [Environment]::SetEnvironmentVariable("Path", "$old;$Directory", "Machine")
    }
    $env:Path = "$Directory;$env:Path"
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw "Dieses Skript benoetigt 64-Bit-Windows."
}

$tesseract = Find-Tesseract
if (-not $tesseract) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget fehlt. Bitte den Microsoft 'App-Installer' installieren/aktualisieren."
    }
    & winget.exe install --id tesseract-ocr.tesseract --exact --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw "Tesseract-Installation fehlgeschlagen ($LASTEXITCODE)." }
    $tesseract = Find-Tesseract
    if (-not $tesseract) { throw "Tesseract wurde nicht im Standardordner gefunden. Bitte PATH pruefen." }
}

# Fehlende normale Sprachdaten installieren; vorhandene Modelle behalten.
$tessdata = Join-Path (Split-Path $tesseract) "tessdata"
New-Item -ItemType Directory -Force $tessdata | Out-Null
foreach ($sprache in @("deu", "osd")) {
    $ziel = Join-Path $tessdata "$sprache.traineddata"
    if (-not (Test-Path $ziel)) {
        try {
            Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/tesseract-ocr/tessdata/main/$sprache.traineddata" -OutFile "$ziel.neu"
            Move-Item "$ziel.neu" $ziel -Force
        } finally {
            Remove-Item "$ziel.neu" -Force -ErrorAction SilentlyContinue
        }
    }
}

$gs = Find-Ghostscript
if (-not $gs) {
    # Offiziellen aktuellen Windows-Installer von Artifex herunterladen.
    $release = Invoke-RestMethod "https://api.github.com/repos/ArtifexSoftware/ghostpdl-downloads/releases/latest" -Headers @{"User-Agent"="OCR-System-Installer"}
    $asset = $release.assets | Where-Object { $_.name -match '^gs\d+w64\.exe$' } | Select-Object -First 1
    if (-not $asset) { throw "Kein passender Ghostscript-Installer im offiziellen Release gefunden." }
    $setup = Join-Path $env:TEMP ("ghostscript-" + [guid]::NewGuid().ToString() + ".exe")
    try {
        Invoke-WebRequest -UseBasicParsing $asset.browser_download_url -OutFile $setup
        Write-Host "Bitte die Installation im Ghostscript-Setup abschliessen (Standardordner verwenden)."
        $prozess = Start-Process -FilePath $setup -Wait -PassThru
        if ($prozess.ExitCode -ne 0) { throw "Ghostscript-Setup meldet Fehler $($prozess.ExitCode)." }
    } finally {
        Remove-Item $setup -Force -ErrorAction SilentlyContinue
    }
    $gs = Find-Ghostscript
    if (-not $gs) { throw "Ghostscript wurde nicht im Standardordner gefunden. Bitte PATH pruefen." }
}

Add-SystemPath (Split-Path $tesseract)
Add-SystemPath (Split-Path $gs)

if ($env:TESSDATA_PREFIX -and $env:TESSDATA_PREFIX.TrimEnd("\", "/") -ne $tessdata.TrimEnd("\", "/")) {
    Write-Warning "TESSDATA_PREFIX zeigt auf '$env:TESSDATA_PREFIX'. Fuer diese Installation bitte entfernen oder auf '$tessdata' setzen."
}
$langs = & $tesseract --tessdata-dir $tessdata --list-langs 2>&1
if ($LASTEXITCODE -ne 0) { throw "Sprachdatenpruefung fehlgeschlagen: $langs" }
$langs | ForEach-Object { Write-Host $_ }
foreach ($sprache in @("deu", "osd")) {
    if (-not ($langs | Where-Object { "$_".Trim() -eq $sprache })) {
        throw "Sprachpaket $sprache wurde nicht erkannt."
    }
}
& $gs --version
if ($LASTEXITCODE -ne 0) { throw "Ghostscript konnte nicht gestartet werden." }
Write-Host "Fertig. Neue Programme/Terminals neu starten, damit der globale PATH wirksam wird."
Write-Host "Python-Pakete separat installieren: python -m pip install -r requirements.txt"
