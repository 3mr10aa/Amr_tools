# Amr Utility - UTF-8 Safe Bootstrap Launcher
# Public command remains:
# irm https://tinyurl.com/Amr-t00l | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sourceUrl = 'https://raw.githubusercontent.com/3mr10aa/Amr_tools/main/Amr_utility.ps1'
$downloadPath = Join-Path $env:TEMP 'Amr_utility.download'
$installPath = Join-Path $env:TEMP 'Amr_utility.ps1'
$logPath = Join-Path $env:TEMP 'Amr_Utility_Launcher.log'

function Write-LauncherLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try { Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 } catch {}
    Write-Host $Message
}

try {
    Write-LauncherLog 'Downloading Amr Utility...'

    # Download the original bytes so Windows PowerShell does not guess the encoding.
    Invoke-WebRequest -Uri $sourceUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $downloadPath -PathType Leaf)) {
        throw 'The download did not create the application file.'
    }

    $downloadedFile = Get-Item -LiteralPath $downloadPath
    if ($downloadedFile.Length -lt 1000) {
        throw "The downloaded application file is too small ($($downloadedFile.Length) bytes)."
    }

    # Decode explicitly as UTF-8, while allowing StreamReader to detect an existing BOM.
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $reader = New-Object System.IO.StreamReader($downloadPath, $strictUtf8, $true)
    try {
        $scriptText = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }

    if ($scriptText -match '(?i)^\s*<!doctype\s+html|^\s*<html') {
        throw 'GitHub returned an HTML page instead of the PowerShell application.'
    }

    # Save with a UTF-8 BOM for compatibility with Windows PowerShell 5.1.
    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($installPath, $scriptText, $utf8WithBom)

    # Validate syntax before starting the application.
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $installPath,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    if ($parseErrors.Count -gt 0) {
        $firstErrors = ($parseErrors | Select-Object -First 5 | ForEach-Object {
            'Line {0}: {1}' -f $_.Extent.StartLineNumber, $_.Message
        }) -join [Environment]::NewLine
        throw "The downloaded script failed its PowerShell syntax check:`n$firstErrors"
    }

    Write-LauncherLog ("Download and syntax check complete ({0:N0} bytes)." -f (Get-Item -LiteralPath $installPath).Length)
    Write-LauncherLog 'Starting Amr Utility...'

    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellExe)) {
        $powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "{0}"' -f $installPath
    Start-Process -FilePath $powershellExe -ArgumentList $arguments -ErrorAction Stop | Out-Null
}
catch {
    Write-LauncherLog ("LAUNCHER ERROR: {0}" -f $_.Exception.Message)
    Write-Host "Details saved to: $logPath" -ForegroundColor Yellow
    Write-Host 'Press Enter to close this window...' -ForegroundColor Yellow
    try { [void](Read-Host) } catch {}
}
finally {
    if (Test-Path -LiteralPath $downloadPath) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
}
