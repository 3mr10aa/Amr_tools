# Amr Utility - Bootstrap Installer
# Usage:
# irm "YOUR_SHORT_URL" | iex

$ErrorActionPreference = 'Stop'

$amrSourceUrl = 'https://raw.githubusercontent.com/3mr10aa/Amr_tools/main/Amr_utility.ps1'
$amrInstallPath = Join-Path $env:TEMP 'Amr_utility.ps1'

try {
    Write-Host 'Downloading Amr Utility...' -ForegroundColor Cyan

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $amrSourceUrl -OutFile $amrInstallPath -UseBasicParsing

    if (-not (Test-Path -LiteralPath $amrInstallPath)) {
        throw 'The download did not create the installer file.'
    }

    $downloadedFile = Get-Item -LiteralPath $amrInstallPath
    if ($downloadedFile.Length -lt 1000) {
        throw 'The downloaded script looks incomplete or empty.'
    }

    Write-Host 'Download complete. Starting Amr Utility...' -ForegroundColor Green

    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    $launchArguments = '-NoProfile -ExecutionPolicy Bypass -STA -File "{0}"' -f $amrInstallPath

    Start-Process -FilePath $powershellExe -ArgumentList $launchArguments
}
catch {
    Write-Host ('Amr Utility could not be started: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Check your internet connection and try again.' -ForegroundColor Yellow
}
