# AMR Utility - Silent, elevated bootstrap launcher
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
    try {
        Add-Content -LiteralPath $logPath -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) -Encoding UTF8
    } catch {}
}

try {
    Write-LauncherLog 'Downloading AMR Utility from GitHub.'

    Invoke-WebRequest -Uri $sourceUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $downloadPath -PathType Leaf)) {
        throw 'The download did not create the application file.'
    }

    $downloadedFile = Get-Item -LiteralPath $downloadPath
    if ($downloadedFile.Length -lt 100000) {
        throw ('The downloaded application file is unexpectedly small ({0} bytes).' -f $downloadedFile.Length)
    }

    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $reader = New-Object System.IO.StreamReader($downloadPath, $strictUtf8, $true)
    try {
        $scriptText = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }

    if ($scriptText -match '(?i)^\s*<!doctype\s+html|^\s*<html') {
        throw 'GitHub returned an HTML page instead of the PowerShell application.'
    }
    if ($scriptText -match 'Thank you for choosing AMR') {
        throw 'The GitHub main script still contains the old welcome message. Update Amr_utility.ps1 on the main branch first.'
    }

    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($installPath, $scriptText, $utf8WithBom)

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

    Write-LauncherLog ('Download and syntax check complete ({0:N0} bytes).' -f (Get-Item -LiteralPath $installPath).Length)

    # Start the application directly in an elevated, hidden STA process.
    # The Windows UAC consent prompt remains visible when Windows requires it.
    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellExe)) {
        $powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "{0}"' -f $installPath
    $shell = New-Object -ComObject Shell.Application
    try {
        $shell.ShellExecute($powershellExe, $arguments, '', 'runas', 0)
    } finally {
        if ($null -ne $shell) {
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
        }
    }

    Write-LauncherLog 'AMR Utility handoff completed.'
}
catch {
    Write-LauncherLog ('LAUNCHER ERROR: {0}' -f $_.Exception.Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            ('AMR Utility could not start.`r`n`r`n{0}`r`n`r`nDetails: {1}' -f $_.Exception.Message, $logPath),
            'AMR Utility Launcher',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    } catch {}
}
finally {
    if (Test-Path -LiteralPath $downloadPath) {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
}

# Close the PowerShell host after the hidden elevated application is handed off.
exit
