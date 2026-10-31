# AMR Windows Utility launcher
# Starts the main WPF application in an elevated STA PowerShell process.
$ErrorActionPreference = 'Stop'
$mainScript = Join-Path $PSScriptRoot 'Amr_utility.ps1'

if (-not (Test-Path -LiteralPath $mainScript -PathType Leaf)) {
    Write-Host 'Amr_utility.ps1 was not found next to the launcher.' -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

try {
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "{0}"' -f $mainScript
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
} catch {
    Write-Host ("Could not start AMR Windows Utility: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}
