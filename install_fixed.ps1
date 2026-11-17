# AMR Utility - Premium branded download launcher (Windows PowerShell 5.1)
# Public command remains: irm https://tinyurl.com/Amr-t00l | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$sourceUrl = 'https://raw.githubusercontent.com/3mr10aa/Amr_tools/main/Amr_utility.ps1'
$downloadPath = Join-Path $env:TEMP 'Amr_utility.download'
$installPath = Join-Path $env:TEMP 'Amr_utility.ps1'
$logPath = Join-Path $env:TEMP 'Amr_Utility_Launcher.log'
$handoffId = [guid]::NewGuid().ToString('N')
$readyPath = Join-Path $env:TEMP ('AMR_{0}.ready' -f $handoffId)
$releasePath = Join-Path $env:TEMP ('AMR_{0}.release' -f $handoffId)

function Write-LauncherLog {
    param([string]$Message)
    try { Add-Content -LiteralPath $logPath -Value ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message) -Encoding UTF8 } catch {}
}

$form = $null
$progressBar = $null
$statusLabel = $null
$percentLabel = $null
$detailLabel = $null
$progressTrack = $null
$progressFill = $null
$progressValue = 0

function Set-AMRLauncherProgress {
    param([int]$Percent,[string]$Status,[string]$Detail)
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($Percent -ge 0) {
        $script:progressValue = [Math]::Max(0,[Math]::Min(100,$Percent))
        $progressFill.Width = [int](($progressTrack.ClientSize.Width * $script:progressValue) / 100)
        $percentLabel.Text = ('{0}%' -f $script:progressValue)
    } else {
        $percentLabel.Text = '...'
    }
    $statusLabel.Text = $Status
    $detailLabel.Text = $Detail
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Premium AMR splash: shown by the launcher only, never by the main application.
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'AMR Windows Utility'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ClientSize = New-Object System.Drawing.Size(590,310)
    $form.BackColor = [System.Drawing.Color]::FromArgb(18,30,48)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true
    $form.TopMost = $true

    $brand = New-Object System.Windows.Forms.Label
    $brand.Location = New-Object System.Drawing.Point(28,25)
    $brand.Size = New-Object System.Drawing.Size(534,34)
    $brand.Text = 'AMR  |  WINDOWS UTILITY'
    $brand.Font = New-Object System.Drawing.Font('Segoe UI',19,[System.Drawing.FontStyle]::Bold)
    $brand.ForeColor = [System.Drawing.Color]::FromArgb(96,165,250)
    $brand.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($brand)

    $thanks = New-Object System.Windows.Forms.Label
    $thanks.Location = New-Object System.Drawing.Point(30,67)
    $thanks.Size = New-Object System.Drawing.Size(530,25)
    $thanks.Text = 'Thank you for your trust and support. We truly appreciate you.'
    $thanks.Font = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
    $thanks.ForeColor = [System.Drawing.Color]::FromArgb(229,195,90)
    $thanks.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($thanks)

    $edition = New-Object System.Windows.Forms.Label
    $edition.Location = New-Object System.Drawing.Point(30,99)
    $edition.Size = New-Object System.Drawing.Size(530,27)
    $edition.Text = 'PREMIUM EDITION'
    $edition.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $edition.ForeColor = [System.Drawing.Color]::FromArgb(229,190,75)
    $edition.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($edition)

    $tagline = New-Object System.Windows.Forms.Label
    $tagline.Location = New-Object System.Drawing.Point(30,130)
    $tagline.Size = New-Object System.Drawing.Size(530,22)
    $tagline.Text = 'We work hard every day for your happiness.'
    $tagline.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Regular)
    $tagline.ForeColor = [System.Drawing.Color]::FromArgb(190,205,224)
    $tagline.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($tagline)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(42,169)
    $statusLabel.Size = New-Object System.Drawing.Size(506,24)
    $statusLabel.Text = 'Getting everything ready for you...'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(241,245,249)
    $form.Controls.Add($statusLabel)

    $progressTrack = New-Object System.Windows.Forms.Panel
    $progressTrack.Location = New-Object System.Drawing.Point(42,205)
    $progressTrack.Size = New-Object System.Drawing.Size(440,12)
    $progressTrack.BackColor = [System.Drawing.Color]::FromArgb(43,59,80)
    $progressTrack.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $form.Controls.Add($progressTrack)

    $progressFill = New-Object System.Windows.Forms.Panel
    $progressFill.Location = New-Object System.Drawing.Point(0,0)
    $progressFill.Size = New-Object System.Drawing.Size(0,12)
    $progressFill.BackColor = [System.Drawing.Color]::FromArgb(59,151,255)
    $progressTrack.Controls.Add($progressFill)
    $progressBar = $progressFill

    $percentLabel = New-Object System.Windows.Forms.Label
    $percentLabel.Location = New-Object System.Drawing.Point(490,198)
    $percentLabel.Size = New-Object System.Drawing.Size(58,25)
    $percentLabel.Text = '0%'
    $percentLabel.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $percentLabel.ForeColor = [System.Drawing.Color]::FromArgb(96,177,255)
    $percentLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $form.Controls.Add($percentLabel)

    $detailLabel = New-Object System.Windows.Forms.Label
    $detailLabel.Location = New-Object System.Drawing.Point(42,232)
    $detailLabel.Size = New-Object System.Drawing.Size(506,22)
    $detailLabel.Text = 'Preparing secure connection to AMR servers...'
    $detailLabel.Font = New-Object System.Drawing.Font('Segoe UI',8)
    $detailLabel.ForeColor = [System.Drawing.Color]::FromArgb(148,163,184)
    $detailLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $form.Controls.Add($detailLabel)

    $footer = New-Object System.Windows.Forms.Label
    $footer.Location = New-Object System.Drawing.Point(30,276)
    $footer.Size = New-Object System.Drawing.Size(530,20)
    $footer.Text = 'SECURE DOWNLOAD  •  VERIFIED SCRIPT  •  AMR'
    $footer.Font = New-Object System.Drawing.Font('Segoe UI',7,[System.Drawing.FontStyle]::Bold)
    $footer.ForeColor = [System.Drawing.Color]::FromArgb(126,151,181)
    $footer.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($footer)

    $form.Show()
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()

    Write-LauncherLog 'Starting AMR launcher download.'
    Set-AMRLauncherProgress -Percent 0 -Status 'Getting everything ready for you...' -Detail 'Connecting securely to GitHub...'

    # Stream the response ourselves so the percentage reflects bytes actually received.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $request = [System.Net.HttpWebRequest]::Create($sourceUrl)
    $request.Method = 'GET'
    $request.UserAgent = 'AMR-Windows-Utility-Launcher/1.0'
    $request.AllowAutoRedirect = $true
    $request.Timeout = 30000
    $request.ReadWriteTimeout = 30000
    $response = $request.GetResponse()
    try {
        $totalBytes = [int64]$response.ContentLength
        $inputStream = $response.GetResponseStream()
        $outputStream = New-Object System.IO.FileStream($downloadPath,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
        try {
            $buffer = New-Object byte[] 65536
            [int64]$received = 0
            while (($read = $inputStream.Read($buffer,0,$buffer.Length)) -gt 0) {
                $outputStream.Write($buffer,0,$read)
                $received += $read
                if ($totalBytes -gt 0) {
                    $pct = [int][Math]::Floor(($received / [double]$totalBytes) * 85)
                    $pct = [Math]::Min(85,$pct)
                    $detail = '{0:N1} MB of {1:N1} MB downloaded' -f ($received/1MB),($totalBytes/1MB)
                    Set-AMRLauncherProgress -Percent $pct -Status 'Downloading your AMR experience...' -Detail $detail
                } else {
                    Set-AMRLauncherProgress -Percent -1 -Status 'Downloading your AMR experience...' -Detail ('{0:N1} MB received — measuring download...' -f ($received/1MB))
                }
            }
        } finally {
            $outputStream.Dispose()
            $inputStream.Dispose()
        }
    } finally { $response.Dispose() }

    if (-not (Test-Path -LiteralPath $downloadPath -PathType Leaf)) { throw 'The download did not create the application file.' }
    $downloadedFile = Get-Item -LiteralPath $downloadPath
    if ($downloadedFile.Length -lt 100000) { throw ('The downloaded application file is unexpectedly small ({0} bytes).' -f $downloadedFile.Length) }

    Set-AMRLauncherProgress -Percent 90 -Status 'Download complete — verifying AMR...' -Detail ('{0:N2} MB received. Checking file integrity and PowerShell syntax.' -f ($downloadedFile.Length/1MB))
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false,$true)
    $reader = New-Object System.IO.StreamReader($downloadPath,$strictUtf8,$true)
    try { $scriptText = $reader.ReadToEnd() } finally { $reader.Dispose() }
    # Reuse the exact embedded AMR application icon for the launcher and its taskbar entry.
    try {
        $iconMatch = [regex]::Match($scriptText, '\$amrIconBytes\s*=\s*\[Convert\]::FromBase64String\(''([^'']+)''\)')
        if ($iconMatch.Success) {
            $iconBytes = [Convert]::FromBase64String($iconMatch.Groups[1].Value)
            $iconStream = New-Object System.IO.MemoryStream(,$iconBytes)
            try { $form.Icon = New-Object System.Drawing.Icon($iconStream) } finally { $iconStream.Dispose() }
        }
    } catch { Write-LauncherLog ('Could not apply embedded AMR icon to launcher: {0}' -f $_.Exception.Message) }
    if ($scriptText -match '(?i)^\s*<!doctype\s+html|^\s*<html') { throw 'GitHub returned an HTML page instead of the PowerShell application.' }
    if ($scriptText -match 'Thank you for choosing AMR') { throw 'The GitHub main script still contains the old welcome message. Update Amr_utility.ps1 on the main branch first.' }
    if ($scriptText -match 'Getting things ready\.\.\.') { throw 'The GitHub main script still contains the old startup splash. Replace it with the silent main script first.' }

    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($installPath,$scriptText,$utf8WithBom)
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($installPath,[ref]$tokens,[ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        $firstErrors = ($parseErrors | Select-Object -First 5 | ForEach-Object { 'Line {0}: {1}' -f $_.Extent.StartLineNumber,$_.Message }) -join [Environment]::NewLine
        throw "The downloaded script failed its PowerShell syntax check:`n$firstErrors"
    }
    Write-LauncherLog ('Download and syntax check complete ({0:N0} bytes).' -f $downloadedFile.Length)

    Set-AMRLauncherProgress -Percent 96 -Status 'Starting your AMR experience...' -Detail 'Preparing the application interface...'
    [System.Windows.Forms.Application]::DoEvents()
    $powershellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powershellExe)) { $powershellExe = (Get-Command powershell.exe -ErrorAction Stop).Source }
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "{0}" -AMRLauncherReadyPath "{1}" -AMRLauncherReleasePath "{2}"' -f $installPath,$readyPath,$releasePath

    # Pass handshake paths as script arguments: these survive the UAC elevation boundary.
    $appProcess = Start-Process -FilePath $powershellExe -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop
    Write-LauncherLog ('Elevated application process started (PID {0}). Waiting for WPF ready signal.' -f $appProcess.Id)
    Set-AMRLauncherProgress -Percent 97 -Status 'Almost there...' -Detail 'Preparing your application window. Please wait...'
    $windowReady = $false
    $handoffStarted = [DateTime]::UtcNow
    $lastProgressUpdate = $handoffStarted
    $handoffDeadline = $handoffStarted.AddSeconds(180)
    while ([DateTime]::UtcNow -lt $handoffDeadline) {
        [System.Windows.Forms.Application]::DoEvents()
        if (Test-Path -LiteralPath $readyPath -PathType Leaf) { $windowReady = $true; break }
        if (([DateTime]::UtcNow - $lastProgressUpdate).TotalSeconds -ge 5) {
            $elapsed = ([DateTime]::UtcNow - $handoffStarted).TotalSeconds
            $slowPercent = if ($elapsed -ge 15) { 99 } elseif ($elapsed -ge 7) { 98 } else { 97 }
            if ($slowPercent -gt $progressValue) { Set-AMRLauncherProgress -Percent $slowPercent -Status 'Almost there...' -Detail 'Finishing interface preparation...' }
            $lastProgressUpdate = [DateTime]::UtcNow
        }
        $appProcess.Refresh()
        if ($appProcess.HasExited) { throw 'The AMR application process exited before its main window was ready.' }
        Start-Sleep -Milliseconds 80
    }
    if (-not $windowReady) { throw 'AMR did not report that its main window was ready within 180 seconds. Check the launcher log.' }
    # 100% is shown exactly once, at the actual handoff.
    Set-AMRLauncherProgress -Percent 100 -Status 'Your AMR experience is ready!' -Detail 'Thank you for being part of our journey.'
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 350
    Write-LauncherLog 'WPF ready signal received; closing launcher and releasing the application window.'
    if ($form -and -not $form.IsDisposed) { $form.Close(); $form.Dispose(); $form = $null }
    [System.IO.File]::WriteAllText($releasePath,'show')

}
catch {
    Write-LauncherLog ('LAUNCHER ERROR: {0}' -f $_.Exception.Message)
    # If the child is still starting, release its hidden window rather than leave it invisible.
    try { if ($appProcess -and -not $appProcess.HasExited) { [System.IO.File]::WriteAllText($releasePath,'show') } } catch {}
    try {
        if ($form -and -not $form.IsDisposed) { $form.Close(); $form.Dispose(); $form = $null }
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(('AMR Utility could not start.`r`n`r`n{0}`r`n`r`nDetails: {1}' -f $_.Exception.Message,$logPath),'AMR Utility Launcher',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
}
finally {
    try { if ($form -and -not $form.IsDisposed) { $form.Close(); $form.Dispose() } } catch {}
    if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue }
    # The application removes its own ready/release handshake files after reveal.
}
exit
