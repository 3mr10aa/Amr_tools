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
    # Borderless custom caption: removes the bright Windows title strip while
    # retaining the AMR icon and title in a matching, clean dark header.
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.ClientSize = New-Object System.Drawing.Size(590,310)
    $form.BackColor = [System.Drawing.Color]::FromArgb(22,29,41)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $true
    $form.TopMost = $true

    # Custom caption strip uses the same dark palette (no white Windows bar).
    $caption = New-Object System.Windows.Forms.Panel
    $caption.Location = New-Object System.Drawing.Point(0,0)
    $caption.Size = New-Object System.Drawing.Size(590,36)
    $caption.BackColor = [System.Drawing.Color]::FromArgb(38,52,70)
    $form.Controls.Add($caption)

    $captionIcon = New-Object System.Windows.Forms.PictureBox
    $captionIcon.Location = New-Object System.Drawing.Point(12,7)
    $captionIcon.Size = New-Object System.Drawing.Size(22,22)
    $captionIcon.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
    $caption.Controls.Add($captionIcon)

    $captionTitle = New-Object System.Windows.Forms.Label
    $captionTitle.Location = New-Object System.Drawing.Point(42,4)
    $captionTitle.Size = New-Object System.Drawing.Size(430,28)
    $captionTitle.Text = 'AMR  |  WINDOWS UTILITY'
    $captionTitle.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $captionTitle.ForeColor = [System.Drawing.Color]::White
    $captionTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $caption.Controls.Add($captionTitle)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(552,3)
    $closeButton.Size = New-Object System.Drawing.Size(32,28)
    $closeButton.Text = '×'
    $closeButton.Font = New-Object System.Drawing.Font('Segoe UI',15,[System.Drawing.FontStyle]::Regular)
    $closeButton.ForeColor = [System.Drawing.Color]::FromArgb(210,220,233)
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(45,65,88)
    $closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $closeButton.FlatAppearance.BorderSize = 0
    $closeButton.Add_Click({ $form.Close() })
    $caption.Controls.Add($closeButton)

    # Allow dragging the custom caption just like a normal Windows title bar.
    if (-not ('AMR.LauncherCaptionNative' -as [type])) {
        Add-Type -Namespace AMR -Name LauncherCaptionNative -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ReleaseCapture();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern System.IntPtr SendMessage(System.IntPtr hWnd, int msg, int wParam, int lParam);
'@
    }

    # Windows 10/11 acrylic blur (frosted-glass) for the launcher body.
    # The separate darker caption strip creates a refined glass-on-glass hierarchy.
    if (-not ('AMR.LauncherAcrylicNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AMR {
    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy { public int AccentState; public int AccentFlags; public int GradientColor; public int AnimationId; }
    [StructLayout(LayoutKind.Sequential)]
    public struct WindowCompositionAttributeData { public int Attribute; public IntPtr Data; public int SizeOfData; }
    public static class LauncherAcrylicNative {
        [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
        [DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int processId);
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extraData);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out int processId);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
        private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr extraData);
        public static IntPtr FindVisibleWindow(int targetPid) {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate(IntPtr hwnd, IntPtr extra) {
                int pid; GetWindowThreadProcessId(hwnd, out pid);
                if (pid == targetPid && IsWindowVisible(hwnd)) { found = hwnd; return false; }
                return true;
            }, IntPtr.Zero);
            return found;
        }
    }
}
'@
    }
    $applyAMRAcrylic = {
        try {
            $policy = New-Object AMR.AccentPolicy
            $policy.AccentState = 4       # ACCENT_ENABLE_ACRYLICBLURBEHIND
            $policy.AccentFlags = 2
            # Lower alpha keeps the backdrop visibly translucent instead of painting
            # the whole launcher as a solid blue panel (AABBGGRR).
            $policy.GradientColor = [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]0x44563A20),0)
            $size = [Runtime.InteropServices.Marshal]::SizeOf([type][AMR.AccentPolicy])
            $memory = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
            try {
                [Runtime.InteropServices.Marshal]::StructureToPtr($policy,$memory,$false)
                $data = New-Object AMR.WindowCompositionAttributeData
                $data.Attribute = 19 # WCA_ACCENT_POLICY
                $data.Data = $memory
                $data.SizeOfData = $size
                $glassApplied = [AMR.LauncherAcrylicNative]::SetWindowCompositionAttribute($form.Handle,[ref]$data)
                if (-not $glassApplied) {
                    # Compatibility fallback: classic blur-behind still gives a
                    # translucent glass surface on builds without acrylic support.
                    $policy.AccentState = 3 # ACCENT_ENABLE_BLURBEHIND
                    [Runtime.InteropServices.Marshal]::StructureToPtr($policy,$memory,$true)
                    $glassApplied = [AMR.LauncherAcrylicNative]::SetWindowCompositionAttribute($form.Handle,[ref]$data)
                }
                if (-not $glassApplied) { Write-LauncherLog 'Windows did not accept acrylic or blur composition; launcher is using its dark glass fallback.' }
            } finally { [Runtime.InteropServices.Marshal]::FreeHGlobal($memory) }
        } catch { Write-LauncherLog ('Acrylic glass effect unavailable; using fallback background: {0}' -f $_.Exception.Message) }
    }.GetNewClosure()
    $form.Add_Shown($applyAMRAcrylic)
    $caption.Add_MouseDown({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [void][AMR.LauncherCaptionNative]::ReleaseCapture()
            [void][AMR.LauncherCaptionNative]::SendMessage($form.Handle,0xA1,0x2,0)
        }
    })
    $captionTitle.Add_MouseDown({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [void][AMR.LauncherCaptionNative]::ReleaseCapture()
            [void][AMR.LauncherCaptionNative]::SendMessage($form.Handle,0xA1,0x2,0)
        }
    })

    $thanks = New-Object System.Windows.Forms.Label
    $thanks.Location = New-Object System.Drawing.Point(30,49)
    $thanks.Size = New-Object System.Drawing.Size(530,25)
    $thanks.Text = 'Thank you for your trust and support. We truly appreciate you.'
    $thanks.Font = New-Object System.Drawing.Font('Segoe UI',12,[System.Drawing.FontStyle]::Bold)
    $thanks.BackColor = [System.Drawing.Color]::Transparent
    $thanks.ForeColor = [System.Drawing.Color]::White
    $thanks.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($thanks)

    $edition = New-Object System.Windows.Forms.Label
    $edition.Location = New-Object System.Drawing.Point(30,81)
    $edition.Size = New-Object System.Drawing.Size(530,27)
    $edition.Text = 'PREMIUM EDITION'
    $edition.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $edition.BackColor = [System.Drawing.Color]::Transparent
    $edition.ForeColor = [System.Drawing.Color]::FromArgb(229,190,75)
    $edition.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($edition)

    $tagline = New-Object System.Windows.Forms.Label
    $tagline.Location = New-Object System.Drawing.Point(30,112)
    $tagline.Size = New-Object System.Drawing.Size(530,22)
    $tagline.Text = 'We work hard every day for your happiness.'
    $tagline.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Regular)
    $tagline.BackColor = [System.Drawing.Color]::Transparent
    $tagline.ForeColor = [System.Drawing.Color]::FromArgb(198,211,228)
    $tagline.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($tagline)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(42,151)
    $statusLabel.Size = New-Object System.Drawing.Size(506,24)
    $statusLabel.Text = 'Getting everything ready for you...'
    $statusLabel.Font = New-Object System.Drawing.Font('Segoe UI',10,[System.Drawing.FontStyle]::Bold)
    $statusLabel.BackColor = [System.Drawing.Color]::Transparent
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(241,245,249)
    $form.Controls.Add($statusLabel)

    $progressTrack = New-Object System.Windows.Forms.Panel
    $progressTrack.Location = New-Object System.Drawing.Point(42,187)
    $progressTrack.Size = New-Object System.Drawing.Size(440,12)
    $progressTrack.BackColor = [System.Drawing.Color]::FromArgb(48,67,91)
    $progressTrack.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $form.Controls.Add($progressTrack)

    $progressFill = New-Object System.Windows.Forms.Panel
    $progressFill.Location = New-Object System.Drawing.Point(0,0)
    $progressFill.Size = New-Object System.Drawing.Size(0,12)
    $progressFill.BackColor = [System.Drawing.Color]::FromArgb(72,166,255)
    $progressTrack.Controls.Add($progressFill)
    $progressBar = $progressFill

    $percentLabel = New-Object System.Windows.Forms.Label
    $percentLabel.Location = New-Object System.Drawing.Point(490,180)
    $percentLabel.Size = New-Object System.Drawing.Size(58,25)
    $percentLabel.Text = '0%'
    $percentLabel.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
    $percentLabel.BackColor = [System.Drawing.Color]::Transparent
    $percentLabel.ForeColor = [System.Drawing.Color]::FromArgb(112,190,255)
    $percentLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $form.Controls.Add($percentLabel)

    $detailLabel = New-Object System.Windows.Forms.Label
    $detailLabel.Location = New-Object System.Drawing.Point(42,214)
    $detailLabel.Size = New-Object System.Drawing.Size(506,22)
    $detailLabel.Text = 'Preparing secure connection to AMR servers...'
    $detailLabel.Font = New-Object System.Drawing.Font('Segoe UI',8)
    $detailLabel.BackColor = [System.Drawing.Color]::Transparent
    $detailLabel.ForeColor = [System.Drawing.Color]::FromArgb(157,174,196)
    $detailLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $form.Controls.Add($detailLabel)

    $footer = New-Object System.Windows.Forms.Label
    $footer.Location = New-Object System.Drawing.Point(30,258)
    $footer.Size = New-Object System.Drawing.Size(530,20)
    $footer.Text = 'SECURE DOWNLOAD  •  VERIFIED SCRIPT  •  AMR'
    $footer.Font = New-Object System.Drawing.Font('Segoe UI',7,[System.Drawing.FontStyle]::Bold)
    $footer.BackColor = [System.Drawing.Color]::Transparent
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
    # Reuse a single high-resolution PNG frame from the embedded AMR multi-size
    # ICO. System.Drawing.Icon.ToBitmap() may select a tiny low-quality frame from
    # a multi-image ICO, which caused the colored pixel mosaic in the caption.
    try {
        $iconMatch = [regex]::Match($scriptText, '\$amrIconBytes\s*=\s*\[Convert\]::FromBase64String\(''([^'']+)''\)')
        if ($iconMatch.Success) {
            $iconBytes = [Convert]::FromBase64String($iconMatch.Groups[1].Value)
            if ($iconBytes.Length -ge 22 -and $iconBytes[0] -eq 0 -and $iconBytes[1] -eq 0 -and $iconBytes[2] -eq 1) {
                $frameCount = [BitConverter]::ToUInt16($iconBytes,4)
                $chosen = $null
                for ($i=0; $i -lt $frameCount; $i++) {
                    $entry = 6 + (16 * $i)
                    $w = [int]$iconBytes[$entry]; if ($w -eq 0) { $w = 256 }
                    $h = [int]$iconBytes[$entry+1]; if ($h -eq 0) { $h = 256 }
                    $length = [BitConverter]::ToUInt32($iconBytes,$entry+8)
                    $offset = [BitConverter]::ToUInt32($iconBytes,$entry+12)
                    if ($w -ge 48 -and $h -ge 48 -and $offset -ge 0 -and ($offset + $length) -le $iconBytes.Length) {
                        $chosen = @{ Width=$w; Height=$h; Length=[int]$length; Offset=[int]$offset; Area=($w*$h) }
                        break
                    }
                }
                if ($null -ne $chosen) {
                    $pngBytes = New-Object byte[] $chosen.Length
                    [Buffer]::BlockCopy($iconBytes,$chosen.Offset,$pngBytes,0,$chosen.Length)
                    $pngStream = New-Object System.IO.MemoryStream(,$pngBytes)
                    try {
                        $sourceImage = [System.Drawing.Image]::FromStream($pngStream)
                        try { $captionIcon.Image = New-Object System.Drawing.Bitmap($sourceImage) } finally { $sourceImage.Dispose() }
                    } finally { $pngStream.Dispose() }
                    # Build a one-frame ICO at the selected resolution for a crisp taskbar icon.
                    $singleIco = New-Object byte[] (22 + $chosen.Length)
                    $singleIco[2] = 1; $singleIco[4] = 1
                    $singleIco[6] = [byte]($chosen.Width -band 255)
                    $singleIco[7] = [byte]($chosen.Height -band 255)
                    $singleIco[10] = 1; $singleIco[12] = 32
                    [Buffer]::BlockCopy([BitConverter]::GetBytes([uint32]$chosen.Length),0,$singleIco,14,4)
                    [Buffer]::BlockCopy([BitConverter]::GetBytes([uint32]22),0,$singleIco,18,4)
                    [Buffer]::BlockCopy($pngBytes,0,$singleIco,22,$chosen.Length)
                    $iconStream = New-Object System.IO.MemoryStream(,$singleIco)
                    try { $form.Icon = New-Object System.Drawing.Icon($iconStream) } finally { $iconStream.Dispose() }
                    Write-LauncherLog ('Loaded clean {0}x{1} AMR caption/taskbar icon frame.' -f $chosen.Width,$chosen.Height)
                } else { throw 'No suitable high-resolution PNG frame was found in the embedded AMR icon.' }
            } else { throw 'Embedded AMR icon data is not a valid ICO file.' }
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
    $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "{0}" -AMRLauncherReadyPath "{1}"' -f $installPath,$readyPath

    # Pass handshake paths as script arguments: these survive the UAC elevation boundary.
    $appProcess = Start-Process -FilePath $powershellExe -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop
    Write-LauncherLog ('Elevated application process started (PID {0}). Waiting for WPF ready signal.' -f $appProcess.Id)
    Set-AMRLauncherProgress -Percent 97 -Status 'Almost there...' -Detail 'Preparing your application window. Please wait...'
    $windowReady = $false
    $handoffStarted = [DateTime]::UtcNow
    $lastProgressUpdate = $handoffStarted
    $handoffDeadline = $handoffStarted.AddSeconds(180)
    $visibleWindowSince = $null
    $visibleWindowHandle = [IntPtr]::Zero
    while ([DateTime]::UtcNow -lt $handoffDeadline) {
        [System.Windows.Forms.Application]::DoEvents()
        if (Test-Path -LiteralPath $readyPath -PathType Leaf) {
            $windowReady = $true
            Write-LauncherLog 'Main application ready marker received.'
            break
        }
        $appProcess.Refresh()
        if ($appProcess.HasExited) { throw 'The AMR application process exited before its main window was ready.' }

        # Fail-safe handoff: some WPF/PowerShell 5.1 runs render the window but
        # the ContentRendered marker write can fail silently. Detect the actual
        # visible top-level window and require it to remain visible for 2.5 sec.
        $candidateHandle = [IntPtr]::Zero
        try {
            $candidateHandle = $appProcess.MainWindowHandle
            if ($candidateHandle -eq [IntPtr]::Zero) {
                $candidateHandle = [AMR.LauncherAcrylicNative]::FindVisibleWindow($appProcess.Id)
            }
        } catch {}
        if ($candidateHandle -ne [IntPtr]::Zero) {
            if ($candidateHandle -ne $visibleWindowHandle) {
                $visibleWindowHandle = $candidateHandle
                $visibleWindowSince = [DateTime]::UtcNow
            } elseif ($null -ne $visibleWindowSince -and ([DateTime]::UtcNow - $visibleWindowSince).TotalSeconds -ge 2.5) {
                $windowReady = $true
                Write-LauncherLog ('Ready marker was absent, but AMR main window {0} remained visible for 2.5 seconds; using verified-window fallback.' -f $candidateHandle)
                break
            }
        } else {
            $visibleWindowHandle = [IntPtr]::Zero
            $visibleWindowSince = $null
        }

        if (([DateTime]::UtcNow - $lastProgressUpdate).TotalSeconds -ge 5) {
            $elapsed = ([DateTime]::UtcNow - $handoffStarted).TotalSeconds
            $slowPercent = if ($elapsed -ge 15) { 99 } elseif ($elapsed -ge 7) { 98 } else { 97 }
            if ($slowPercent -gt $progressValue) { Set-AMRLauncherProgress -Percent $slowPercent -Status 'Almost there...' -Detail 'Finishing interface preparation...' }
            $lastProgressUpdate = [DateTime]::UtcNow
        }
        Start-Sleep -Milliseconds 100
    }
    if (-not $windowReady) { throw 'AMR did not report readiness and no stable visible application window was detected within 180 seconds. Check the launcher log.' }
    # 100% is shown exactly once, at the actual handoff.
    Set-AMRLauncherProgress -Percent 100 -Status 'Your AMR experience is ready!' -Detail 'Thank you for being part of our journey.'
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 350
    Write-LauncherLog 'WPF first render confirmed; closing launcher and activating the application window.'
    # Capture the real WPF top-level handle before closing the topmost splash.
    $appWindowHandle = [IntPtr]::Zero
    try {
        $appProcess.Refresh()
        $appWindowHandle = $appProcess.MainWindowHandle
        if ($appWindowHandle -eq [IntPtr]::Zero) { $appWindowHandle = [AMR.LauncherAcrylicNative]::FindVisibleWindow($appProcess.Id) }
    } catch {}
    if ($form -and -not $form.IsDisposed) { $form.TopMost = $false; $form.Close(); $form.Dispose(); $form = $null }
    # Explicit foreground handoff prevents the hidden PowerShell host from leaving
    # the desktop on a dark/black surface after the splash disappears.
    if ($appWindowHandle -ne [IntPtr]::Zero) {
        try {
            [void][AMR.LauncherAcrylicNative]::AllowSetForegroundWindow($appProcess.Id)
            [void][AMR.LauncherAcrylicNative]::ShowWindow($appWindowHandle,9) # SW_RESTORE
            [void][AMR.LauncherAcrylicNative]::SetForegroundWindow($appWindowHandle)
            Write-LauncherLog ('Activated AMR WPF window handle {0}.' -f $appWindowHandle)
        } catch { Write-LauncherLog ('Could not explicitly activate AMR window: {0}' -f $_.Exception.Message) }
    } else {
        Write-LauncherLog 'WPF ready signal arrived but MainWindowHandle was zero; application remains running.'
    }
    Remove-Item -LiteralPath $readyPath -Force -ErrorAction SilentlyContinue

}
catch {
    Write-LauncherLog ('LAUNCHER ERROR: {0}' -f $_.Exception.Message)
    # The application window is never hidden; do not leave a stale handoff signal.
    try { Remove-Item -LiteralPath $readyPath -Force -ErrorAction SilentlyContinue } catch {}
    try {
        if ($form -and -not $form.IsDisposed) { $form.Close(); $form.Dispose(); $form = $null }
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(('AMR Utility could not start.`r`n`r`n{0}`r`n`r`nDetails: {1}' -f $_.Exception.Message,$logPath),'AMR Utility Launcher',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    } catch {}
}
finally {
    try { if ($form -and -not $form.IsDisposed) { $form.Close(); $form.Dispose() } } catch {}
    if (Test-Path -LiteralPath $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue }
    try { Remove-Item -LiteralPath $readyPath -Force -ErrorAction SilentlyContinue } catch {}
}
exit
