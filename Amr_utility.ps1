#requires -Version 5.1
<#
Amr | windows_utility - V0.1
Windows 10/11 | Windows PowerShell 5.1 | WPF | Administrator
Developer: عمرو أحمد عبد الفتاح | Phone: 01014716301 | Email: 3mr10aa@gmail.com
#>
[CmdletBinding()]
param()

# --- 0. Force STA Mode for WPF Stability & Prevent Freeze ---
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "& '$PSCommandPath'"
    exit
}

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# --- 1. Admin Privilege Check (Self-Elevation) ---
function Test-AMRAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-AMRAdmin)) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Windows.Forms

# --- 2. Environment & Folders Setup ---
$script:AppRoot     = Join-Path $env:ProgramData 'AMR-Utility'
$script:BackupDir   = Join-Path $script:AppRoot 'Backups'
$script:LogDir      = Join-Path $script:AppRoot 'Logs'
$script:ExportDir   = Join-Path $script:AppRoot 'Exports'
$script:IconDir     = Join-Path $script:AppRoot 'Icons'
$script:DownloadDir = Join-Path $script:AppRoot 'Downloads'

New-Item -ItemType Directory -Force -Path $script:BackupDir,$script:LogDir,$script:ExportDir,$script:IconDir,$script:DownloadDir | Out-Null
$script:LogFile = Join-Path $script:LogDir ("AMR_{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

$script:Window = $null
# Initialize refresh state before registering WPF handlers (StrictMode is enabled).
$script:OverviewRefreshing = $false
$script:Status = $null
$script:ProgressBar = $null
$script:ProgressText = $null

# Categorized UI Log Controls Mapping
$script:LogControls = @{
    'All'       = $null
    'System'    = $null
    'Overview'  = $null
    'Software'  = $null
    'Customize' = $null
    'Cleanup'   = $null
}

# --- Thread-Safe Multi-Category Real-time Logging Engine ---
function Write-AMRLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','DEBUG')][string]$Level='INFO',
        [ValidateSet('System','Overview','Software','Customize','Cleanup')][string]$Area='System'
    )
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logLine = "[$time] [$Level] [$Area] $Message"
    
    Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue
    
    if ($script:Window) {
        try {
            $script:Window.Dispatcher.Invoke([Action]{
                if ($script:LogControls['All']) {
                    $script:LogControls['All'].AppendText("$logLine`r`n")
                    $script:LogControls['All'].ScrollToEnd()
                }
                if ($script:LogControls[$Area]) {
                    $script:LogControls[$Area].AppendText("$logLine`r`n")
                    $script:LogControls[$Area].ScrollToEnd()
                }
            })
        } catch {}
    }
    
    if ($script:Status -and $script:Window) {
        try {
            $script:Window.Dispatcher.Invoke([Action]{
                $script:Status.Text = "[$Area] $Message"
            })
        } catch {}
    }
}

function Show-AMRMessage {
    param(
        [string]$Message,
        [string]$Title='Amr | windows_utility',
        [System.Windows.MessageBoxButton]$Buttons=[System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon=[System.Windows.MessageBoxImage]::Information
    )
    return [System.Windows.MessageBox]::Show($script:Window, $Message, $Title, $Buttons, $Icon)
}

# --- SAFE REGISTRY WRITER ---
function Set-AMRRegistryKey {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$PropertyType='DWord'
    )
    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force -ErrorAction Stop | Out-Null
        Write-AMRLog "Registry set [$Path -> $Name = $Value]" SUCCESS Customize
        return $true
    } catch {
        Write-AMRLog "Failed setting Registry [$Path -> $Name]: $_" ERROR Customize
        return $false
    }
}

# --- 3. EXPANDED SOFTWARE CATALOG (500 APPLICATIONS; 235 EXISTING + 265 ADDITIONS) ---
$RawApps = @(
    # 01. Web Browsers (16 Apps)
    [pscustomobject]@{ Name='Google Chrome'; Category='01. Web Browsers'; Id='Google.Chrome'; ChocoId='googlechrome'; DirectUrl='https://dl.google.com/chrome/install/standalonesetup64.exe'; DirectArgs='/silent /install'; Publisher='Google LLC' },
    [pscustomobject]@{ Name='Mozilla Firefox'; Category='01. Web Browsers'; Id='Mozilla.Firefox'; ChocoId='firefox'; DirectUrl='https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US'; DirectArgs='/S'; Publisher='Mozilla Corporation' },
    [pscustomobject]@{ Name='Microsoft Edge'; Category='01. Web Browsers'; Id='Microsoft.Edge'; ChocoId='microsoft-edge'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Brave Browser'; Category='01. Web Browsers'; Id='Brave.Brave'; ChocoId='brave'; DirectUrl='https://laptop-updates.brave.com/latest/winx64'; DirectArgs='/silent'; Publisher='Brave Software' },
    [pscustomobject]@{ Name='Opera'; Category='01. Web Browsers'; Id='Opera.Opera'; ChocoId='opera'; DirectUrl=''; DirectArgs=''; Publisher='Opera Software' },
    [pscustomobject]@{ Name='Opera GX'; Category='01. Web Browsers'; Id='Opera.OperaGX'; ChocoId='opera-gx'; DirectUrl=''; DirectArgs=''; Publisher='Opera Software' },
    [pscustomobject]@{ Name='Vivaldi'; Category='01. Web Browsers'; Id='Vivaldi.Vivaldi'; ChocoId='vivaldi'; DirectUrl=''; DirectArgs=''; Publisher='Vivaldi Technologies' },
    [pscustomobject]@{ Name='Tor Browser'; Category='01. Web Browsers'; Id='TorProject.TorBrowser'; ChocoId='tor-browser'; DirectUrl=''; DirectArgs=''; Publisher='The Tor Project' },
    [pscustomobject]@{ Name='LibreWolf'; Category='01. Web Browsers'; Id='LibreWolf.LibreWolf'; ChocoId='librewolf'; DirectUrl=''; DirectArgs=''; Publisher='LibreWolf' },
    [pscustomobject]@{ Name='Waterfox'; Category='01. Web Browsers'; Id='Waterfox.Waterfox'; ChocoId='waterfox'; DirectUrl=''; DirectArgs=''; Publisher='Waterfox' },
    [pscustomobject]@{ Name='Pale Moon'; Category='01. Web Browsers'; Id='MoonchildProductions.PaleMoon'; ChocoId='palemoon'; DirectUrl=''; DirectArgs=''; Publisher='Moonchild Productions' },
    [pscustomobject]@{ Name='Chromium'; Category='01. Web Browsers'; Id='Chromium.Chromium'; ChocoId='chromium'; DirectUrl=''; DirectArgs=''; Publisher='The Chromium Project' },
    [pscustomobject]@{ Name='Maxthon Browser'; Category='01. Web Browsers'; Id='Maxthon.Maxthon'; ChocoId='maxthon'; DirectUrl=''; DirectArgs=''; Publisher='Maxthon' },
    [pscustomobject]@{ Name='Falkon'; Category='01. Web Browsers'; Id='KDE.Falkon'; ChocoId='falkon'; DirectUrl=''; DirectArgs=''; Publisher='KDE Project' },
    [pscustomobject]@{ Name='Avast Secure Browser'; Category='01. Web Browsers'; Id='Avast.SecureBrowser'; ChocoId='avast-secure-browser'; DirectUrl=''; DirectArgs=''; Publisher='Avast Software' },
    [pscustomobject]@{ Name='Sidekick Browser'; Category='01. Web Browsers'; Id='PushApp.Sidekick'; ChocoId='sidekick'; DirectUrl=''; DirectArgs=''; Publisher='PushApp Inc' },

    # 02. Media Players & Audio (18 Apps)
    [pscustomobject]@{ Name='VLC Media Player'; Category='02. Media & Audio'; Id='VideoLAN.VLC'; ChocoId='vlc'; DirectUrl=''; DirectArgs=''; Publisher='VideoLAN' },
    [pscustomobject]@{ Name='PotPlayer'; Category='02. Media & Audio'; Id='DAUM.PotPlayer'; ChocoId='potplayer'; DirectUrl=''; DirectArgs=''; Publisher='Kakao' },
    [pscustomobject]@{ Name='K-Lite Codec Pack Mega'; Category='02. Media & Audio'; Id='CodecGuide.K-LiteCodecPack.Mega'; ChocoId='k-litecodecpackmega'; DirectUrl=''; DirectArgs=''; Publisher='Codec Guide' },
    [pscustomobject]@{ Name='K-Lite Codec Pack Full'; Category='02. Media & Audio'; Id='CodecGuide.K-LiteCodecPack.Full'; ChocoId='k-litecodecpackfull'; DirectUrl=''; DirectArgs=''; Publisher='Codec Guide' },
    [pscustomobject]@{ Name='Spotify'; Category='02. Media & Audio'; Id='Spotify.Spotify'; ChocoId='spotify'; DirectUrl=''; DirectArgs=''; Publisher='Spotify' },
    [pscustomobject]@{ Name='Audacity'; Category='02. Media & Audio'; Id='Audacity.Audacity'; ChocoId='audacity'; DirectUrl=''; DirectArgs=''; Publisher='Muse Group' },
    [pscustomobject]@{ Name='MPC-HC'; Category='02. Media & Audio'; Id='clsid2.mpc-hc'; ChocoId='mpc-hc'; DirectUrl=''; DirectArgs=''; Publisher='clsid2' },
    [pscustomobject]@{ Name='AIMP'; Category='02. Media & Audio'; Id='AIMP.AIMP'; ChocoId='aimp'; DirectUrl=''; DirectArgs=''; Publisher='Artem Izmaylov' },
    [pscustomobject]@{ Name='Foobar2000'; Category='02. Media & Audio'; Id='PeterPawlowski.foobar2000'; ChocoId='foobar2000'; DirectUrl=''; DirectArgs=''; Publisher='Peter Pawlowski' },
    [pscustomobject]@{ Name='Winamp'; Category='02. Media & Audio'; Id='Winamp.Winamp'; ChocoId='winamp'; DirectUrl=''; DirectArgs=''; Publisher='Winamp' },
    [pscustomobject]@{ Name='MusicBee'; Category='02. Media & Audio'; Id='StevenMayall.MusicBee'; ChocoId='musicbee'; DirectUrl=''; DirectArgs=''; Publisher='Steven Mayall' },
    [pscustomobject]@{ Name='Clementine'; Category='02. Media & Audio'; Id='Clementine.Clementine'; ChocoId='clementine'; DirectUrl=''; DirectArgs=''; Publisher='Clementine Team' },
    [pscustomobject]@{ Name='MusicBrainz Picard'; Category='02. Media & Audio'; Id='MetaBrainz.Picard'; ChocoId='picard'; DirectUrl=''; DirectArgs=''; Publisher='MetaBrainz Foundation' },
    [pscustomobject]@{ Name='Kodi'; Category='02. Media & Audio'; Id='XBMCFoundation.Kodi'; ChocoId='kodi'; DirectUrl=''; DirectArgs=''; Publisher='Kodi Foundation' },
    [pscustomobject]@{ Name='MediaMonkey'; Category='02. Media & Audio'; Id='VentisMedia.MediaMonkey'; ChocoId='mediamonkey'; DirectUrl=''; DirectArgs=''; Publisher='Ventis Media' },
    [pscustomobject]@{ Name='iTunes'; Category='02. Media & Audio'; Id='Apple.iTunes'; ChocoId='itunes'; DirectUrl=''; DirectArgs=''; Publisher='Apple Inc.' },
    [pscustomobject]@{ Name='SMPlayer'; Category='02. Media & Audio'; Id='RicardoVillalba.SMPlayer'; ChocoId='smplayer'; DirectUrl=''; DirectArgs=''; Publisher='Ricardo Villalba' },
    [pscustomobject]@{ Name='mpv Player'; Category='02. Media & Audio'; Id='mpv.mpv'; ChocoId='mpv'; DirectUrl=''; DirectArgs=''; Publisher='mpv team' },

    # 03. Video & Media Editing (15 Apps)
    [pscustomobject]@{ Name='OBS Studio'; Category='03. Media Creation'; Id='OBSProject.OBSStudio'; ChocoId='obs-studio'; DirectUrl=''; DirectArgs=''; Publisher='OBS Project' },
    [pscustomobject]@{ Name='HandBrake'; Category='03. Media Creation'; Id='HandBrake.HandBrake'; ChocoId='handbrake'; DirectUrl=''; DirectArgs=''; Publisher='HandBrake Team' },
    [pscustomobject]@{ Name='Shotcut'; Category='03. Media Creation'; Id='Meltytech.Shotcut'; ChocoId='shotcut'; DirectUrl=''; DirectArgs=''; Publisher='Meltytech' },
    [pscustomobject]@{ Name='CapCut'; Category='03. Media Creation'; Id='ByteDance.CapCut'; ChocoId='capcut'; DirectUrl=''; DirectArgs=''; Publisher='ByteDance' },
    [pscustomobject]@{ Name='DaVinci Resolve'; Category='03. Media Creation'; Id='BlackmagicDesign.DaVinciResolve'; ChocoId='davinci-resolve'; DirectUrl=''; DirectArgs=''; Publisher='Blackmagic Design' },
    [pscustomobject]@{ Name='Kdenlive'; Category='03. Media Creation'; Id='KDE.Kdenlive'; ChocoId='kdenlive'; DirectUrl=''; DirectArgs=''; Publisher='KDE Community' },
    [pscustomobject]@{ Name='Avidemux'; Category='03. Media Creation'; Id='Avidemux.Avidemux'; ChocoId='avidemux'; DirectUrl=''; DirectArgs=''; Publisher='Mean' },
    [pscustomobject]@{ Name='MakeMKV'; Category='03. Media Creation'; Id='GuinpinSoft.MakeMKV'; ChocoId='makemkv'; DirectUrl=''; DirectArgs=''; Publisher='GuinpinSoft' },
    [pscustomobject]@{ Name='MKVToolNix'; Category='03. Media Creation'; Id='MoritzBunkus.MKVToolNix'; ChocoId='mkvtoolnix'; DirectUrl=''; DirectArgs=''; Publisher='Moritz Bunkus' },
    [pscustomobject]@{ Name='LosslessCut'; Category='03. Media Creation'; Id='mifi.LosslessCut'; ChocoId='lossless-cut'; DirectUrl=''; DirectArgs=''; Publisher='mifi' },
    [pscustomobject]@{ Name='Streamlink'; Category='03. Media Creation'; Id='Streamlink.Streamlink'; ChocoId='streamlink'; DirectUrl=''; DirectArgs=''; Publisher='Streamlink Team' },
    [pscustomobject]@{ Name='VirtualDub2'; Category='03. Media Creation'; Id='VirtualDub2.VirtualDub2'; ChocoId='virtualdub2'; DirectUrl=''; DirectArgs=''; Publisher='VirtualDub2 Team' },
    [pscustomobject]@{ Name='Natron'; Category='03. Media Creation'; Id='Natron.Natron'; ChocoId='natron'; DirectUrl=''; DirectArgs=''; Publisher='Natron VFX' },
    [pscustomobject]@{ Name='StaxRip'; Category='03. Media Creation'; Id='StaxRip.StaxRip'; ChocoId='staxrip'; DirectUrl=''; DirectArgs=''; Publisher='StaxRip Team' },
    [pscustomobject]@{ Name='OpenShot Video Editor'; Category='03. Media Creation'; Id='OpenShot.OpenShot'; ChocoId='openshot'; DirectUrl=''; DirectArgs=''; Publisher='OpenShot Studios' },

    # 04. Archiving & Compression (10 Apps)
    [pscustomobject]@{ Name='7-Zip'; Category='04. Compression'; Id='7zip.7zip'; ChocoId='7zip'; DirectUrl=''; DirectArgs=''; Publisher='Igor Pavlov' },
    [pscustomobject]@{ Name='WinRAR'; Category='04. Compression'; Id='RARLab.WinRAR'; ChocoId='winrar'; DirectUrl=''; DirectArgs=''; Publisher='win.rar GmbH' },
    [pscustomobject]@{ Name='PeaZip'; Category='04. Compression'; Id='Giorgiotani.PeaZip'; ChocoId='peazip'; DirectUrl=''; DirectArgs=''; Publisher='Giorgio Tani' },
    [pscustomobject]@{ Name='NanaZip'; Category='04. Compression'; Id='M2Team.NanaZip'; ChocoId='nanazip'; DirectUrl=''; DirectArgs=''; Publisher='M2Team' },
    [pscustomobject]@{ Name='Bandizip'; Category='04. Compression'; Id='Bandisoft.Bandizip'; ChocoId='bandizip'; DirectUrl=''; DirectArgs=''; Publisher='Bandisoft' },
    [pscustomobject]@{ Name='WinZip'; Category='04. Compression'; Id='Corel.WinZip'; ChocoId='winzip'; DirectUrl=''; DirectArgs=''; Publisher='Corel Corporation' },
    [pscustomobject]@{ Name='IZArc'; Category='04. Compression'; Id='IvanZupan.IZArc'; ChocoId='izarc'; DirectUrl=''; DirectArgs=''; Publisher='Ivan Zupan' },
    [pscustomobject]@{ Name='Bzip2'; Category='04. Compression'; Id='Bzip2.Bzip2'; ChocoId='bzip2'; DirectUrl=''; DirectArgs=''; Publisher='Julian Seward' },
    [pscustomobject]@{ Name='Zstandard'; Category='04. Compression'; Id='Facebook.Zstandard'; ChocoId='zstandard'; DirectUrl=''; DirectArgs=''; Publisher='Meta Platforms' },
    [pscustomobject]@{ Name='Tar'; Category='04. Compression'; Id='GNU.Tar'; ChocoId='tar'; DirectUrl=''; DirectArgs=''; Publisher='GNU Project' },

    # 05. System Utilities & Diagnostics (25 Apps)
    [pscustomobject]@{ Name='Microsoft PowerToys'; Category='05. System Utilities'; Id='Microsoft.PowerToys'; ChocoId='powertoys'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Everything Search'; Category='05. System Utilities'; Id='voidtools.Everything'; ChocoId='everything'; DirectUrl=''; DirectArgs=''; Publisher='voidtools' },
    [pscustomobject]@{ Name='Rufus'; Category='05. System Utilities'; Id='Rufus.Rufus'; ChocoId='rufus'; DirectUrl=''; DirectArgs=''; Publisher='Pete Batard' },
    [pscustomobject]@{ Name='AnyDesk'; Category='05. System Utilities'; Id='AnyDesk.AnyDesk'; ChocoId='anydesk'; DirectUrl='https://download.anydesk.com/AnyDesk.exe'; DirectArgs='--install "C:\Program Files (x86)\AnyDesk" --start-with-win --silent'; Publisher='AnyDesk Software GmbH' },
    [pscustomobject]@{ Name='TeamViewer'; Category='05. System Utilities'; Id='TeamViewer.TeamViewer'; ChocoId='teamviewer'; DirectUrl=''; DirectArgs=''; Publisher='TeamViewer' },
    [pscustomobject]@{ Name='CPU-Z'; Category='05. System Utilities'; Id='CPUID.CPU-Z'; ChocoId='cpu-z'; DirectUrl=''; DirectArgs=''; Publisher='CPUID' },
    [pscustomobject]@{ Name='GPU-Z'; Category='05. System Utilities'; Id='TechPowerUp.GPU-Z'; ChocoId='gpu-z'; DirectUrl=''; DirectArgs=''; Publisher='TechPowerUp' },
    [pscustomobject]@{ Name='CrystalDiskInfo'; Category='05. System Utilities'; Id='CrystalDewWorld.CrystalDiskInfo'; ChocoId='crystaldiskinfo'; DirectUrl=''; DirectArgs=''; Publisher='Crystal Dew World' },
    [pscustomobject]@{ Name='CrystalDiskMark'; Category='05. System Utilities'; Id='CrystalDewWorld.CrystalDiskMark'; ChocoId='crystaldiskmark'; DirectUrl=''; DirectArgs=''; Publisher='Crystal Dew World' },
    [pscustomobject]@{ Name='Revo Uninstaller'; Category='05. System Utilities'; Id='VSRevoGroup.RevoUninstaller'; ChocoId='revo-uninstaller'; DirectUrl=''; DirectArgs=''; Publisher='VS Revo Group' },
    [pscustomobject]@{ Name='System Informer'; Category='05. System Utilities'; Id='SystemInformer.SystemInformer'; ChocoId='system-informer'; DirectUrl=''; DirectArgs=''; Publisher='System Informer' },
    [pscustomobject]@{ Name='Sysinternals Suite'; Category='05. System Utilities'; Id='Microsoft.Sysinternals.SysinternalsSuite'; ChocoId='sysinternals'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Speccy'; Category='05. System Utilities'; Id='Piriform.Speccy'; ChocoId='speccy'; DirectUrl=''; DirectArgs=''; Publisher='Piriform' },
    [pscustomobject]@{ Name='HWMonitor'; Category='05. System Utilities'; Id='CPUID.HWMonitor'; ChocoId='hwmonitor'; DirectUrl=''; DirectArgs=''; Publisher='CPUID' },
    [pscustomobject]@{ Name='HWiNFO'; Category='05. System Utilities'; Id='REALiX.HWiNFO'; ChocoId='hwinfo'; DirectUrl=''; DirectArgs=''; Publisher='REALiX' },
    [pscustomobject]@{ Name='Core Temp'; Category='05. System Utilities'; Id='ALCPU.CoreTemp'; ChocoId='coretemp'; DirectUrl=''; DirectArgs=''; Publisher='Arthur Liberman' },
    [pscustomobject]@{ Name='TreeSize Free'; Category='05. System Utilities'; Id='JAMSoftware.TreeSize.Free'; ChocoId='treesizefree'; DirectUrl=''; DirectArgs=''; Publisher='JAM Software' },
    [pscustomobject]@{ Name='WizTree'; Category='05. System Utilities'; Id='AntibodySoftware.WizTree'; ChocoId='wiztree'; DirectUrl=''; DirectArgs=''; Publisher='Antibody Software' },
    [pscustomobject]@{ Name='BleachBit'; Category='05. System Utilities'; Id='BleachBit.BleachBit'; ChocoId='bleachbit'; DirectUrl=''; DirectArgs=''; Publisher='Andrew Ziem' },
    [pscustomobject]@{ Name='AutoHotkey'; Category='05. System Utilities'; Id='AutoHotkey.AutoHotkey'; ChocoId='autohotkey'; DirectUrl=''; DirectArgs=''; Publisher='AutoHotkey Foundation' },
    [pscustomobject]@{ Name='Ventoy'; Category='05. System Utilities'; Id='ventoy.ventoy'; ChocoId='ventoy'; DirectUrl=''; DirectArgs=''; Publisher='longPanda' },
    [pscustomobject]@{ Name='Windows Terminal'; Category='05. System Utilities'; Id='Microsoft.WindowsTerminal'; ChocoId='microsoft-windows-terminal'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='PowerShell 7'; Category='05. System Utilities'; Id='Microsoft.PowerShell'; ChocoId='powershell-core'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='WinDirStat'; Category='05. System Utilities'; Id='WinDirStat.WinDirStat'; ChocoId='windirstat'; DirectUrl=''; DirectArgs=''; Publisher='WinDirStat Team' },
    [pscustomobject]@{ Name='Bulk Crap Uninstaller'; Category='05. System Utilities'; Id='Klocman.BulkCrapUninstaller'; ChocoId='bcuninstaller'; DirectUrl=''; DirectArgs=''; Publisher='Marcin Klocman' },

    # 06. Development & Coding (22 Apps)
    [pscustomobject]@{ Name='Visual Studio Code'; Category='06. Development'; Id='Microsoft.VisualStudioCode'; ChocoId='vscode'; DirectUrl='https://update.code.visualstudio.com/latest/win32-x64-user/stable'; DirectArgs='/verysilent /norestart'; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Notepad++'; Category='06. Development'; Id='Notepad++.Notepad++'; ChocoId='notepadplusplus'; DirectUrl=''; DirectArgs=''; Publisher='Don HO' },
    [pscustomobject]@{ Name='Git'; Category='06. Development'; Id='Git.Git'; ChocoId='git'; DirectUrl=''; DirectArgs=''; Publisher='The Git Development Team' },
    [pscustomobject]@{ Name='Python 3.12'; Category='06. Development'; Id='Python.Python.3.12'; ChocoId='python'; DirectUrl=''; DirectArgs=''; Publisher='Python Software Foundation' },
    [pscustomobject]@{ Name='Node.js LTS'; Category='06. Development'; Id='OpenJS.NodeJS.LTS'; ChocoId='nodejs-lts'; DirectUrl=''; DirectArgs=''; Publisher='OpenJS Foundation' },
    [pscustomobject]@{ Name='IntelliJ IDEA Community'; Category='06. Development'; Id='JetBrains.IntelliJIDEA.Community'; ChocoId='intellijidea-community'; DirectUrl=''; DirectArgs=''; Publisher='JetBrains' },
    [pscustomobject]@{ Name='PyCharm Community'; Category='06. Development'; Id='JetBrains.PyCharm.Community'; ChocoId='pycharm-community'; DirectUrl=''; DirectArgs=''; Publisher='JetBrains' },
    [pscustomobject]@{ Name='CLion'; Category='06. Development'; Id='JetBrains.CLion'; ChocoId='clion'; DirectUrl=''; DirectArgs=''; Publisher='JetBrains' },
    [pscustomobject]@{ Name='WebStorm'; Category='06. Development'; Id='JetBrains.WebStorm'; ChocoId='webstorm'; DirectUrl=''; DirectArgs=''; Publisher='JetBrains' },
    [pscustomobject]@{ Name='Eclipse IDE'; Category='06. Development'; Id='EclipseFoundation.EclipseIDE'; ChocoId='eclipse'; DirectUrl=''; DirectArgs=''; Publisher='Eclipse Foundation' },
    [pscustomobject]@{ Name='Visual Studio 2022 Community'; Category='06. Development'; Id='Microsoft.VisualStudio.2022.Community'; ChocoId='visualstudio2022community'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Sublime Text 4'; Category='06. Development'; Id='SublimeHQ.SublimeText.4'; ChocoId='sublimetext4'; DirectUrl=''; DirectArgs=''; Publisher='Sublime HQ' },
    [pscustomobject]@{ Name='Neovim'; Category='06. Development'; Id='Neovim.Neovim'; ChocoId='neovim'; DirectUrl=''; DirectArgs=''; Publisher='Neovim Team' },
    [pscustomobject]@{ Name='Vim'; Category='06. Development'; Id='vim.vim'; ChocoId='vim'; DirectUrl=''; DirectArgs=''; Publisher='Vim Development Team' },
    [pscustomobject]@{ Name='Docker Desktop'; Category='06. Development'; Id='Docker.DockerDesktop'; ChocoId='docker-desktop'; DirectUrl=''; DirectArgs=''; Publisher='Docker Inc.' },
    [pscustomobject]@{ Name='Go Programming Language'; Category='06. Development'; Id='Golang.Go'; ChocoId='golang'; DirectUrl=''; DirectArgs=''; Publisher='Google LLC' },
    [pscustomobject]@{ Name='Rust Compiler'; Category='06. Development'; Id='Rustlang.Rustup'; ChocoId='rustup'; DirectUrl=''; DirectArgs=''; Publisher='Rust Team' },
    [pscustomobject]@{ Name='Ruby'; Category='06. Development'; Id='RubyInstallerTeam.RubyWithDevKit'; ChocoId='ruby'; DirectUrl=''; DirectArgs=''; Publisher='RubyInstaller Team' },
    [pscustomobject]@{ Name='PHP'; Category='06. Development'; Id='PHP.PHP'; ChocoId='php'; DirectUrl=''; DirectArgs=''; Publisher='PHP Group' },
    [pscustomobject]@{ Name='CMake'; Category='06. Development'; Id='Kitware.CMake'; ChocoId='cmake'; DirectUrl=''; DirectArgs=''; Publisher='Kitware' },
    [pscustomobject]@{ Name='Postman'; Category='06. Development'; Id='Postman.Postman'; ChocoId='postman'; DirectUrl=''; DirectArgs=''; Publisher='Postman Inc.' },
    [pscustomobject]@{ Name='Insomnia API Client'; Category='06. Development'; Id='Insomnia.Insomnia'; ChocoId='insomnia-rest-client'; DirectUrl=''; DirectArgs=''; Publisher='Kong Inc.' },

    # 07. Communication & Social (15 Apps)
    [pscustomobject]@{ Name='Discord'; Category='07. Communication'; Id='Discord.Discord'; ChocoId='discord'; DirectUrl=''; DirectArgs=''; Publisher='Discord Inc.' },
    [pscustomobject]@{ Name='Telegram Desktop'; Category='07. Communication'; Id='Telegram.TelegramDesktop'; ChocoId='telegram'; DirectUrl=''; DirectArgs=''; Publisher='Telegram FZ-LLC' },
    [pscustomobject]@{ Name='WhatsApp'; Category='07. Communication'; Id='9NKSQGP7F2NH'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='Meta Platforms' },
    [pscustomobject]@{ Name='Zoom'; Category='07. Communication'; Id='Zoom.Zoom'; ChocoId='zoom'; DirectUrl=''; DirectArgs=''; Publisher='Zoom Video Communications' },
    [pscustomobject]@{ Name='Signal'; Category='07. Communication'; Id='OpenWhisperSystems.Signal'; ChocoId='signal'; DirectUrl=''; DirectArgs=''; Publisher='Signal Foundation' },
    [pscustomobject]@{ Name='Skype'; Category='07. Communication'; Id='Microsoft.Skype'; ChocoId='skype'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Slack'; Category='07. Communication'; Id='SlackTechnologies.Slack'; ChocoId='slack'; DirectUrl=''; DirectArgs=''; Publisher='Slack Technologies' },
    [pscustomobject]@{ Name='Microsoft Teams'; Category='07. Communication'; Id='Microsoft.Teams'; ChocoId='microsoft-teams'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Viber'; Category='07. Communication'; Id='Viber.Viber'; ChocoId='viber'; DirectUrl=''; DirectArgs=''; Publisher='Rakuten Viber' },
    [pscustomobject]@{ Name='Element Desktop'; Category='07. Communication'; Id='Element.Element'; ChocoId='element-desktop'; DirectUrl=''; DirectArgs=''; Publisher='Element' },
    [pscustomobject]@{ Name='Thunderbird Email'; Category='07. Communication'; Id='Mozilla.Thunderbird'; ChocoId='thunderbird'; DirectUrl=''; DirectArgs=''; Publisher='Mozilla Foundation' },
    [pscustomobject]@{ Name='HexChat'; Category='07. Communication'; Id='HexChat.HexChat'; ChocoId='hexchat'; DirectUrl=''; DirectArgs=''; Publisher='HexChat' },
    [pscustomobject]@{ Name='Pidgin'; Category='07. Communication'; Id='Pidgin.Pidgin'; ChocoId='pidgin'; DirectUrl=''; DirectArgs=''; Publisher='Pidgin Development Team' },
    [pscustomobject]@{ Name='Session Messenger'; Category='07. Communication'; Id='Oxen.Session'; ChocoId='session'; DirectUrl=''; DirectArgs=''; Publisher='Oxen Foundation' },
    [pscustomobject]@{ Name='Revolt Desktop'; Category='07. Communication'; Id='Revolt.Revolt'; ChocoId='revolt'; DirectUrl=''; DirectArgs=''; Publisher='Revolt Chat' },

    # 08. Gaming & Launchers (12 Apps)
    [pscustomobject]@{ Name='Steam'; Category='08. Gaming'; Id='Valve.Steam'; ChocoId='steam'; DirectUrl=''; DirectArgs=''; Publisher='Valve Corp' },
    [pscustomobject]@{ Name='Epic Games Launcher'; Category='08. Gaming'; Id='EpicGames.EpicGamesLauncher'; ChocoId='epicgameslauncher'; DirectUrl=''; DirectArgs=''; Publisher='Epic Games' },
    [pscustomobject]@{ Name='GOG Galaxy'; Category='08. Gaming'; Id='GOG.Galaxy'; ChocoId='goggalaxy'; DirectUrl=''; DirectArgs=''; Publisher='GOG sp. z o.o.' },
    [pscustomobject]@{ Name='EA App'; Category='08. Gaming'; Id='ElectronicArts.EADesktop'; ChocoId='ea-app'; DirectUrl=''; DirectArgs=''; Publisher='Electronic Arts' },
    [pscustomobject]@{ Name='Ubisoft Connect'; Category='08. Gaming'; Id='Ubisoft.Connect'; ChocoId='ubisoft-connect'; DirectUrl=''; DirectArgs=''; Publisher='Ubisoft' },
    [pscustomobject]@{ Name='Battle.net'; Category='08. Gaming'; Id='Blizzard.BattleNet'; ChocoId='battlenet'; DirectUrl=''; DirectArgs=''; Publisher='Blizzard Entertainment' },
    [pscustomobject]@{ Name='Heroic Games Launcher'; Category='08. Gaming'; Id='HeroicGamesLauncher.HeroicGamesLauncher'; ChocoId='heroic-games-launcher'; DirectUrl=''; DirectArgs=''; Publisher='Heroic Team' },
    [pscustomobject]@{ Name='Playnite'; Category='08. Gaming'; Id='Playnite.Playnite'; ChocoId='playnite'; DirectUrl=''; DirectArgs=''; Publisher='Josef Nemec' },
    [pscustomobject]@{ Name='Prism Launcher'; Category='08. Gaming'; Id='PrismLauncher.PrismLauncher'; ChocoId='prismlauncher'; DirectUrl=''; DirectArgs=''; Publisher='Prism Launcher Team' },
    [pscustomobject]@{ Name='Mod Organizer 2'; Category='08. Gaming'; Id='ModOrganizer2.ModOrganizer2'; ChocoId='modorganizer2'; DirectUrl=''; DirectArgs=''; Publisher='NexusMods Team' },
    [pscustomobject]@{ Name='Roblox'; Category='08. Gaming'; Id='Roblox.Roblox'; ChocoId='roblox'; DirectUrl=''; DirectArgs=''; Publisher='Roblox Corporation' },
    [pscustomobject]@{ Name='Razer Synapse'; Category='08. Gaming'; Id='RazerInc.RazerInstaller.Synapse3'; ChocoId='razer-synapse'; DirectUrl=''; DirectArgs=''; Publisher='Razer Inc.' },

    # 09. Productivity & Office (15 Apps)
    [pscustomobject]@{ Name='LibreOffice'; Category='09. Productivity'; Id='TheDocumentFoundation.LibreOffice'; ChocoId='libreoffice-fresh'; DirectUrl=''; DirectArgs=''; Publisher='The Document Foundation' },
    [pscustomobject]@{ Name='Adobe Acrobat Reader'; Category='09. Productivity'; Id='Adobe.Acrobat.Reader.64-bit'; ChocoId='adobereader'; DirectUrl=''; DirectArgs=''; Publisher='Adobe Inc.' },
    [pscustomobject]@{ Name='Foxit PDF Reader'; Category='09. Productivity'; Id='Foxit.FoxitReader'; ChocoId='foxitreader'; DirectUrl=''; DirectArgs=''; Publisher='Foxit Software' },
    [pscustomobject]@{ Name='Apache OpenOffice'; Category='09. Productivity'; Id='Apache.OpenOffice'; ChocoId='openoffice'; DirectUrl=''; DirectArgs=''; Publisher='Apache Software Foundation' },
    [pscustomobject]@{ Name='WPS Office'; Category='09. Productivity'; Id='Kingsoft.WPSOffice'; ChocoId='wps-office'; DirectUrl=''; DirectArgs=''; Publisher='Kingsoft' },
    [pscustomobject]@{ Name='ONLYOFFICE Desktop'; Category='09. Productivity'; Id='ONLYOFFICE.DesktopEditors'; ChocoId='onlyoffice'; DirectUrl=''; DirectArgs=''; Publisher='Ascensio System SIA' },
    [pscustomobject]@{ Name='SumatraPDF'; Category='09. Productivity'; Id='SumatraPDF.SumatraPDF'; ChocoId='sumatrapdf'; DirectUrl=''; DirectArgs=''; Publisher='Krzysztof Kowalczyk' },
    [pscustomobject]@{ Name='PDF24 Creator'; Category='09. Productivity'; Id='geeksoftwareGmbH.PDF24Creator'; ChocoId='pdf24'; DirectUrl=''; DirectArgs=''; Publisher='geek software GmbH' },
    [pscustomobject]@{ Name='Obsidian'; Category='09. Productivity'; Id='Obsidian.Obsidian'; ChocoId='obsidian'; DirectUrl=''; DirectArgs=''; Publisher='Dynalist Inc.' },
    [pscustomobject]@{ Name='Notion'; Category='09. Productivity'; Id='Notion.Notion'; ChocoId='notion'; DirectUrl=''; DirectArgs=''; Publisher='Notion Labs' },
    [pscustomobject]@{ Name='Logseq'; Category='09. Productivity'; Id='Logseq.Logseq'; ChocoId='logseq'; DirectUrl=''; DirectArgs=''; Publisher='Logseq' },
    [pscustomobject]@{ Name='Typora'; Category='09. Productivity'; Id='Typora.Typora'; ChocoId='typora'; DirectUrl=''; DirectArgs=''; Publisher='Typora' },
    [pscustomobject]@{ Name='Joplin'; Category='09. Productivity'; Id='Joplin.Joplin'; ChocoId='joplin'; DirectUrl=''; DirectArgs=''; Publisher='Laurent Cozic' },
    [pscustomobject]@{ Name='Evernote'; Category='09. Productivity'; Id='Evernote.Evernote'; ChocoId='evernote'; DirectUrl=''; DirectArgs=''; Publisher='Evernote Corporation' },
    [pscustomobject]@{ Name='Microsoft OneNote'; Category='09. Productivity'; Id='Microsoft.Office.OneNote'; ChocoId='onenote'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },

    # 10. Design & Graphics (15 Apps)
    [pscustomobject]@{ Name='Blender 3D'; Category='10. Design & Graphics'; Id='BlenderFoundation.Blender'; ChocoId='blender'; DirectUrl=''; DirectArgs=''; Publisher='Blender Foundation' },
    [pscustomobject]@{ Name='GIMP Image Editor'; Category='10. Design & Graphics'; Id='GIMP.GIMP'; ChocoId='gimp'; DirectUrl=''; DirectArgs=''; Publisher='The GIMP Team' },
    [pscustomobject]@{ Name='Inkscape'; Category='10. Design & Graphics'; Id='Inkscape.Inkscape'; ChocoId='inkscape'; DirectUrl=''; DirectArgs=''; Publisher='Inkscape Community' },
    [pscustomobject]@{ Name='Krita'; Category='10. Design & Graphics'; Id='KDE.Krita'; ChocoId='krita'; DirectUrl=''; DirectArgs=''; Publisher='Krita Foundation' },
    [pscustomobject]@{ Name='Paint.NET'; Category='10. Design & Graphics'; Id='dotPDN.PaintDotNet'; ChocoId='paint.net'; DirectUrl=''; DirectArgs=''; Publisher='dotPDN LLC' },
    [pscustomobject]@{ Name='Darktable'; Category='10. Design & Graphics'; Id='darktable.darktable'; ChocoId='darktable'; DirectUrl=''; DirectArgs=''; Publisher='darktable team' },
    [pscustomobject]@{ Name='RawTherapee'; Category='10. Design & Graphics'; Id='RawTherapee.RawTherapee'; ChocoId='rawtherapee'; DirectUrl=''; DirectArgs=''; Publisher='RawTherapee Team' },
    [pscustomobject]@{ Name='ShareX'; Category='10. Design & Graphics'; Id='ShareX.ShareX'; ChocoId='sharex'; DirectUrl=''; DirectArgs=''; Publisher='ShareX Team' },
    [pscustomobject]@{ Name='Flameshot'; Category='10. Design & Graphics'; Id='Flameshot.Flameshot'; ChocoId='flameshot'; DirectUrl=''; DirectArgs=''; Publisher='Flameshot Team' },
    [pscustomobject]@{ Name='Greenshot'; Category='10. Design & Graphics'; Id='Greenshot.Greenshot'; ChocoId='greenshot'; DirectUrl=''; DirectArgs=''; Publisher='Greenshot' },
    [pscustomobject]@{ Name='Figma Desktop'; Category='10. Design & Graphics'; Id='Figma.Figma'; ChocoId='figma'; DirectUrl=''; DirectArgs=''; Publisher='Figma Inc.' },
    [pscustomobject]@{ Name='Canva'; Category='10. Design & Graphics'; Id='Canva.Canva'; ChocoId='canva'; DirectUrl=''; DirectArgs=''; Publisher='Canva Pty Ltd' },
    [pscustomobject]@{ Name='IrfanView'; Category='10. Design & Graphics'; Id='IrfanSkiljan.IrfanView'; ChocoId='irfanview'; DirectUrl=''; DirectArgs=''; Publisher='Irfan Skiljan' },
    [pscustomobject]@{ Name='XnView MP'; Category='10. Design & Graphics'; Id='XnSoft.XnViewMP'; ChocoId='xnviewmp'; DirectUrl=''; DirectArgs=''; Publisher='Pierre-Emmanuel Gougelet' },
    [pscustomobject]@{ Name='FastStone Image Viewer'; Category='10. Design & Graphics'; Id='FastStone.ImageViewer'; ChocoId='faststoneview'; DirectUrl=''; DirectArgs=''; Publisher='FastStone Soft' },

    # 11. Security & Privacy (15 Apps)
    [pscustomobject]@{ Name='Malwarebytes'; Category='11. Security & Privacy'; Id='Malwarebytes.Malwarebytes'; ChocoId='malwarebytes'; DirectUrl=''; DirectArgs=''; Publisher='Malwarebytes' },
    [pscustomobject]@{ Name='Bitwarden Vault'; Category='11. Security & Privacy'; Id='Bitwarden.Bitwarden'; ChocoId='bitwarden'; DirectUrl=''; DirectArgs=''; Publisher='Bitwarden Inc.' },
    [pscustomobject]@{ Name='KeePassXC'; Category='11. Security & Privacy'; Id='KeePassXCTeam.KeePassXC'; ChocoId='keepassxc'; DirectUrl=''; DirectArgs=''; Publisher='KeePassXC Team' },
    [pscustomobject]@{ Name='KeePass'; Category='11. Security & Privacy'; Id='DominikReichl.KeePass'; ChocoId='keepass'; DirectUrl=''; DirectArgs=''; Publisher='Dominik Reichl' },
    [pscustomobject]@{ Name='ProtonVPN'; Category='11. Security & Privacy'; Id='Proton.ProtonVPN'; ChocoId='protonvpn'; DirectUrl=''; DirectArgs=''; Publisher='Proton AG' },
    [pscustomobject]@{ Name='WireGuard'; Category='11. Security & Privacy'; Id='WireGuard.WireGuard'; ChocoId='wireguard'; DirectUrl=''; DirectArgs=''; Publisher='WireGuard Development Team' },
    [pscustomobject]@{ Name='OpenVPN Community'; Category='11. Security & Privacy'; Id='OpenVPNTechnologies.OpenVPN'; ChocoId='openvpn'; DirectUrl=''; DirectArgs=''; Publisher='OpenVPN Inc.' },
    [pscustomobject]@{ Name='NordVPN'; Category='11. Security & Privacy'; Id='NordSecurity.NordVPN'; ChocoId='nordvpn'; DirectUrl=''; DirectArgs=''; Publisher='Nord Security' },
    [pscustomobject]@{ Name='ExpressVPN'; Category='11. Security & Privacy'; Id='ExpressVPN.ExpressVPN'; ChocoId='expressvpn'; DirectUrl=''; DirectArgs=''; Publisher='ExpressVPN' },
    [pscustomobject]@{ Name='Mullvad VPN'; Category='11. Security & Privacy'; Id='MullvadVPN.MullvadVPN'; ChocoId='mullvad-vpn'; DirectUrl=''; DirectArgs=''; Publisher='Mullvad VPN AB' },
    [pscustomobject]@{ Name='GlassWire'; Category='11. Security & Privacy'; Id='GlassWire.GlassWire'; ChocoId='glasswire'; DirectUrl=''; DirectArgs=''; Publisher='GlassWire' },
    [pscustomobject]@{ Name='Wireshark'; Category='11. Security & Privacy'; Id='WiresharkFoundation.Wireshark'; ChocoId='wireshark'; DirectUrl=''; DirectArgs=''; Publisher='Wireshark Foundation' },
    [pscustomobject]@{ Name='VeraCrypt'; Category='11. Security & Privacy'; Id='IDRIX.VeraCrypt'; ChocoId='veracrypt'; DirectUrl=''; DirectArgs=''; Publisher='IDRIX' },
    [pscustomobject]@{ Name='Cryptomator'; Category='11. Security & Privacy'; Id='Skymatic.Cryptomator'; ChocoId='cryptomator'; DirectUrl=''; DirectArgs=''; Publisher='Skymatic GmbH' },
    [pscustomobject]@{ Name='ClamWin Antivirus'; Category='11. Security & Privacy'; Id='ClamWin.ClamWin'; ChocoId='clamwin'; DirectUrl=''; DirectArgs=''; Publisher='ClamWin Pty Ltd' },

    # 12. Cloud Storage & Sync (10 Apps)
    [pscustomobject]@{ Name='Google Drive'; Category='12. Cloud & Storage'; Id='Google.Drive'; ChocoId='googledrive'; DirectUrl=''; DirectArgs=''; Publisher='Google LLC' },
    [pscustomobject]@{ Name='Dropbox'; Category='12. Cloud & Storage'; Id='Dropbox.Dropbox'; ChocoId='dropbox'; DirectUrl=''; DirectArgs=''; Publisher='Dropbox' },
    [pscustomobject]@{ Name='Microsoft OneDrive'; Category='12. Cloud & Storage'; Id='Microsoft.OneDrive'; ChocoId='onedrive'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Nextcloud Desktop'; Category='12. Cloud & Storage'; Id='Nextcloud.NextcloudDesktop'; ChocoId='nextcloud-client'; DirectUrl=''; DirectArgs=''; Publisher='Nextcloud GmbH' },
    [pscustomobject]@{ Name='MEGAsync'; Category='12. Cloud & Storage'; Id='Mega.MEGAsync'; ChocoId='megasync'; DirectUrl=''; DirectArgs=''; Publisher='Mega Limited' },
    [pscustomobject]@{ Name='Syncthing'; Category='12. Cloud & Storage'; Id='Syncthing.Syncthing'; ChocoId='syncthing'; DirectUrl=''; DirectArgs=''; Publisher='The Syncthing Project' },
    [pscustomobject]@{ Name='ownCloud Desktop'; Category='12. Cloud & Storage'; Id='ownCloud.ownCloudDesktop'; ChocoId='owncloud-client'; DirectUrl=''; DirectArgs=''; Publisher='ownCloud GmbH' },
    [pscustomobject]@{ Name='Seafile Client'; Category='12. Cloud & Storage'; Id='Seafile.SeafileClient'; ChocoId='seafile-client'; DirectUrl=''; DirectArgs=''; Publisher='Seafile Ltd.' },
    [pscustomobject]@{ Name='pCloud Drive'; Category='12. Cloud & Storage'; Id='pCloudAG.pCloudDrive'; ChocoId='pcloud'; DirectUrl=''; DirectArgs=''; Publisher='pCloud AG' },
    [pscustomobject]@{ Name='Rclone'; Category='12. Cloud & Storage'; Id='Rclone.Rclone'; ChocoId='rclone'; DirectUrl=''; DirectArgs=''; Publisher='Nick Craig-Wood' },

    # 13. Runtimes & Libraries (10 Apps)
    [pscustomobject]@{ Name='.NET Desktop Runtime 8'; Category='13. Runtimes & Libraries'; Id='Microsoft.dotnet.desktop-runtime.8'; ChocoId='dotnet-8.0-desktopruntime'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='.NET Desktop Runtime 7'; Category='13. Runtimes & Libraries'; Id='Microsoft.dotnet.desktop-runtime.7'; ChocoId='dotnet-7.0-desktopruntime'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='.NET Desktop Runtime 6'; Category='13. Runtimes & Libraries'; Id='Microsoft.dotnet.desktop-runtime.6'; ChocoId='dotnet-6.0-desktopruntime'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='VCRedist 2015-2022 x64'; Category='13. Runtimes & Libraries'; Id='Microsoft.VCRedist.2015+.x64'; ChocoId='vcredist140'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='VCRedist 2015-2022 x86'; Category='13. Runtimes & Libraries'; Id='Microsoft.VCRedist.2015+.x86'; ChocoId='vcredist-all'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='DirectX End-User Runtime'; Category='13. Runtimes & Libraries'; Id='Microsoft.DirectX'; ChocoId='directx'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='Java Runtime Environment 8'; Category='13. Runtimes & Libraries'; Id='Oracle.JavaRuntimeEnvironment'; ChocoId='jre8'; DirectUrl=''; DirectArgs=''; Publisher='Oracle Corporation' },
    [pscustomobject]@{ Name='OpenJDK 21'; Category='13. Runtimes & Libraries'; Id='EclipseAdoptium.Temurin.21.JDK'; ChocoId='temurin21'; DirectUrl=''; DirectArgs=''; Publisher='Eclipse Adoptium' },
    [pscustomobject]@{ Name='Microsoft XNA Framework 4.0'; Category='13. Runtimes & Libraries'; Id='Microsoft.XNAFrameworkRedist'; ChocoId='xna'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },
    [pscustomobject]@{ Name='WebView2 Runtime'; Category='13. Runtimes & Libraries'; Id='Microsoft.EdgeWebView2Runtime'; ChocoId='webview2-runtime'; DirectUrl=''; DirectArgs=''; Publisher='Microsoft Corporation' },

    # 14. Virtualization & Emulation (12 Apps)
    [pscustomobject]@{ Name='Oracle VirtualBox'; Category='14. Virtualization'; Id='Oracle.VirtualBox'; ChocoId='virtualbox'; DirectUrl=''; DirectArgs=''; Publisher='Oracle Corporation' },
    [pscustomobject]@{ Name='VMware Workstation Player'; Category='14. Virtualization'; Id='VMware.WorkstationPlayer'; ChocoId='vmware-workstation-player'; DirectUrl=''; DirectArgs=''; Publisher='VMware' },
    [pscustomobject]@{ Name='QEMU'; Category='14. Virtualization'; Id='SoftwareFreedomConservancy.QEMU'; ChocoId='qemu'; DirectUrl=''; DirectArgs=''; Publisher='QEMU Project' },
    [pscustomobject]@{ Name='BlueStacks 5'; Category='14. Virtualization'; Id='BlueStack.BlueStacks'; ChocoId='bluestacks'; DirectUrl=''; DirectArgs=''; Publisher='BlueStack Systems' },
    [pscustomobject]@{ Name='LDPlayer'; Category='14. Virtualization'; Id='XuanZhi.LDPlayer'; ChocoId='ldplayer'; DirectUrl=''; DirectArgs=''; Publisher='XuanZhi International' },
    [pscustomobject]@{ Name='NoxPlayer'; Category='14. Virtualization'; Id='Duodian.NoxPlayer'; ChocoId='noxplayer'; DirectUrl=''; DirectArgs=''; Publisher='Duodian Network' },
    [pscustomobject]@{ Name='PCSX2 PlayStation 2 Emulator'; Category='14. Virtualization'; Id='PCSX2Team.PCSX2'; ChocoId='pcsx2'; DirectUrl=''; DirectArgs=''; Publisher='PCSX2 Team' },
    [pscustomobject]@{ Name='RPCS3 PS3 Emulator'; Category='14. Virtualization'; Id='RPCS3.RPCS3'; ChocoId='rpcs3'; DirectUrl=''; DirectArgs=''; Publisher='RPCS3 Team' },
    [pscustomobject]@{ Name='Dolphin Emulator'; Category='14. Virtualization'; Id='DolphinEmulator.Dolphin'; ChocoId='dolphin'; DirectUrl=''; DirectArgs=''; Publisher='Dolphin Team' },
    [pscustomobject]@{ Name='PPSSPP PSP Emulator'; Category='14. Virtualization'; Id='PPSSPPTeam.PPSSPP'; ChocoId='ppsspp'; DirectUrl=''; DirectArgs=''; Publisher='Henrik Rydgard' },
    [pscustomobject]@{ Name='RetroArch'; Category='14. Virtualization'; Id='Libretro.RetroArch'; ChocoId='retroarch'; DirectUrl=''; DirectArgs=''; Publisher='Libretro' },
    [pscustomobject]@{ Name='DOSBox'; Category='14. Virtualization'; Id='DOSBox.DOSBox'; ChocoId='dosbox'; DirectUrl=''; DirectArgs=''; Publisher='DOSBox Team' },

    # 15. Network & Database Tools (15 Apps)
    [pscustomobject]@{ Name='DBeaver Community'; Category='15. Network & Database'; Id='DBeaver.DBeaver.Community'; ChocoId='dbeaver'; DirectUrl=''; DirectArgs=''; Publisher='DBeaver Corp' },
    [pscustomobject]@{ Name='MongoDB Compass'; Category='15. Network & Database'; Id='MongoDB.Compass.Full'; ChocoId='mongodb-compass'; DirectUrl=''; DirectArgs=''; Publisher='MongoDB Inc.' },
    [pscustomobject]@{ Name='pgAdmin 4'; Category='15. Network & Database'; Id='PostgreSQL.pgAdmin4'; ChocoId='pgadmin4'; DirectUrl=''; DirectArgs=''; Publisher='pgAdmin Team' },
    [pscustomobject]@{ Name='MySQL Workbench'; Category='15. Network & Database'; Id='Oracle.MySQLWorkbench'; ChocoId='mysql.workbench'; DirectUrl=''; DirectArgs=''; Publisher='Oracle Corporation' },
    [pscustomobject]@{ Name='HeidiSQL'; Category='15. Network & Database'; Id='AnsgarBecker.HeidiSQL'; ChocoId='heidisql'; DirectUrl=''; DirectArgs=''; Publisher='Ansgar Becker' },
    [pscustomobject]@{ Name='DB Browser for SQLite'; Category='15. Network & Database'; Id='DBBrowserForSQLite.DBBrowserForSQLite'; ChocoId='sqlitebrowser'; DirectUrl=''; DirectArgs=''; Publisher='DB Browser Team' },
    [pscustomobject]@{ Name='PuTTY'; Category='15. Network & Database'; Id='PuTTY.PuTTY'; ChocoId='putty'; DirectUrl=''; DirectArgs=''; Publisher='Simon Tatham' },
    [pscustomobject]@{ Name='WinSCP'; Category='15. Network & Database'; Id='WinSCP.WinSCP'; ChocoId='winscp'; DirectUrl=''; DirectArgs=''; Publisher='Martin Prikryl' },
    [pscustomobject]@{ Name='FileZilla Client'; Category='15. Network & Database'; Id='TimKosse.FileZilla.Client'; ChocoId='filezilla'; DirectUrl=''; DirectArgs=''; Publisher='Tim Kosse' },
    [pscustomobject]@{ Name='Nmap'; Category='15. Network & Database'; Id='Insecure.Nmap'; ChocoId='nmap'; DirectUrl=''; DirectArgs=''; Publisher='Insecure.Org' },
    [pscustomobject]@{ Name='Angry IP Scanner'; Category='15. Network & Database'; Id='angryziber.AngryIPScanner'; ChocoId='angryip'; DirectUrl=''; DirectArgs=''; Publisher='Anton Keks' },
    [pscustomobject]@{ Name='Termius'; Category='15. Network & Database'; Id='Termius.Termius'; ChocoId='termius'; DirectUrl=''; DirectArgs=''; Publisher='Termius Corporation' },
    [pscustomobject]@{ Name='MTPuTTY'; Category='15. Network & Database'; Id='TTYPlus.MTPuTTY'; ChocoId='mtputty'; DirectUrl=''; DirectArgs=''; Publisher='TTYPlus' },
    [pscustomobject]@{ Name='Redis Insight'; Category='15. Network & Database'; Id='Redis.RedisInsight'; ChocoId='redis-insight'; DirectUrl=''; DirectArgs=''; Publisher='Redis Ltd.' },
    [pscustomobject]@{ Name='Advanced IP Scanner'; Category='15. Network & Database'; Id='Famatech.AdvancedIPScanner'; ChocoId='advanced-ip-scanner'; DirectUrl=''; DirectArgs=''; Publisher='Famatech' },

    # 16. Torrent & Download Managers (10 Apps)
    [pscustomobject]@{ Name='Free Download Manager'; Category='16. Downloads & Torrent'; Id='SoftDeluxe.FreeDownloadManager'; ChocoId='freedownloadmanager'; DirectUrl=''; DirectArgs=''; Publisher='SoftDeluxe' },
    [pscustomobject]@{ Name='Internet Download Manager'; Category='16. Downloads & Torrent'; Id='Tonec.InternetDownloadManager'; ChocoId='internet-download-manager'; DirectUrl=''; DirectArgs=''; Publisher='Tonic Solutions' },
    [pscustomobject]@{ Name='qBittorrent'; Category='16. Downloads & Torrent'; Id='qBittorrent.qBittorrent'; ChocoId='qbittorrent'; DirectUrl=''; DirectArgs=''; Publisher='The qBittorrent Project' },
    [pscustomobject]@{ Name='Transmission'; Category='16. Downloads & Torrent'; Id='Transmission.Transmission'; ChocoId='transmission'; DirectUrl=''; DirectArgs=''; Publisher='Transmission Project' },
    [pscustomobject]@{ Name='Deluge Torrent'; Category='16. Downloads & Torrent'; Id='DelugeTeam.Deluge'; ChocoId='deluge'; DirectUrl=''; DirectArgs=''; Publisher='Deluge Team' },
    [pscustomobject]@{ Name='Motrix Download Manager'; Category='16. Downloads & Torrent'; Id='agalwood.Motrix'; ChocoId='motrix'; DirectUrl=''; DirectArgs=''; Publisher='Megalwood' },
    [pscustomobject]@{ Name='PicoTorrent'; Category='16. Downloads & Torrent'; Id='PicoTorrent.PicoTorrent'; ChocoId='picotorrent'; DirectUrl=''; DirectArgs=''; Publisher='PicoTorrent' },
    [pscustomobject]@{ Name='Aria2 Download Utility'; Category='16. Downloads & Torrent'; Id='aria2.aria2'; ChocoId='aria2'; DirectUrl=''; DirectArgs=''; Publisher='Tatsuhiro Tsujikawa' },
    [pscustomobject]@{ Name='yt-dlp Video Downloader'; Category='16. Downloads & Torrent'; Id='yt-dlp.yt-dlp'; ChocoId='yt-dlp'; DirectUrl=''; DirectArgs=''; Publisher='yt-dlp Project' },
    [pscustomobject]@{ Name='JDownloader 2'; Category='16. Downloads & Torrent'; Id='AppWork.JDownloader'; ChocoId='jdownloader'; DirectUrl=''; DirectArgs=''; Publisher='AppWork GmbH' },
    # --- 265 additional Winget-first applications; no unverified Chocolatey/direct recipes ---
    # 17. Browsers & Web
    [pscustomobject]@{ Name='Zen Browser'; Category='17. Browsers & Web'; Id='Zen-Team.Zen-Browser'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Floorp Browser'; Category='17. Browsers & Web'; Id='Ablaze.Floorp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Google Chrome Beta'; Category='17. Browsers & Web'; Id='Google.Chrome.Beta'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Google Chrome Dev'; Category='17. Browsers & Web'; Id='Google.Chrome.Dev'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Mozilla Firefox Developer Edition'; Category='17. Browsers & Web'; Id='Mozilla.Firefox.DeveloperEdition'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Edge Beta'; Category='17. Browsers & Web'; Id='Microsoft.Edge.Beta'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Edge Dev'; Category='17. Browsers & Web'; Id='Microsoft.Edge.Dev'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Edge Canary'; Category='17. Browsers & Web'; Id='Microsoft.Edge.Canary'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Chromium (Ungoogled)'; Category='17. Browsers & Web'; Id='eloston.ungoogled-chromium'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Midori Browser'; Category='17. Browsers & Web'; Id='Astian.Midori'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 18. Communication & Meetings
    [pscustomobject]@{ Name='Signal Beta'; Category='18. Communication & Meetings'; Id='OpenWhisperSystems.Signal.Beta'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Cisco Webex'; Category='18. Communication & Meetings'; Id='Cisco.Webex'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Jitsi Meet'; Category='18. Communication & Meetings'; Id='Jitsi.Meet'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='LINE'; Category='18. Communication & Meetings'; Id='LINE.LINE'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='WeChat'; Category='18. Communication & Meetings'; Id='Tencent.WeChat'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Mumble'; Category='18. Communication & Meetings'; Id='Mumble.Mumble'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='TeamSpeak Client'; Category='18. Communication & Meetings'; Id='TeamSpeakSystems.TeamSpeakClient'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Wire'; Category='18. Communication & Meetings'; Id='Wire.Wire'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Mattermost Desktop'; Category='18. Communication & Meetings'; Id='Mattermost.MattermostDesktop'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Ferdium'; Category='18. Communication & Meetings'; Id='Ferdium.Ferdium'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 19. Development & IDEs
    [pscustomobject]@{ Name='GitHub CLI'; Category='19. Development & IDEs'; Id='GitHub.cli'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='GitHub Desktop'; Category='19. Development & IDEs'; Id='GitHub.GitHubDesktop'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Git Extensions'; Category='19. Development & IDEs'; Id='GitExtensionsTeam.GitExtensions'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='TortoiseGit'; Category='19. Development & IDEs'; Id='TortoiseGit.TortoiseGit'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='TortoiseSVN'; Category='19. Development & IDEs'; Id='TortoiseSVN.TortoiseSVN'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='JetBrains Toolbox'; Category='19. Development & IDEs'; Id='JetBrains.Toolbox'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Rider'; Category='19. Development & IDEs'; Id='JetBrains.Rider'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='DataGrip'; Category='19. Development & IDEs'; Id='JetBrains.DataGrip'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='GoLand'; Category='19. Development & IDEs'; Id='JetBrains.GoLand'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PhpStorm'; Category='19. Development & IDEs'; Id='JetBrains.PhpStorm'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='RubyMine'; Category='19. Development & IDEs'; Id='JetBrains.RubyMine'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Inso CLI'; Category='19. Development & IDEs'; Id='Insomnia.Inso'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Bruno API Client'; Category='19. Development & IDEs'; Id='Bruno.Bruno'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Podman Desktop'; Category='19. Development & IDEs'; Id='RedHat.Podman-Desktop'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Vagrant'; Category='19. Development & IDEs'; Id='Hashicorp.Vagrant'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Terraform'; Category='19. Development & IDEs'; Id='Hashicorp.Terraform'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='LLVM'; Category='19. Development & IDEs'; Id='LLVM.LLVM'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MSYS2'; Category='19. Development & IDEs'; Id='MSYS2.MSYS2'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Deno'; Category='19. Development & IDEs'; Id='DenoLand.Deno'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Composer'; Category='19. Development & IDEs'; Id='Composer.Composer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Azure CLI'; Category='19. Development & IDEs'; Id='Microsoft.AzureCLI'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Azure Storage Explorer'; Category='19. Development & IDEs'; Id='Microsoft.AzureStorageExplorer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Azure Functions Core Tools'; Category='19. Development & IDEs'; Id='Microsoft.AzureFunctionsCoreTools'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Windows Terminal Preview'; Category='19. Development & IDEs'; Id='Microsoft.WindowsTerminal.Preview'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='WinDbg'; Category='19. Development & IDEs'; Id='Microsoft.WinDbg'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Visual Studio 2022 Build Tools'; Category='19. Development & IDEs'; Id='Microsoft.VisualStudio.2022.BuildTools'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='.NET SDK 8'; Category='19. Development & IDEs'; Id='Microsoft.DotNet.SDK.8'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='.NET SDK 9'; Category='19. Development & IDEs'; Id='Microsoft.DotNet.SDK.9'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenJDK 17'; Category='19. Development & IDEs'; Id='EclipseAdoptium.Temurin.17.JDK'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 20. Productivity & Notes
    [pscustomobject]@{ Name='Standard Notes'; Category='20. Productivity & Notes'; Id='StandardNotes.StandardNotes'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='TickTick'; Category='20. Productivity & Notes'; Id='Appest.TickTick'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft To Do'; Category='20. Productivity & Notes'; Id='Microsoft.ToDo'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Synology Drive Client'; Category='20. Productivity & Notes'; Id='Synology.DriveClient'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Koodo Reader'; Category='20. Productivity & Notes'; Id='KoodoReader.KoodoReader'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PDFsam Basic'; Category='20. Productivity & Notes'; Id='PDFsam.PDFsam'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 21. Design & Graphics
    [pscustomobject]@{ Name='ImageMagick'; Category='21. Design & Graphics'; Id='ImageMagick.ImageMagick'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Upscayl'; Category='21. Design & Graphics'; Id='Upscayl.Upscayl'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ScreenToGif'; Category='21. Design & Graphics'; Id='NickeManarin.ScreenToGif'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PicPick'; Category='21. Design & Graphics'; Id='NGWIN.PicPick'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Affinity Photo 2'; Category='21. Design & Graphics'; Id='Serif.AffinityPhoto.2'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft PC Manager'; Category='21. Design & Graphics'; Id='Microsoft.PCManager'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 22. Security & Privacy
    [pscustomobject]@{ Name='1Password'; Category='22. Security & Privacy'; Id='AgileBits.1Password'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenVPN Connect'; Category='22. Security & Privacy'; Id='OpenVPNTechnologies.OpenVPNConnect'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Tailscale'; Category='22. Security & Privacy'; Id='Tailscale.Tailscale'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ZeroTier One'; Category='22. Security & Privacy'; Id='ZeroTier.ZeroTierOne'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Cloudflare WARP'; Category='22. Security & Privacy'; Id='Cloudflare.Warp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='AdGuard'; Category='22. Security & Privacy'; Id='Adguard.Adguard'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ESET Security'; Category='22. Security & Privacy'; Id='ESET.Security'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Bitdefender'; Category='22. Security & Privacy'; Id='Bitdefender.Bitdefender'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Portmaster'; Category='22. Security & Privacy'; Id='Safing.Portmaster'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Fiddler Classic'; Category='22. Security & Privacy'; Id='Progress.FiddlerClassic'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Fiddler Everywhere'; Category='22. Security & Privacy'; Id='Progress.FiddlerEverywhere'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='mitmproxy'; Category='22. Security & Privacy'; Id='mitmproxy.mitmproxy'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 23. System & Hardware
    [pscustomobject]@{ Name='balenaEtcher'; Category='23. System & Hardware'; Id='Balena.Etcher'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MSI Afterburner'; Category='23. System & Hardware'; Id='MSI.Afterburner'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NVIDIA App'; Category='23. System & Hardware'; Id='NVIDIA.NVIDIAApp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Intel Driver & Support Assistant'; Category='23. System & Hardware'; Id='Intel.IntelDriverAndSupportAssistant'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Samsung Magician'; Category='23. System & Hardware'; Id='Samsung.SamsungMagician'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Geek Uninstaller'; Category='23. System & Hardware'; Id='GeekUninstaller.GeekUninstaller'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Winaero Tweaker'; Category='23. System & Hardware'; Id='Winaero.WinaeroTweaker'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='O&O ShutUp10++'; Category='23. System & Hardware'; Id='OO-Software.ShutUp10'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='AOMEI Backupper'; Category='23. System & Hardware'; Id='AOMEI.Backupper.Standard'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MiniTool Partition Wizard'; Category='23. System & Hardware'; Id='MiniTool.PartitionWizard'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 24. Remote Access & Networking
    [pscustomobject]@{ Name='RustDesk'; Category='24. Remote Access & Networking'; Id='RustDesk.RustDesk'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Parsec'; Category='24. Remote Access & Networking'; Id='Parsec.Parsec'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MobaXterm'; Category='24. Remote Access & Networking'; Id='Mobatek.MobaXterm'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Remote Desktop Manager'; Category='24. Remote Access & Networking'; Id='Devolutions.RemoteDesktopManager'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Remote Desktop'; Category='24. Remote Access & Networking'; Id='Microsoft.RemoteDesktop'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='WinFsp'; Category='24. Remote Access & Networking'; Id='WinFsp.WinFsp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenSSH'; Category='24. Remote Access & Networking'; Id='Microsoft.OpenSSH.Beta'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NetBird'; Category='24. Remote Access & Networking'; Id='NetBird.NetBird'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='LocalSend'; Category='24. Remote Access & Networking'; Id='LocalSend.LocalSend'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='KDE Connect'; Category='24. Remote Access & Networking'; Id='KDE.KDEConnect'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Barrier'; Category='24. Remote Access & Networking'; Id='DebaucheeOpenSourceGroup.Barrier'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Input Leap'; Category='24. Remote Access & Networking'; Id='InputLeap.InputLeap'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='TightVNC'; Category='24. Remote Access & Networking'; Id='GlavSoft.TightVNC'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NoMachine'; Category='24. Remote Access & Networking'; Id='NoMachine.NoMachine'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 25. Cloud & Backup
    [pscustomobject]@{ Name='Backblaze'; Category='25. Cloud & Backup'; Id='Backblaze.Backblaze'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Proton Drive'; Category='25. Cloud & Backup'; Id='Proton.ProtonDrive'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Duplicati'; Category='25. Cloud & Backup'; Id='Duplicati.Duplicati'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Restic'; Category='25. Cloud & Backup'; Id='Restic.Restic'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='FreeFileSync'; Category='25. Cloud & Backup'; Id='FreeFileSync.FreeFileSync'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Resilio Sync'; Category='25. Cloud & Backup'; Id='Resilio.ResilioSync'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Duplicacy'; Category='25. Cloud & Backup'; Id='Duplicacy.Duplicacy'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 26. Database & Server
    [pscustomobject]@{ Name='PostgreSQL'; Category='26. Database & Server'; Id='PostgreSQL.PostgreSQL'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MariaDB Server'; Category='26. Database & Server'; Id='MariaDB.Server'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Redis'; Category='26. Database & Server'; Id='Redis.Redis'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='InfluxDB'; Category='26. Database & Server'; Id='InfluxData.InfluxDB'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Telegraf'; Category='26. Database & Server'; Id='InfluxData.Telegraf'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Elasticsearch'; Category='26. Database & Server'; Id='Elastic.Elasticsearch'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Kibana'; Category='26. Database & Server'; Id='Elastic.Kibana'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SQL Server Express'; Category='26. Database & Server'; Id='Microsoft.SQLServer.2022.Express'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SQL Server Management Studio'; Category='26. Database & Server'; Id='Microsoft.SQLServerManagementStudio'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Azure Data Studio'; Category='26. Database & Server'; Id='Microsoft.AzureDataStudio'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Oracle SQL Developer'; Category='26. Database & Server'; Id='Oracle.SQLDeveloper'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='CouchDB'; Category='26. Database & Server'; Id='Apache.CouchDB'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Couchbase Server'; Category='26. Database & Server'; Id='Couchbase.Server'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Neo4j Desktop'; Category='26. Database & Server'; Id='Neo4j.Neo4jDesktop'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Robo 3T'; Category='26. Database & Server'; Id='3T.Robo3T'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 27. Gaming & Game Tools
    [pscustomobject]@{ Name='itch'; Category='27. Gaming & Game Tools'; Id='itchio.itch'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Modrinth App'; Category='27. Gaming & Game Tools'; Id='Modrinth.ModrinthApp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='CurseForge'; Category='27. Gaming & Game Tools'; Id='Overwolf.CurseForge'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenRGB'; Category='27. Gaming & Game Tools'; Id='CalcProgrammer1.OpenRGB'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Logitech G HUB'; Category='27. Gaming & Game Tools'; Id='Logitech.GHUB'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SteelSeries GG'; Category='27. Gaming & Game Tools'; Id='SteelSeries.GG'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Elgato Stream Deck'; Category='27. Gaming & Game Tools'; Id='Elgato.StreamDeck'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Corsair iCUE'; Category='27. Gaming & Game Tools'; Id='Corsair.iCUE.5'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Moonlight'; Category='27. Gaming & Game Tools'; Id='MoonlightGameStreamingProject.Moonlight'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Chiaki'; Category='27. Gaming & Game Tools'; Id='StreetPea.Chiaki'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 28. Office & PDF
    [pscustomobject]@{ Name='Microsoft Office Deployment Tool'; Category='28. Office & PDF'; Id='Microsoft.OfficeDeploymentTool'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Visio Viewer'; Category='28. Office & PDF'; Id='Microsoft.VisioViewer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Project Viewer'; Category='28. Office & PDF'; Id='Microsoft.ProjectViewer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PDF-XChange Editor'; Category='28. Office & PDF'; Id='TrackerSoftware.PDF-XChangeEditor'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PDFgear'; Category='28. Office & PDF'; Id='PDFgear.PDFgear'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Master PDF Editor'; Category='28. Office & PDF'; Id='CodeIndustry.MasterPDFEditor'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='KDE Okular'; Category='28. Office & PDF'; Id='KDE.Okular'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Foxit PDF Editor'; Category='28. Office & PDF'; Id='Foxit.FoxitPDFEditor'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Nitro PDF Pro'; Category='28. Office & PDF'; Id='NitroSoftware.NitroPDFPro'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ABBYY FineReader PDF'; Category='28. Office & PDF'; Id='ABBYY.FineReader.PDF'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PDF Arranger'; Category='28. Office & PDF'; Id='pdfarranger.pdfarranger'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Pandoc'; Category='28. Office & PDF'; Id='JohnMacFarlane.Pandoc'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Zotero'; Category='28. Office & PDF'; Id='DigitalScholar.Zotero'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Mendeley Reference Manager'; Category='28. Office & PDF'; Id='Elsevier.MendeleyReferenceManager'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 29. Media & Streaming
    [pscustomobject]@{ Name='Plex Media Server'; Category='29. Media & Streaming'; Id='Plex.PlexMediaServer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Jellyfin Media Player'; Category='29. Media & Streaming'; Id='Jellyfin.JellyfinMediaPlayer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Emby Theater'; Category='29. Media & Streaming'; Id='Emby.EmbyTheater'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Stremio'; Category='29. Media & Streaming'; Id='Stremio.Stremio'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Plex HTPC'; Category='29. Media & Streaming'; Id='Plex.PlexHTPC'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='JRiver Media Center'; Category='29. Media & Streaming'; Id='JRiver.MediaCenter'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='JRiver Media Center 32-bit'; Category='29. Media & Streaming'; Id='JRiver.MediaCenter.32bit'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MediaInfo'; Category='29. Media & Streaming'; Id='MediaArea.MediaInfo'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Shutter Encoder'; Category='29. Media & Streaming'; Id='PaulPacifico.ShutterEncoder'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='FFmpeg'; Category='29. Media & Streaming'; Id='Gyan.FFmpeg.Shared'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Subtitle Edit'; Category='29. Media & Streaming'; Id='Nikse.SubtitleEdit'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MKVcleaver'; Category='29. Media & Streaming'; Id='MkvCleaver.MkvCleaver'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Aegisub'; Category='29. Media & Streaming'; Id='Aegisub.Aegisub'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Jellyfin Server'; Category='29. Media & Streaming'; Id='Jellyfin.Server'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 30. Education & Science
    [pscustomobject]@{ Name='Anki'; Category='30. Education & Science'; Id='Anki.Anki'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='GeoGebra Classic'; Category='30. Education & Science'; Id='GeoGebra.GeoGebra'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='GNU Octave'; Category='30. Education & Science'; Id='GNU.Octave'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='R Project'; Category='30. Education & Science'; Id='RProject.R'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='RStudio'; Category='30. Education & Science'; Id='Posit.RStudio'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Wolfram Mathematica'; Category='30. Education & Science'; Id='WolframResearch.Mathematica'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='KiCad'; Category='30. Education & Science'; Id='KiCad.KiCad'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='FreeCAD'; Category='30. Education & Science'; Id='FreeCAD.FreeCAD'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='LTspice'; Category='30. Education & Science'; Id='AnalogDevices.LTspice'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Fritzing'; Category='30. Education & Science'; Id='Fritzing.Fritzing'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Arduino IDE'; Category='30. Education & Science'; Id='ArduinoSA.IDE.stable'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Processing'; Category='30. Education & Science'; Id='ProcessingFoundation.Processing'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='QGIS'; Category='30. Education & Science'; Id='QGIS.QGIS'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='GNU PSPP'; Category='30. Education & Science'; Id='GNU.PSPP'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Stellarium'; Category='30. Education & Science'; Id='Stellarium.Stellarium'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 31. Fonts & Language Tools
    [pscustomobject]@{ Name='FontForge'; Category='31. Fonts & Language Tools'; Id='FontForge.FontForge'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='BirdFont'; Category='31. Fonts & Language Tools'; Id='BirdFont.BirdFont'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Noto Fonts'; Category='31. Fonts & Language Tools'; Id='Google.NotoFonts'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Keyviz'; Category='31. Fonts & Language Tools'; Id='keyviz.keyviz'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Espanso'; Category='31. Fonts & Language Tools'; Id='Espanso.Espanso'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Ditto Clipboard'; Category='31. Fonts & Language Tools'; Id='Ditto.Ditto'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='CopyQ'; Category='31. Fonts & Language Tools'; Id='hluk.CopyQ'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='QuickLook'; Category='31. Fonts & Language Tools'; Id='QL-Win.QuickLook'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 19. Development & IDEs
    [pscustomobject]@{ Name='VSCodium'; Category='19. Development & IDEs'; Id='VSCodium.VSCodium'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Visual Studio Code Insiders'; Category='19. Development & IDEs'; Id='Microsoft.VisualStudioCode.Insiders'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Apache NetBeans'; Category='19. Development & IDEs'; Id='Apache.NetBeans'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Apache Maven'; Category='19. Development & IDEs'; Id='Apache.Maven'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Gradle'; Category='19. Development & IDEs'; Id='Gradle.Gradle'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Oracle JDK 21'; Category='19. Development & IDEs'; Id='Oracle.JDK.21'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Oracle JDK 17'; Category='19. Development & IDEs'; Id='Oracle.JDK.17'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Amazon Corretto 21 JDK'; Category='19. Development & IDEs'; Id='Amazon.Corretto.21.JDK'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Amazon Corretto 17 JDK'; Category='19. Development & IDEs'; Id='Amazon.Corretto.17.JDK'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='BellSoft Liberica JDK 21'; Category='19. Development & IDEs'; Id='BellSoft.LibericaJDK.21'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Microsoft Bicep'; Category='19. Development & IDEs'; Id='Microsoft.Bicep'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ngrok'; Category='19. Development & IDEs'; Id='Ngrok.Ngrok'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenSSL'; Category='19. Development & IDEs'; Id='ShiningLight.OpenSSL'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='WinMerge'; Category='19. Development & IDEs'; Id='WinMerge.WinMerge'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Beyond Compare'; Category='19. Development & IDEs'; Id='ScooterSoftware.BeyondCompare.5'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='KDiff3'; Category='19. Development & IDEs'; Id='KDE.KDiff3'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Araxis Merge'; Category='19. Development & IDEs'; Id='Araxis.Merge'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 20. Productivity & Notes
    [pscustomobject]@{ Name='Mailspring'; Category='20. Productivity & Notes'; Id='Foundry376.Mailspring'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='eM Client'; Category='20. Productivity & Notes'; Id='eMClient.eMClient'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SoftMaker FreeOffice'; Category='20. Productivity & Notes'; Id='SoftMaker.FreeOffice'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Scribus'; Category='20. Productivity & Notes'; Id='Scribus.Scribus'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='draw.io Desktop'; Category='20. Productivity & Notes'; Id='JGraph.Draw'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Dia Diagram Editor'; Category='20. Productivity & Notes'; Id='Dia.Dia'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Pencil Project'; Category='20. Productivity & Notes'; Id='PencilProject.Pencil'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Freeplane'; Category='20. Productivity & Notes'; Id='Freeplane.Freeplane'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='XMind'; Category='20. Productivity & Notes'; Id='XMind.XMind'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='FocusWriter'; Category='20. Productivity & Notes'; Id='GottCode.FocusWriter'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='QOwnNotes'; Category='20. Productivity & Notes'; Id='PBE.QOwnNotes'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 21. Design & Graphics
    [pscustomobject]@{ Name='OpenSCAD'; Category='21. Design & Graphics'; Id='OpenSCAD.OpenSCAD'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MeshLab'; Category='21. Design & Graphics'; Id='MeshLab.MeshLab'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Ultimaker Cura'; Category='21. Design & Graphics'; Id='Ultimaker.Cura'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PrusaSlicer'; Category='21. Design & Graphics'; Id='Prusa3D.PrusaSlicer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OrcaSlicer'; Category='21. Design & Graphics'; Id='SoftFever.OrcaSlicer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Sweet Home 3D'; Category='21. Design & Graphics'; Id='eTeks.SweetHome3D'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='LibreCAD'; Category='21. Design & Graphics'; Id='LibreCAD.LibreCAD'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Advanced Renamer'; Category='21. Design & Graphics'; Id='HulubuluSoftware.AdvancedRenamer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='PhotoDemon'; Category='21. Design & Graphics'; Id='PhotoDemon.PhotoDemon'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 22. Security & Privacy
    [pscustomobject]@{ Name='Windscribe'; Category='22. Security & Privacy'; Id='Windscribe.Windscribe'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Psiphon'; Category='22. Security & Privacy'; Id='Psiphon.Psiphon'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Enpass'; Category='22. Security & Privacy'; Id='Enpass.Enpass'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Dashlane'; Category='22. Security & Privacy'; Id='Dashlane.Dashlane'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NordPass'; Category='22. Security & Privacy'; Id='NordSecurity.NordPass'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 23. System & Hardware
    [pscustomobject]@{ Name='Driver Store Explorer'; Category='23. System & Hardware'; Id='RAPR.DriverStoreExplorer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Display Driver Uninstaller'; Category='23. System & Hardware'; Id='Wagnardsoft.DisplayDriverUninstaller'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NVCleanstall'; Category='23. System & Hardware'; Id='TechPowerUp.NVCleanstall'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Recuva'; Category='23. System & Hardware'; Id='Piriform.Recuva'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Defraggler'; Category='23. System & Hardware'; Id='Piriform.Defraggler'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Wise Disk Cleaner'; Category='23. System & Hardware'; Id='WiseCleaner.WiseDiskCleaner'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Wise Registry Cleaner'; Category='23. System & Hardware'; Id='WiseCleaner.WiseRegistryCleaner'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Wise Memory Optimizer'; Category='23. System & Hardware'; Id='WiseCleaner.WiseMemoryOptimizer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='IObit Advanced SystemCare'; Category='23. System & Hardware'; Id='IObit.AdvancedSystemCare'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='IObit Driver Booster'; Category='23. System & Hardware'; Id='IObit.DriverBooster'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Lenovo Vantage'; Category='23. System & Hardware'; Id='Lenovo.Vantage'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Dell Command Update'; Category='23. System & Hardware'; Id='Dell.CommandUpdate'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='HP Image Assistant'; Category='23. System & Hardware'; Id='HP.HPImageAssistant'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='ASUS Armoury Crate'; Category='23. System & Hardware'; Id='ASUS.ArmouryCrate'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='AMD Ryzen Master'; Category='23. System & Hardware'; Id='AMD.RyzenMaster'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Intel Graphics Command Center'; Category='23. System & Hardware'; Id='Intel.IntelGraphicsCommandCenter'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 24. Remote Access & Networking
    [pscustomobject]@{ Name='Cyberduck'; Category='24. Remote Access & Networking'; Id='iterate.Cyberduck'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NSSM'; Category='24. Remote Access & Networking'; Id='NSSM.NSSM'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='OpenSSL Light'; Category='24. Remote Access & Networking'; Id='ShiningLight.OpenSSL.Light'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Cloudflare Tunnel'; Category='24. Remote Access & Networking'; Id='Cloudflare.cloudflared'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Netcat'; Category='24. Remote Access & Networking'; Id='HackerTarget.Netcat'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Famatech Radmin Viewer'; Category='24. Remote Access & Networking'; Id='Famatech.RadminViewer'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Supremo'; Category='24. Remote Access & Networking'; Id='Nanosystems.Supremo'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 25. Cloud & Backup
    [pscustomobject]@{ Name='Duplicati Canary'; Category='25. Cloud & Backup'; Id='Duplicati.Duplicati.Canary'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Kopia'; Category='25. Cloud & Backup'; Id='Kopia.Kopia'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Borg Backup'; Category='25. Cloud & Backup'; Id='Borg.Borg'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Syncthing GTK'; Category='25. Cloud & Backup'; Id='Syncthing.SyncthingGTK'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 26. Database & Server
    [pscustomobject]@{ Name='MySQL Server'; Category='26. Database & Server'; Id='Oracle.MySQL'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MySQL Shell'; Category='26. Database & Server'; Id='Oracle.MySQLShell'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SQLite'; Category='26. Database & Server'; Id='SQLite.SQLite'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='SQLiteStudio'; Category='26. Database & Server'; Id='sqlitestudio.SQLiteStudio'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MongoDB Server'; Category='26. Database & Server'; Id='MongoDB.Server'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='MongoDB Shell'; Category='26. Database & Server'; Id='MongoDB.Shell'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Cassandra'; Category='26. Database & Server'; Id='Apache.Cassandra'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Apache Tomcat'; Category='26. Database & Server'; Id='Apache.Tomcat'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    # 27. Gaming & Game Tools
    [pscustomobject]@{ Name='PlayStation Remote Play'; Category='27. Gaming & Game Tools'; Id='Sony.PlayStationRemotePlay'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Xbox Accessories'; Category='27. Gaming & Game Tools'; Id='Microsoft.XboxAccessories'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Xbox App'; Category='27. Gaming & Game Tools'; Id='Microsoft.GamingApp'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='NVIDIA GeForce NOW'; Category='27. Gaming & Game Tools'; Id='Nvidia.GeForceNow'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Razer Cortex'; Category='27. Gaming & Game Tools'; Id='RazerInc.RazerCortex'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='DS4Windows'; Category='27. Gaming & Game Tools'; Id='Ryochan7.DS4Windows'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='BakkesMod'; Category='27. Gaming & Game Tools'; Id='BakkesMod.BakkesMod'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' },
    [pscustomobject]@{ Name='Lossless Scaling'; Category='27. Gaming & Game Tools'; Id='THS.LosslessScaling'; ChocoId=''; DirectUrl=''; DirectArgs=''; Publisher='' }
)

# --- SOFTWARE ICONS: DOWNLOAD/CACHE THE PUBLISHED ICON PACK ---
# Only affects the Software catalog's icon files; no installer or other UI logic is changed.
$script:IconArchiveUrl = 'https://raw.githubusercontent.com/3mr10aa/Amr_tools/91d4c6047478238e8fd9ddd421ea5bd4c54769e0/icons.zip'
$script:IconArchivePath = Join-Path $script:DownloadDir 'amr-software-icons.zip'

function Initialize-AMRSoftwareIcons {
    param([Parameter(Mandatory = $true)][object[]]$Apps)

    # Avoid network and extraction work when all catalog icons are already cached.
    $missingIcons = @($Apps | Where-Object {
        $id = [string]$_.Id
        -not (Test-Path -LiteralPath (Join-Path $script:IconDir "$id.png") -PathType Leaf) -and
        -not (Test-Path -LiteralPath (Join-Path $script:IconDir "$id.jpg") -PathType Leaf) -and
        -not (Test-Path -LiteralPath (Join-Path $script:IconDir "$id.jpeg") -PathType Leaf)
    }).Count
    if ($missingIcons -eq 0) {
        Write-AMRLog "All $($Apps.Count) software icons are already cached; skipping icon download." INFO Software
        return
    }

    $downloadTemp = "$($script:IconArchivePath).download"
    $stagingDir = Join-Path $script:DownloadDir 'AMR_Icons_Staging'
    try {
        if (-not (Test-Path -LiteralPath $script:IconArchivePath -PathType Leaf)) {
            Write-AMRLog "Downloading the software icon pack ($missingIcons catalog icons missing)..." INFO Software
            # Windows PowerShell 5.1 may otherwise negotiate an older TLS protocol.
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
            Remove-Item -LiteralPath $downloadTemp -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $script:IconArchiveUrl -OutFile $downloadTemp -UseBasicParsing -TimeoutSec 45 -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $downloadTemp -PathType Leaf) -or (Get-Item -LiteralPath $downloadTemp).Length -lt 1024) {
                throw 'The downloaded icon archive is empty or too small.'
            }
            # Validate the ZIP before replacing the cached copy.
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
            $zipCheck = [System.IO.Compression.ZipFile]::OpenRead($downloadTemp)
            try { if ($zipCheck.Entries.Count -lt 1) { throw 'The icon ZIP contains no files.' } }
            finally { $zipCheck.Dispose() }
            Move-Item -LiteralPath $downloadTemp -Destination $script:IconArchivePath -Force
        }

        if (Test-Path -LiteralPath $stagingDir) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
        Expand-Archive -LiteralPath $script:IconArchivePath -DestinationPath $stagingDir -Force -ErrorAction Stop

        $imageFiles = @(Get-ChildItem -LiteralPath $stagingDir -Recurse -File -ErrorAction Stop | Where-Object {
            $_.Extension -match '^\.(png|jpe?g)$'
        })
        if ($imageFiles.Count -eq 0) { throw 'No PNG/JPG icons were found in the downloaded archive.' }

        # Index by exact filename first; the archive was prepared with application IDs as filenames.
        $byBaseName = @{}
        foreach ($file in $imageFiles) {
            $key = [System.IO.Path]::GetFileNameWithoutExtension($file.Name).ToLowerInvariant()
            if (-not $byBaseName.ContainsKey($key)) { $byBaseName[$key] = $file }
        }

        $copied = 0
        foreach ($app in $Apps) {
            $appId = [string]$app.Id
            $sourceIcon = $null
            $exactKey = $appId.ToLowerInvariant()
            if ($byBaseName.ContainsKey($exactKey)) {
                $sourceIcon = $byBaseName[$exactKey]
            } else {
                # Be tolerant of filenames where punctuation in the ID was normalized.
                $normalizedId = ($appId -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
                foreach ($file in $imageFiles) {
                    $normalizedBase = ([System.IO.Path]::GetFileNameWithoutExtension($file.Name) -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
                    if ($normalizedBase -eq $normalizedId) { $sourceIcon = $file; break }
                }
            }

            if ($null -ne $sourceIcon) {
                $targetExtension = if ($sourceIcon.Extension -ieq '.jpeg') { '.jpg' } else { $sourceIcon.Extension.ToLowerInvariant() }
                $targetPath = Join-Path $script:IconDir ($appId + $targetExtension)
                Copy-Item -LiteralPath $sourceIcon.FullName -Destination $targetPath -Force -ErrorAction Stop
                $copied++
            }
        }
        Write-AMRLog "Icon pack processed: matched and cached $copied of $($Apps.Count) catalog applications." $(if ($copied -gt 0) { 'SUCCESS' } else { 'WARNING' }) Software
    }
    catch {
        Write-AMRLog "Could not initialize the online software icon pack: $($_.Exception.Message). Existing local icons will still be used." WARNING Software
        # Do not keep a broken/incomplete download that would block future attempts.
        if (Test-Path -LiteralPath $downloadTemp) { Remove-Item -LiteralPath $downloadTemp -Force -ErrorAction SilentlyContinue }
        if ((Test-Path -LiteralPath $script:IconArchivePath) -and (Get-Item -LiteralPath $script:IconArchivePath).Length -lt 1024) {
            Remove-Item -LiteralPath $script:IconArchivePath -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingDir) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Initialize-AMRSoftwareIcons -Apps @($RawApps)

# Convert icon files to frozen WPF ImageSource objects.
# WPF Image.Source expects an ImageSource, not a plain filesystem path string.
function Get-AMRIconImageSource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.CreateOptions = [System.Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
        $bitmap.UriSource = New-Object System.Uri($fullPath, [System.UriKind]::Absolute)
        $bitmap.EndInit()

        if ($bitmap.CanFreeze) {
            $bitmap.Freeze()
        }

        return $bitmap
    }
    catch {
        Write-AMRLog "Could not load app icon '$Path': $($_.Exception.Message)" WARNING Software
        return $null
    }
}

$script:SoftwareCatalog = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'

$RawApps | ForEach-Object {
    $initial  = if ($_.Name.Length -gt 0) { $_.Name.Substring(0,1).ToUpper() } else { 'A' }
    $iconPath = Join-Path $script:IconDir "$($_.Id).png"
    $jpgPath  = Join-Path $script:IconDir "$($_.Id).jpg"
    $jpegPath = Join-Path $script:IconDir "$($_.Id).jpeg"
    $iconSource = $null

    if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
        $iconSource = Get-AMRIconImageSource -Path $iconPath
    }

    if ($null -eq $iconSource -and
        (Test-Path -LiteralPath $jpgPath -PathType Leaf)) {
        $iconSource = Get-AMRIconImageSource -Path $jpgPath
    }

    if ($null -eq $iconSource -and
        (Test-Path -LiteralPath $jpegPath -PathType Leaf)) {
        $iconSource = Get-AMRIconImageSource -Path $jpegPath
    }

    $script:SoftwareCatalog.Add([pscustomobject]@{
        IsSelected    = $false
        Name          = $_.Name
        Category      = $_.Category
        Id            = $_.Id
        ChocoId       = $_.ChocoId
        DirectUrl     = $_.DirectUrl
        DirectArgs    = $_.DirectArgs
        Publisher     = $_.Publisher
        Initials      = $initial
        Icon          = [System.Windows.Media.ImageSource]$iconSource
    })
}

$loadedIconCount = @($script:SoftwareCatalog | Where-Object { $null -ne $_.Icon }).Count
Write-AMRLog "Loaded $loadedIconCount app icons out of $($script:SoftwareCatalog.Count) catalog entries from '$script:IconDir'." INFO Software

# --- 4. FULL WPF XAML INTERFACE WITH PROGRESS BAR & 27 CUSTOMIZE TOOLS ---
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
        Title="Amr | windows_utility" Height="700" Width="1100" 
        MinHeight="600" MinWidth="900" WindowStartupLocation="CenterScreen" WindowState="Normal" 
        Background="#18181B" Foreground="#E4E4E7" FontFamily="Segoe UI">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Background" Value="#27272A"/>
   <Setter Property="Foreground" Value="#F4F4F5"/>
   <Setter Property="BorderThickness" Value="1"/>
   <Setter Property="BorderBrush" Value="#3F3F46"/>
   <Setter Property="FontWeight" Value="SemiBold"/>
   <Setter Property="Cursor" Value="Hand"/>
   <Setter Property="Padding" Value="15,8"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="Button">
      <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
       <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
      </Border>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
  
  <Style TargetType="TabControl">
   <Setter Property="Background" Value="#18181B"/>
   <Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="TabControl">
      <Grid>
       <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
       </Grid.RowDefinitions>
       <UniformGrid Grid.Row="0" Rows="1" Columns="12" IsItemsHost="True" Margin="0,0,0,10"/>
       <Border Grid.Row="1" Background="{TemplateBinding Background}">
        <ContentPresenter ContentSource="SelectedContent"/>
       </Border>
      </Grid>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <Style TargetType="TabItem">
   <Setter Property="Padding" Value="0,10"/>
   <Setter Property="Margin" Value="2,0"/>
   <Setter Property="Foreground" Value="#A1A1AA"/>
   <Setter Property="Background" Value="#27272A"/>
   <Setter Property="BorderThickness" Value="1"/>
   <Setter Property="BorderBrush" Value="#3F3F46"/>
   <Setter Property="FontSize" Value="13"/>
   <Setter Property="HorizontalContentAlignment" Value="Center"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="TabItem">
      <Border Name="Border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="{TemplateBinding Margin}">
       <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header"/>
      </Border>
      <ControlTemplate.Triggers>
       <Trigger Property="IsSelected" Value="True">
        <Setter TargetName="Border" Property="Background" Value="#2563EB"/>
        <Setter TargetName="Border" Property="BorderBrush" Value="#3B82F6"/>
        <Setter Property="Foreground" Value="#FFFFFF"/>
        <Setter Property="FontWeight" Value="Bold"/>
       </Trigger>
      </ControlTemplate.Triggers>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>

  <Style TargetType="TextBox">
   <Setter Property="Background" Value="#27272A"/>
   <Setter Property="Foreground" Value="#FFFFFF"/>
   <Setter Property="BorderBrush" Value="#3F3F46"/>
   <Setter Property="BorderThickness" Value="1"/>
   <Setter Property="Padding" Value="12,8"/>
   <Setter Property="VerticalContentAlignment" Value="Center"/>
   <Setter Property="Template">
    <Setter.Value>
     <ControlTemplate TargetType="TextBox">
      <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
       <ScrollViewer x:Name="PART_ContentHost"/>
      </Border>
     </ControlTemplate>
    </Setter.Value>
   </Setter>
  </Style>
 </Window.Resources>
 
 <Grid>
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  
  <!-- Header -->
  <Border Background="#18181B" BorderBrush="#27272A" BorderThickness="0,0,0,1" Padding="20">
   <Grid>
    <StackPanel>
     <TextBlock Text="Amr | windows_utility" FontSize="26" FontWeight="Bold" Foreground="#3B82F6"/>
     <TextBlock Text="V0.1" Foreground="#A1A1AA" FontSize="13" Margin="0,2,0,0" FontWeight="SemiBold"/>
    </StackPanel>
    <StackPanel HorizontalAlignment="Right" VerticalAlignment="Center" Orientation="Horizontal">
     <TextBlock Text="ADMINISTRATOR" Foreground="#10B981" FontWeight="Bold" FontSize="14" Margin="0,0,20,0"/>
     <TextBlock Name="WingetHeader" Text="Checking Winget..." Foreground="#A1A1AA" FontSize="13" VerticalAlignment="Center"/>
    </StackPanel>
   </Grid>
  </Border>
  
  <TabControl Grid.Row="1" Margin="15,15,15,0">
   
   <!-- 1. OVERVIEW -->
   <TabItem Header="Overview">
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="10,0,10,20">
     <StackPanel>
      <Grid Margin="0,10,0,15">
       <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
       </Grid.ColumnDefinitions>
       <StackPanel Grid.Column="0">
        <TextBlock Text="SYSTEM OVERVIEW" FontSize="24" FontWeight="Bold" Foreground="#F8FAFC"/>
        <TextBlock Text="Your device at a glance  •  Hardware, performance &amp; health" Foreground="#94A3B8" FontSize="12" TextWrapping="Wrap" Margin="0,5,8,0"/>
       </StackPanel>
       <StackPanel Grid.Column="1" VerticalAlignment="Center" HorizontalAlignment="Right">
        <Button Name="RefreshOverviewBtn" Content="↻ Refresh" Background="#2563EB" Foreground="#FFFFFF" BorderBrush="#60A5FA" BorderThickness="1" Padding="18,9" FontSize="13" FontWeight="SemiBold" Cursor="Hand"/>
        <TextBlock Name="ovLastRefresh" Text="Updated: --" Foreground="#94A3B8" FontSize="10" HorizontalAlignment="Right" Margin="0,5,2,0"/>
       </StackPanel>
      </Grid>
      <WrapPanel Orientation="Horizontal">
       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="System Information" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <TextBlock Name="ovOS" Text="OS: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
         <TextBlock Name="ovPCName" Text="PC Name: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
         <TextBlock Name="ovArch" Text="Architecture: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
         <TextBlock Name="ovDeviceType" Text="Device Type: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
        </StackPanel>
       </Border>

       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Processor &amp; Graphics" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <TextBlock Name="ovCPU" Text="CPU: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovCPULoad" Text="CPU Usage: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
         <TextBlock Name="ovGPU" Text="GPU: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4" TextWrapping="Wrap"/>
        </StackPanel>
       </Border>

       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Memory (RAM)" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <TextBlock Name="ovRAMTotal" Text="Total: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
         <TextBlock Name="ovRAMUsage" Text="Usage: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
        </StackPanel>
       </Border>

       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Motherboard &amp; BIOS" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <TextBlock Name="ovMobo" Text="Board: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovBIOS" Text="BIOS Version: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
        </StackPanel>
       </Border>

       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Disk Storage" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <ItemsControl Name="ovDisks">
          <ItemsControl.ItemTemplate>
           <DataTemplate>
            <TextBlock Text="{Binding DisplayText}" Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
           </DataTemplate>
          </ItemsControl.ItemTemplate>
         </ItemsControl>
        </StackPanel>
       </Border>

       <Border Background="#1B2432" BorderBrush="#334155" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Network Status" FontSize="15" FontWeight="Bold" Foreground="#7DB7FF" Margin="0,0,0,10"/>
         <TextBlock Name="ovIP" Text="IPv4 Address: Loading..." Foreground="#E4E4E7" FontSize="13" Margin="0,4"/>
        </StackPanel>
       </Border>
      </WrapPanel>

      <TextBlock Text="LIVE PERFORMANCE &amp; DEVICE HEALTH" FontSize="15" FontWeight="Bold" Foreground="#60A5FA" Margin="10,8,10,2"/>
      <WrapPanel Orientation="Horizontal">
       <Border Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Performance &amp; Resources" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovUptime" Text="System Uptime: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovProcesses" Text="Running Processes: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovThreads" Text="CPU Cores / Threads: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovRAMAvailable" Text="Available RAM: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
        </StackPanel>
       </Border>
       <Border Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Display &amp; Graphics" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovDisplay" Text="Display: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovGPUDetails" Text="Graphics Memory: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovBIOSDate" Text="BIOS Date: Loading..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
        </StackPanel>
       </Border>
       <Border Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Security Status" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovDefender" Text="Microsoft Defender: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovFirewall" Text="Windows Firewall: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovTPM" Text="TPM: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovSecureBoot" Text="Secure Boot: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovWindowsActivation" Text="Windows Activation: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
        </StackPanel>
       </Border>
       <Border Name="ovBatteryCard" Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Battery Information" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovBatteryStatus" Text="Battery: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovBatteryHealth" Text="Battery Health: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovBatteryCapacity" Text="Design / Full Charge: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
        </StackPanel>
       </Border>
       <Border Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Network Details" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovNetworkAdapter" Text="Adapter: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovGatewayDNS" Text="Gateway / DNS: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4" TextWrapping="Wrap"/>
         <TextBlock Name="ovLinkSpeed" Text="Link Speed: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
        </StackPanel>
       </Border>
       <Border Background="#182638" BorderBrush="#35506D" BorderThickness="1" CornerRadius="14" Padding="18" Margin="8" Width="390">
        <StackPanel>
         <TextBlock Text="Windows &amp; Updates" FontSize="15" FontWeight="Bold" Foreground="#7DD3FC" Margin="0,0,0,8"/>
         <TextBlock Name="ovBuild" Text="Windows Build: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovLastBoot" Text="Last Boot: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4"/>
         <TextBlock Name="ovUpdate" Text="Latest Installed Update: Checking..." Foreground="#E4E4E7" FontSize="12" Margin="0,4" TextWrapping="Wrap"/>
        </StackPanel>
       </Border>
      </WrapPanel>
     </StackPanel>
    </ScrollViewer>
   </TabItem>

   <!-- 2. SOFTWARE WITH INTEGRATED PROGRESS BAR -->
   <TabItem Header="Software" IsSelected="True">
    <Border Padding="10,0,10,20">
     <Grid>
      <Grid.RowDefinitions>
       <RowDefinition Height="Auto"/>
       <RowDefinition Height="*"/>
       <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      
      <Grid Grid.Row="0" Margin="0,10,0,20">
       <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="350"/>
       </Grid.ColumnDefinitions>
       <StackPanel Grid.Column="0" VerticalAlignment="Center">
        <TextBlock Text="Software Catalog" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="Smart Multi-Tier Engine (Winget ➔ Chocolatey ➔ Strict Verified Direct Download)." Foreground="#A1A1AA" FontSize="11" TextWrapping="Wrap" Margin="0,3,0,0"/>
       </StackPanel>
       
       <TextBox Name="SearchBox" Grid.Column="1" Height="42" VerticalAlignment="Center" FontSize="15" ToolTip="Search by name or ID..."/>
       <TextBlock Grid.Column="1" Text="🔍 Search name or ID..." IsHitTestVisible="False" VerticalAlignment="Center" Margin="15,0,0,0" Foreground="#71717A" FontSize="14">
        <TextBlock.Style>
         <Style TargetType="TextBlock">
          <Setter Property="Visibility" Value="Hidden"/>
          <Style.Triggers>
           <DataTrigger Binding="{Binding Text.Length, ElementName=SearchBox}" Value="0">
            <Setter Property="Visibility" Value="Visible"/>
           </DataTrigger>
          </Style.Triggers>
         </Style>
        </TextBlock.Style>
       </TextBlock>
      </Grid>
      
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
       <ItemsControl Name="SoftwareGrid" Margin="0,5,0,0">
        <ItemsControl.GroupStyle>
         <GroupStyle>
          <GroupStyle.Panel>
           <ItemsPanelTemplate><StackPanel Orientation="Vertical"/></ItemsPanelTemplate>
          </GroupStyle.Panel>
          <GroupStyle.HeaderTemplate>
           <DataTemplate>
            <Border BorderBrush="#3F3F46" BorderThickness="0,0,0,1" Margin="10,20,10,15" Padding="0,0,0,8">
             <TextBlock Text="{Binding Name}" FontSize="18" FontWeight="SemiBold" Foreground="#3B82F6"/>
            </Border>
           </DataTemplate>
          </GroupStyle.HeaderTemplate>
         </GroupStyle>
        </ItemsControl.GroupStyle>
        <ItemsControl.ItemsPanel>
         <ItemsPanelTemplate><WrapPanel Orientation="Horizontal"/></ItemsPanelTemplate>
        </ItemsControl.ItemsPanel>
        
        <ItemsControl.ItemTemplate>
         <DataTemplate>
          <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="330">
           <Grid>
            <Grid.ColumnDefinitions>
             <ColumnDefinition Width="Auto"/>
             <ColumnDefinition Width="Auto"/>
             <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <CheckBox IsChecked="{Binding IsSelected, UpdateSourceTrigger=PropertyChanged}" VerticalAlignment="Center" Margin="0,0,15,0">
             <CheckBox.LayoutTransform><ScaleTransform ScaleX="1.2" ScaleY="1.2"/></CheckBox.LayoutTransform>
            </CheckBox>
            <Grid Grid.Column="1" Width="48" Height="48" Margin="0,0,15,0">
             <Border Background="#3F3F46" CornerRadius="10"/>
             <TextBlock Text="{Binding Initials}" Foreground="#A1A1AA" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center">
              <TextBlock.Style>
               <Style TargetType="TextBlock">
                <Setter Property="Visibility" Value="Collapsed"/>
                <Style.Triggers>
                 <DataTrigger Binding="{Binding Icon}" Value="{x:Null}">
                  <Setter Property="Visibility" Value="Visible"/>
                 </DataTrigger>
                </Style.Triggers>
               </Style>
              </TextBlock.Style>
             </TextBlock>
             <Image Source="{Binding Icon, Mode=OneWay, TargetNullValue={x:Null}, FallbackValue={x:Null}}" Width="36" Height="36" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True" RenderOptions.BitmapScalingMode="HighQuality"/>
            </Grid>
            <StackPanel Grid.Column="2" VerticalAlignment="Center">
             <TextBlock Text="{Binding Name}" FontSize="16" FontWeight="Bold" Foreground="#FFFFFF" TextWrapping="Wrap"/>
             <TextBlock Text="{Binding Id}" FontSize="12" Foreground="#71717A" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
           </Grid>
          </Border>
         </DataTemplate>
        </ItemsControl.ItemTemplate>
       </ItemsControl>
      </ScrollViewer>
      
      <!-- App Console Bottom Bar & Progress Bar -->
      <Border Grid.Row="2" Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="12" Padding="20" Margin="0,20,0,0">
       <Grid>
        <Grid.RowDefinitions>
         <RowDefinition Height="Auto"/>
         <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <Grid Grid.Row="0">
         <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
         </Grid.ColumnDefinitions>
         <StackPanel Grid.Column="0" VerticalAlignment="Center">
          <TextBlock Text="App Management Console" Foreground="#FFFFFF" FontSize="16" FontWeight="Bold"/>
          <TextBlock Name="ProgressText" Text="Ready to process selected apps." Foreground="#10B981" FontSize="13" Margin="0,4,0,0" FontWeight="SemiBold"/>
         </StackPanel>
         <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
          <Button Name="DeselectAllBtn" Content="Clear Selection" Background="Transparent" Foreground="#A1A1AA" FontSize="14" Margin="0,0,15,0"/>
          <Button Name="RepairSelectedBtn" Content="🔧 Repair" Background="#EAB308" Foreground="#18181B" BorderThickness="0" FontSize="14" FontWeight="Bold" Margin="0,0,15,0"/>
          <Button Name="UpdateSelectedBtn" Content="⬆ Update" Background="#3B82F6" Foreground="#FFFFFF" BorderThickness="0" FontSize="14" FontWeight="Bold" Margin="0,0,15,0"/>
          <Button Name="InstallInteractiveBtn" Content="🖥 Interactive Install" Background="#8B5CF6" Foreground="#FFFFFF" BorderThickness="0" Padding="15,12" FontSize="14" FontWeight="Bold" Margin="0,0,10,0"/>
          <Button Name="InstallSelectedBtn" Content="⬇ Smart Install" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" Padding="20,12" FontSize="14" FontWeight="Bold"/>
         </StackPanel>
        </Grid>
        
        <!-- Live Progress Bar -->
        <ProgressBar Name="InstallProgressBar" Grid.Row="1" Height="8" Minimum="0" Maximum="100" Value="0" Background="#18181B" Foreground="#10B981" Margin="0,15,0,0" BorderThickness="0"/>
       </Grid>
      </Border>
     </Grid>
    </Border>
   </TabItem>

   <!-- 3. MEGA CUSTOMIZE SUITE (27 TOOLS & TWEAKS) -->
   <TabItem Header="Customize">
    <Grid Margin="8,4,8,8">
     <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="2"/>
      <ColumnDefinition Width="*"/>
     </Grid.ColumnDefinitions>
     <!-- Existing customization tools remain on the left, independently scrollable. -->
     <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="4,0,8,8">
      <StackPanel Name="CustomizePanel">
      <Grid Margin="0,10,0,15">
       <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
       </Grid.ColumnDefinitions>
       <StackPanel Grid.Column="0" Margin="0,0,8,0" VerticalAlignment="Center">
        <TextBlock Text="Windows Customization" FontSize="12" FontWeight="Bold" Foreground="#FFFFFF" TextWrapping="Wrap"/>
        <TextBlock Text="Select the tweaks you want to apply safely." Foreground="#A1A1AA" FontSize="9" TextWrapping="Wrap" Margin="0,2,0,0"/>
       </StackPanel>
       <StackPanel Grid.Column="1" VerticalAlignment="Center" MinWidth="112">
        <Button Name="ApplyCustomizeBtn" Content="⚡ Apply Tweaks" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" FontSize="9" FontWeight="Bold" Padding="7,5"/>
        <Button Name="CancelCustomizeBtn" Content="✕ Cancel Tweaks" Background="#3F1D1D" Foreground="#FECACA" BorderBrush="#7F1D1D" FontSize="9" Padding="7,5" Margin="0,4,0,0" ToolTip="Clear selections in the left panel only"/>
        <TextBlock Name="CustomizeSelectionCount" Text="0 selected on left" Foreground="#A1A1AA" FontSize="9" TextAlignment="Center" Margin="0,4,0,0"/>
       </StackPanel>
      </Grid>

      <WrapPanel Orientation="Horizontal">
       <!-- Group 1: Appearance & Visuals (5 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="1. Appearance &amp; Visuals" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkDarkMode" Content="01. Enable System Dark Mode" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableTransparency" Content="02. Disable Transparency Effects" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableAccentColor" Content="03. Disable Accent Color on Title Bars" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkClassicVolume" Content="04. Enable Classic Volume Control Flyout" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableAnimations" Content="05. Minimize Window Animation Overhead" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>

       <!-- Group 2: Taskbar & Start Menu (5 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="2. Taskbar &amp; Start Menu" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkShowSeconds" Content="06. Show Seconds in Taskbar Clock" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableBingSearch" Content="07. Disable Bing Web Search in Start Menu" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkTaskbarLeft" Content="08. Align Taskbar Icons to Left (Win 11)" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkHideWidgets" Content="09. Hide Widgets Button on Taskbar" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkHideTaskView" Content="10. Hide Task View Icon" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>

       <!-- Group 3: File Explorer & Views (5 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="3. File Explorer &amp; View" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkHiddenFiles" Content="11. Show Hidden Files &amp; Extensions" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkOpenThisPC" Content="12. Open Explorer directly to 'This PC'" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkClassicContextMenu" Content="13. Restore Win 10 Classic Right-Click Menu" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkHideRecentFiles" Content="14. Hide Recent Files in Quick Access" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkSeparateFolderProcess" Content="15. Launch Folders in Separate Process" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>

       <!-- Group 4: System Behavior & Accessibility (4 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="4. Behavior &amp; Accessibility" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkDisableStickyKeys" Content="16. Disable Sticky Keys Shortcut Popup" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableAutoRebootUpdate" Content="17. Prevent Auto Reboot on Windows Update" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkShowBSODDetails" Content="18. Show Detailed Information on BSOD" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableShortcutSuffix" Content="19. Remove '- Shortcut' Suffix on New Icons" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>

       <!-- Group 5: Privacy & Diagnostics (4 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="5. Privacy &amp; Tracking" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkDisableAdvertisingID" Content="20. Disable Windows Advertising ID" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableLocationTracking" Content="21. Disable Master Location Tracking" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableFeedbackPrompts" Content="22. Disable Windows Feedback Requests" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableTailoredExperiences" Content="23. Disable Diagnostic Tailored Experiences" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>

       <!-- Group 6: Performance & Gaming (4 Tweaks) -->
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="6. Performance &amp; Context Tools" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <CheckBox Name="chkEnableGameMode" Content="24. Enable Windows Game Mode" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableSearchIndexing" Content="25. Optimize Search Service Memory" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkAddTakeOwnership" Content="26. Add 'Take Ownership' to Context Menu" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
         <CheckBox Name="chkDisableHibernation" Content="27. Disable System Hibernation (Free Disk)" Foreground="#E4E4E7" FontSize="14" Margin="0,4"/>
        </StackPanel>
       </Border>
      </WrapPanel>
      </StackPanel>
     </ScrollViewer>
     <Border Grid.Column="1" Background="#3F3F46" Margin="0,8"/>
     <!-- Basic tweaks occupy the right half of the same Customize tab. -->
     <ScrollViewer Grid.Column="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="8,0,4,8">
      <StackPanel Name="BasicTweaksPanel">
       <Border Background="#18181B" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,10,0,12">
        <StackPanel>
         <TextBlock Text="⚡ Windows Tweaks Presets" FontSize="18" FontWeight="Bold" Foreground="#10B981"/>
         <TextBlock Text="Choose a preset to pre-select options. Nothing runs until you press Apply." Foreground="#A1A1AA" TextWrapping="Wrap" Margin="0,4,0,10"/>
         <UniformGrid Columns="4" Margin="0,0,0,10">
          <Button Name="BasicPresetEssentialBtn" Content="Essential" Background="#065F46" Foreground="#FFFFFF" BorderBrush="#10B981" Padding="5,9" Margin="2" FontWeight="Bold" ToolTip="Select everyday privacy and convenience options"/>
          <Button Name="BasicPresetMinimalBtn" Content="Minimal" Background="#27272A" Foreground="#E4E4E7" BorderBrush="#52525B" Padding="5,9" Margin="2" FontWeight="Bold" ToolTip="Select a small, conservative set of options"/>
          <Button Name="BasicPresetMediumBtn" Content="Medium" Background="#1E3A8A" Foreground="#FFFFFF" BorderBrush="#3B82F6" Padding="5,9" Margin="2" FontWeight="Bold" ToolTip="Select a balanced set of options"/>
          <Button Name="BasicPresetAdvancedBtn" Content="Advanced" Background="#7F1D1D" Foreground="#FFFFFF" BorderBrush="#EF4444" Padding="5,9" Margin="2" FontWeight="Bold" ToolTip="Select more changes for review before applying"/>
         </UniformGrid>
         <TextBlock Name="BasicPresetStatus" Text="Custom selection — choose a preset or select options below." Foreground="#93C5FD" TextWrapping="Wrap" Margin="2,0,2,4"/>
         <TextBlock Name="BasicSelectionCount" Text="0 selected on right | 0 selected total" Foreground="#A7F3D0" FontSize="12" FontWeight="SemiBold" Margin="2,0,2,8"/>
         <Button Name="CancelAllTweaksBtn" Content="✕ Cancel All / Clear Selections" Background="#3F1D1D" Foreground="#FECACA" BorderBrush="#7F1D1D" Padding="8,7" Margin="0,0,0,7"/>
         <Button Name="ApplyBasicTweaksBtn" Content="⚡ Apply Selected Tweaks" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" FontWeight="Bold" Padding="12,9" HorizontalAlignment="Stretch"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🧹 Everyday cleanup" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btTempFiles" Content="Delete current-user temporary files" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btEmptyRecycleBin" Content="Empty Recycle Bin (confirmation required)" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btClearRecent" Content="Clear recent-file history" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableTips" Content="Turn off Windows tips and suggestions" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🚀 Responsiveness" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btDisableTransparency" Content="Disable transparency effects" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableAnimations" Content="Reduce window animations" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btPowerHigh" Content="Select High Performance power plan (if available)" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btGameMode" Content="Enable Windows Game Mode" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🗂️ File Explorer" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btShowExtensions" Content="Show file extensions" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btShowHidden" Content="Show hidden files" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btThisPC" Content="Open File Explorer to This PC" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableRecent" Content="Hide recent and frequent items" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🔒 Privacy &amp; convenience" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btDisableAds" Content="Disable advertising ID for this user" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableFeedback" Content="Reduce Windows feedback prompts" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableBackground" Content="Disable background apps where policy is supported" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableCortana" Content="Disable Cortana policy (where supported)" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🕵️ WinUtil-style privacy &amp; diagnostics" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btActivityHistory" Content="Disable Activity History uploads (keeps clipboard history)" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btConsumerFeatures" Content="Disable Windows consumer app suggestions" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDeliveryOptimization" Content="Disable peer-to-peer Windows Update delivery" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btTailoredExperiences" Content="Disable diagnostic tailored experiences" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btInputPersonalization" Content="Disable inking &amp; typing personalization" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btLockScreenTips" Content="Disable lock-screen tips and Spotlight suggestions" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🧰 Windows components &amp; behavior" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btDisableTelemetryService" Content="Disable Connected User Experiences service (DiagTrack)" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableGameDVR" Content="Disable Game DVR background capture" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableWebSearch" Content="Disable web results in Windows Search (policy)" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableAppLaunchTracking" Content="Disable app launch tracking" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableWidgets" Content="Hide Widgets button on taskbar" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableHibernation" Content="Disable hibernation (removes hiberfil.sys; confirmation)" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🛡️ Additional privacy &amp; Start menu controls" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btDisableStartAppSuggestions" Content="Disable suggested apps in Start menu" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableSilentInstalls" Content="Disable automatic suggested app installs" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableSoftLanding" Content="Disable Windows tips and welcome experience" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableSettingsSuggestions" Content="Disable suggestions in Settings" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableSyncNotifications" Content="Hide File Explorer sync-provider notifications" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableOnlineSpeech" Content="Turn off online speech recognition for this user" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableHandwritingData" Content="Stop handwriting personalization data collection" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="12" Margin="0,0,0,10">
        <StackPanel>
         <TextBlock Text="🗂️ Explorer &amp; device behavior" FontSize="16" FontWeight="Bold" Foreground="#60A5FA" Margin="0,0,0,8"/>
         <CheckBox Name="btShowFullPath" Content="Show full path in File Explorer title bar" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableAutoPlay" Content="Disable AutoPlay for removable drives" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableRecentDocsTracking" Content="Stop Windows from tracking recently opened documents" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableSearchHighlights" Content="Disable search highlights and web suggestions policy" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btUseCompactExplorer" Content="Use compact view in File Explorer" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableLockScreenCamera" Content="Disable lock-screen camera access for this user" Foreground="#E4E4E7" Margin="0,5"/>
         <CheckBox Name="btDisableLockScreenSlideShow" Content="Disable lock-screen slideshow" Foreground="#E4E4E7" Margin="0,5"/>
        </StackPanel>
       </Border>
       <TextBlock Text="Preset selections are inspired by WinUtil categories, but are not claimed to be an exact copy of its live presets. Review all selected changes. Some policies vary by Windows edition/version; service and hibernation changes may affect features and require restart." Foreground="#FBBF24" TextWrapping="Wrap" Margin="2,0,2,12"/>
      </StackPanel>
     </ScrollViewer>
    </Grid>
   </TabItem>

   <!-- CLEANUP -->
   <TabItem Header="Cleanup">
    <Grid Margin="18">
     <Grid.ColumnDefinitions><ColumnDefinition Width="1.08*"/><ColumnDefinition Width="0.92*"/></Grid.ColumnDefinitions>
     <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
     <StackPanel Grid.Row="0" Grid.ColumnSpan="2" Margin="2,0,2,16">
      <TextBlock Text="CLEANUP CENTER" FontSize="21" FontWeight="Bold" Foreground="#F4F4F5"/>
      <TextBlock Text="Review safe cleanup candidates on the left, and run disk diagnostics on the right." FontSize="12" Foreground="#A1A1AA" Margin="0,4,0,0"/>
     </StackPanel>
     <Border Grid.Row="1" Grid.Column="0" Background="#19191F" BorderBrush="#34343D" BorderThickness="1" CornerRadius="12" Padding="14" Margin="0,0,9,0">
      <Grid>
       <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
       <Grid Grid.Row="0" Margin="0,0,0,10">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel>
         <TextBlock Text="SAFE CLEANUP" FontSize="14" FontWeight="SemiBold" Foreground="#E4E4E7"/>
         <TextBlock Name="CleanupScanSummary" Text="No scan performed yet." Foreground="#A1A1AA" FontSize="11" Margin="0,3,0,0" TextWrapping="Wrap"/>
        </StackPanel>
        <Button Name="CleanupScanBtn" Grid.Column="1" Content="Scan Now" Width="105" Height="32" Background="#263B36" Foreground="#A7F3D0" BorderBrush="#36594D"/>
       </Grid>
       <TextBlock Grid.Row="1" Text="Select the categories you want to review" FontSize="11" Foreground="#A1A1AA" Margin="0,0,0,8"/>
       <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
        <StackPanel>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupUserTempCheck" Content="User temporary files" FontWeight="SemiBold"/><TextBlock Text="Temporary files in your Windows user profile." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupUserTempInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupWindowsTempCheck" Content="Windows temporary files" FontWeight="SemiBold"/><TextBlock Text="Temporary files under the Windows Temp folder." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupWindowsTempInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupUpdateCheck" Content="Windows Update download cache" FontWeight="SemiBold"/><TextBlock Text="Downloaded update files; service is paused only during cleanup." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupUpdateInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupWerCheck" Content="Windows error reports" FontWeight="SemiBold"/><TextBlock Text="Archived and queued Windows Error Reporting files." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupWerInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupShaderCheck" Content="DirectX shader cache" FontWeight="SemiBold"/><TextBlock Text="Temporary graphics cache; Windows and apps can rebuild it." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupShaderInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
         <Border Background="#202027" BorderBrush="#383842" BorderThickness="1" CornerRadius="8" Padding="10" Margin="0,0,0,7"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><CheckBox Name="CleanupDeliveryCheck" Content="Delivery Optimization cache" FontWeight="SemiBold"/><TextBlock Text="Cached update delivery files that Windows can download again." Foreground="#A1A1AA" FontSize="11" Margin="22,3,0,0"/></StackPanel><TextBlock Name="CleanupDeliveryInfo" Grid.Column="1" Text="Not scanned" Foreground="#A1A1AA" VerticalAlignment="Center" Margin="8,0,0,0" FontSize="10"/></Grid></Border>
        </StackPanel>
       </ScrollViewer>
       <StackPanel Grid.Row="3" Margin="0,10,0,8">
        <ProgressBar Name="CleanupProgress" Height="7" Minimum="0" Maximum="100" Value="0" Background="#292933" Foreground="#6FC6A5"/>
        <Grid Margin="0,5,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBlock Name="CleanupProgressText" Text="Ready" Foreground="#A1A1AA" FontSize="11"/><TextBlock Name="CleanupSelectedSummary" Grid.Column="1" Text="Selected: 0 files • 0 MB" Foreground="#8BDCC5" FontSize="11" FontWeight="SemiBold"/></Grid>
       </StackPanel>
       <Button Name="CleanupRunBtn" Grid.Row="4" Content="Clean Selected" Height="36" HorizontalAlignment="Stretch" Background="#28483E" Foreground="#C7F9E8" BorderBrush="#416B5D" IsEnabled="False"/>
      </Grid>
     </Border>
     <Border Grid.Row="1" Grid.Column="1" Background="#19191F" BorderBrush="#34343D" BorderThickness="1" CornerRadius="12" Padding="14" Margin="9,0,0,0">
      <Grid>
       <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
       <StackPanel Grid.Row="0" Margin="0,0,0,12">
        <TextBlock Text="DISK TOOLS &amp; DIAGNOSTICS" FontSize="14" FontWeight="SemiBold" Foreground="#E4E4E7"/>
        <TextBlock Text="Analysis tools are read-only unless a clearly marked repair action is selected." FontSize="11" Foreground="#A1A1AA" TextWrapping="Wrap" Margin="0,4,0,0"/>
       </StackPanel>
       <StackPanel Grid.Row="1">
        <Button Name="CleanupDriveAnalyzeBtn" Content="Analyze Drives" Height="36" Margin="0,0,0,8" Background="#293746" Foreground="#C7DDF5" BorderBrush="#40566D" HorizontalContentAlignment="Left" Padding="12,0"/>
        <Button Name="CleanupComponentAnalyzeBtn" Content="Analyze Windows Components" Height="36" Margin="0,0,0,8" Background="#343044" Foreground="#DDD2F5" BorderBrush="#51466A" HorizontalContentAlignment="Left" Padding="12,0"/>
        <Button Name="CleanupComponentRunBtn" Content="Clean Component Store (DISM)" Height="36" Margin="0,0,0,12" Background="#493B2B" Foreground="#F4DFC0" BorderBrush="#70583A" HorizontalContentAlignment="Left" Padding="12,0" IsEnabled="False"/>
       </StackPanel>
       <Grid Grid.Row="2">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="ANALYSIS REPORT" FontSize="11" FontWeight="SemiBold" Foreground="#A1A1AA" Margin="0,0,0,7"/>
        <TextBox Name="CleanupAdvancedReport" Grid.Row="1" Text="Advanced analysis has not been run." IsReadOnly="True" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Background="#111116" Foreground="#D4D4D8" BorderBrush="#383842" Padding="10"/>
       </Grid>
      </Grid>
     </Border>
    </Grid>
   </TabItem>

   <!-- 9. BACKUP -->
   <TabItem Header="Optimize">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
     <Border Padding="20">
      <StackPanel>
       <TextBlock Text="System Optimization Engine" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
       <TextBlock Text="50 optimization tools for performance, startup, storage, maintenance, and Windows settings." Foreground="#AEB8C8" TextWrapping="Wrap" Margin="0,0,0,12"/>
       <TextBox Name="OptSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search optimization tools by name or keyword" Margin="0,0,0,8"/>
       <ComboBox Name="OptCategoryFilter" Height="34" Padding="8,4" FontSize="14" Margin="0,0,0,8" SelectedIndex="0">
        <ComboBoxItem Content="⚙️ All Categories"/>
        <ComboBoxItem Content="⚙️ Performance &amp; Power"/>
        <ComboBoxItem Content="⚙️ Startup &amp; Background"/>
        <ComboBoxItem Content="⚙️ Storage &amp; Cleanup"/>
        <ComboBoxItem Content="⚙️ Windows Maintenance"/>
        <ComboBoxItem Content="⚙️ Network &amp; Responsiveness"/>
        <ComboBoxItem Content="⚙️ Privacy &amp; Features"/>
        <ComboBoxItem Content="⚙️ Diagnostics &amp; Monitoring"/>
       </ComboBox>
       <TextBlock Name="OptResultsCount" Foreground="#AEB8C8" Margin="0,0,0,10"/>
       <UniformGrid Name="OptToolsGrid" Columns="2"/>
      </StackPanel>
     </Border>
    </ScrollViewer>
   </TabItem>

   <!-- 5. SECURITY -->
   <TabItem Header="Security">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
     <Border Padding="20">
      <StackPanel>
       <TextBlock Text="Security &amp; Privacy Console" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
       <TextBlock Text="50 security and privacy tools for protection, firewall, accounts, privacy, and auditing." Foreground="#AEB8C8" TextWrapping="Wrap" Margin="0,0,0,12"/>
       <TextBox Name="SecSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search security tools by name or keyword" Margin="0,0,0,8"/>
       <ComboBox Name="SecCategoryFilter" Height="34" Padding="8,4" FontSize="14" Margin="0,0,0,8" SelectedIndex="0">
        <ComboBoxItem Content="🛡️ All Categories"/>
        <ComboBoxItem Content="🛡️ Defender &amp; Antivirus"/>
        <ComboBoxItem Content="🛡️ Firewall &amp; Network"/>
        <ComboBoxItem Content="🛡️ Privacy &amp; Tracking"/>
        <ComboBoxItem Content="🛡️ Accounts &amp; Sign-in"/>
        <ComboBoxItem Content="🛡️ Encryption &amp; Protection"/>
        <ComboBoxItem Content="🛡️ Auditing &amp; Reports"/>
        <ComboBoxItem Content="🛡️ Security Settings"/>
       </ComboBox>
       <TextBlock Name="SecResultsCount" Foreground="#AEB8C8" Margin="0,0,0,10"/>
       <UniformGrid Name="SecToolsGrid" Columns="2"/>
      </StackPanel>
     </Border>
    </ScrollViewer>
   </TabItem>

   <!-- 6. SYSTEM -->
   <TabItem Header="System">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Advanced System Configuration" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
      <TextBlock Text="50 system tools for performance, startup, recovery, diagnostics, services, and configuration." Foreground="#AEB8C8" TextWrapping="Wrap" Margin="0,0,0,12"/>
      <TextBox Name="SysSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search system tools by name or keyword" Margin="0,0,0,8"/>
      <ComboBox Name="SysCategoryFilter" Height="32" Margin="0,0,0,8" SelectedIndex="0">
       <ComboBoxItem Content="⚙️ All Categories"/><ComboBoxItem Content="⚙️ Performance &amp; Power"/><ComboBoxItem Content="⚙️ Startup &amp; Boot"/><ComboBoxItem Content="⚙️ Recovery &amp; Repair"/><ComboBoxItem Content="⚙️ Diagnostics &amp; Reports"/><ComboBoxItem Content="⚙️ Services &amp; Processes"/><ComboBoxItem Content="⚙️ Windows Settings"/><ComboBoxItem Content="⚙️ Storage &amp; Devices"/><ComboBoxItem Content="⚙️ Security &amp; Maintenance"/>
      </ComboBox>
      <TextBlock Name="SysResultsCount" Text="50 system tools" Foreground="#AEB8C8" Margin="0,0,0,12"/>
      <UniformGrid Name="SysToolsGrid" Columns="2"/>
     </StackPanel>
    </Border>
   </ScrollViewer>
   </TabItem>

   <!-- 7. NETWORK -->
   <TabItem Header="Network">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
     <Border Padding="20">
      <StackPanel>
       <TextBlock Text="Network Diagnostic &amp; Repair Center" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,8"/>
       <TextBlock Text="Search, diagnose, inspect, and repair common Windows networking issues." Foreground="#AEB8C8" TextWrapping="Wrap" Margin="0,0,0,12"/>
       <TextBox Name="NetSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search network tools by name or keyword" Margin="0,0,0,8"/>
       <ComboBox Name="NetCategoryFilter" Height="32" Margin="0,0,0,8" SelectedIndex="0">
        <ComboBoxItem Content="All Categories"/><ComboBoxItem Content="Diagnostics"/><ComboBoxItem Content="DNS &amp; IP"/><ComboBoxItem Content="Repair &amp; Reset"/><ComboBoxItem Content="Adapters &amp; Wi-Fi"/><ComboBoxItem Content="Connections &amp; Ports"/><ComboBoxItem Content="Reports &amp; Settings"/>
       </ComboBox>
       <TextBlock Name="NetResultsCount" Text="50 network tools" Foreground="#AEB8C8" Margin="0,0,0,12"/>
       <UniformGrid Name="NetToolsGrid" Columns="2"/>
      </StackPanel>
     </Border>
    </ScrollViewer>
   </TabItem>

   <!-- 8. CLEANUP -->
   <TabItem Header="Backup">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
     <Border Padding="20">
      <StackPanel>
       <TextBlock Text="Backup &amp; Recovery Center" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,10"/>
       <TextBlock Text="Export important system settings and recovery information. Exports are saved under ProgramData\AMR-Utility\Backups." Foreground="#AEB8C8" TextWrapping="Wrap" Margin="0,0,0,12"/>
       <TextBox Name="BackupSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search backup actions" Margin="0,0,0,8"/>
       <ComboBox Name="BackupCategoryFilter" Height="32" Margin="0,0,0,8" SelectedIndex="0">
        <ComboBoxItem Content="All Categories"/>
        <ComboBoxItem Content="Recovery"/><ComboBoxItem Content="Registry &amp; System"/><ComboBoxItem Content="Drivers &amp; Hardware"/><ComboBoxItem Content="Network"/><ComboBoxItem Content="Security"/><ComboBoxItem Content="Configuration &amp; Reports"/>
       </ComboBox>
       <TextBlock Name="BackupResultsCount" Text="50 backup actions" Foreground="#AEB8C8" Margin="0,0,0,10"/>
       <UniformGrid Name="BackupActionsGrid" Columns="2"/>
      </StackPanel>
     </Border>
    </ScrollViewer>
   </TabItem>

   <!-- 10. UTILITIES -->
   <TabItem Header="Utilities">
    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" CanContentScroll="True">
     <Border Padding="20">
      <StackPanel>
      <TextBlock Text="Quick Administration Utilities" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,12"/>
      <DockPanel Margin="0,0,0,16" LastChildFill="True">
       <ComboBox Name="UtilCategoryFilter" Width="230" Height="34" Margin="0,0,12,0" SelectedIndex="0" VerticalContentAlignment="Center">
        <ComboBoxItem Content="All Categories"/>
        <ComboBoxItem Content="System &amp; Performance"/>
        <ComboBoxItem Content="Hardware &amp; Devices"/>
        <ComboBoxItem Content="Network &amp; Security"/>
        <ComboBoxItem Content="Administration"/>
        <ComboBoxItem Content="Troubleshooting &amp; Recovery"/>
       </ComboBox>
       <TextBox Name="UtilSearchBox" Height="34" Padding="10,5" FontSize="14" ToolTip="Search Utilities by name or keyword" Text=""/>
      </DockPanel>
      <TextBlock Name="UtilResultsCount" Text="50 utilities" Foreground="#AEB8C8" Margin="0,0,0,12"/>
      <WrapPanel Name="UtilButtonsPanel" Orientation="Horizontal">
       <Button Name="UtilControlPanelBtn" Content="🛠 Open Classic Control Panel" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilRegeditBtn" Content="🛠 Open Registry Editor" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDevMgmtBtn" Content="🛠 Open Device Manager" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilSysInfoBtn" Content="🛠 Open System Information" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilTaskMgrBtn" Content="🛠 Open Task Manager" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilServicesBtn" Content="🛠 Open Services" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilEventViewerBtn" Content="🛠 Open Event Viewer" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilResourceMonitorBtn" Content="🛠 Open Resource Monitor" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilPerformanceMonitorBtn" Content="🛠 Open Performance Monitor" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDiskMgmtBtn" Content="🛠 Open Disk Management" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilComputerMgmtBtn" Content="🛠 Open Computer Management" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilTaskSchedulerBtn" Content="🛠 Open Task Scheduler" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilFirewallAdvancedBtn" Content="🛠 Open Advanced Firewall" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilNetworkConnectionsBtn" Content="🛠 Open Network Connections" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilSystemPropertiesBtn" Content="🛠 Open System Properties" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilProgramsFeaturesBtn" Content="🛠 Open Programs and Features" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilWindowsFeaturesBtn" Content="🛠 Open Windows Features" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilPowerOptionsBtn" Content="🛠 Open Power Options" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilSoundBtn" Content="🛠 Open Sound Settings" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilMemoryDiagnosticBtn" Content="🛠 Open Windows Memory Diagnostic" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilCertificatesBtn" Content="🛠 Open Certificate Manager" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilCredentialManagerBtn" Content="🛠 Open Credential Manager" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilGroupPolicyBtn" Content="🛠 Open Local Group Policy" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilLocalUsersBtn" Content="🛠 Open Local Users and Groups" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilTPMBtn" Content="🛠 Open TPM Management" Tag="Network &amp; Security" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilSystemConfigBtn" Content="🛠 Open System Configuration" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilAboutWindowsBtn" Content="🛠 About Windows" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilAdvancedStartupBtn" Content="🛠 Advanced Startup Options" Tag="Troubleshooting &amp; Recovery" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilRecoveryBtn" Content="🛠 Recovery Options" Tag="Troubleshooting &amp; Recovery" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilWindowsUpdateBtn" Content="🛠 Windows Update" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilStorageSettingsBtn" Content="🛠 Storage Settings" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilAppsSettingsBtn" Content="🛠 Installed Apps" Tag="Administration" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilPrivacySettingsBtn" Content="🛠 Privacy Settings" Tag="Network &amp; Security" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilProxySettingsBtn" Content="🛠 Proxy Settings" Tag="Network &amp; Security" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilBluetoothBtn" Content="🛠 Bluetooth Settings" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDisplaySettingsBtn" Content="🛠 Display Settings" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilMouseSettingsBtn" Content="🛠 Mouse Settings" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilKeyboardSettingsBtn" Content="🛠 Keyboard Settings" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilPrintersBtn" Content="🛠 Printers &amp; Scanners" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDateTimeBtn" Content="🛠 Date &amp; Time Settings" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilRegionBtn" Content="🛠 Region Settings" Tag="Administration" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilEnvVariablesBtn" Content="🛠 Environment Variables" Tag="Administration" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilWindowsDefenderBtn" Content="🛠 Windows Security" Tag="Network &amp; Security" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilReliabilityBtn" Content="🛠 Reliability Monitor" Tag="Troubleshooting &amp; Recovery" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilStepsRecorderBtn" Content="🛠 Steps Recorder (if available)" Tag="Troubleshooting &amp; Recovery" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDiskCleanupBtn" Content="🛠 Disk Cleanup" Tag="Troubleshooting &amp; Recovery" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilNetworkResetBtn" Content="🛠 Network Status" Tag="Network &amp; Security" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilIndexingBtn" Content="🛠 Indexing Options" Tag="System &amp; Performance" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilFontsBtn" Content="🛠 Fonts" Tag="Administration" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilColorMgmtBtn" Content="🛠 Color Management" Tag="Hardware &amp; Devices" Width="260" Margin="0,0,15,15"/>
      </WrapPanel>
      </StackPanel>
     </Border>
    </ScrollViewer>
   </TabItem>

   <!-- 11. LOGS -->
   <TabItem Header="Logs">
    <Border Padding="15">
     <Grid>
      <Grid.RowDefinitions>
       <RowDefinition Height="Auto"/>
       <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      
      <Grid Grid.Row="0" Margin="0,0,0,10">
       <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
       </Grid.ColumnDefinitions>
       <StackPanel Grid.Column="0">
        <TextBlock Text="Detailed System &amp; Component Log Suite" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="Real-time categorized execution trace and diagnostic console." Foreground="#A1A1AA" FontSize="13" Margin="0,2,0,0"/>
       </StackPanel>
       <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
        <Button Name="ExportLogsBtn" Content="💾 Export Log File" Background="#2563EB" Foreground="#FFFFFF" BorderThickness="0" Margin="0,0,10,0"/>
        <Button Name="ClearAllLogsBtn" Content="🗑 Clear All Consoles" Background="#3F3F46" Foreground="#FFFFFF" BorderThickness="0"/>
       </StackPanel>
      </Grid>
      
      <TabControl Grid.Row="1" Background="#18181B">
       <TabItem Header="🌐 All Logs">
        <TextBox Name="LogConsoleAll" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#10B981" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
       <TabItem Header="⚙️ System &amp; Utility">
        <TextBox Name="LogConsoleSystem" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#3B82F6" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
       <TabItem Header="📊 Overview">
        <TextBox Name="LogConsoleOverview" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#F59E0B" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
       <TabItem Header="📦 Software Engine">
        <TextBox Name="LogConsoleSoftware" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#EC4899" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
       <TabItem Header="⚡ Customize Engine">
        <TextBox Name="LogConsoleCustomize" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#8B5CF6" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
       <TabItem Header="🧹 Cleanup Logs">
        <TextBox Name="LogConsoleCleanup" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" Background="#09090B" Foreground="#22D3EE" FontFamily="Consolas" FontSize="13" Padding="15" AcceptsReturn="True"/>
       </TabItem>
      </TabControl>
     </Grid>
    </Border>
   </TabItem>

   <!-- 12. ABOUT -->
   <TabItem Header="About">
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="20">
     <StackPanel HorizontalAlignment="Center" Width="800">
      <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="12" Padding="25" Margin="0,0,0,20">
       <StackPanel HorizontalAlignment="Center">
        <TextBlock Text="Amr | windows_utility" FontSize="28" FontWeight="Bold" Foreground="#3B82F6" HorizontalAlignment="Center"/>
        <TextBlock Text="V0.1" FontSize="14" Foreground="#10B981" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,5,0,10"/>
        <TextBlock Text="A comprehensive Windows management, telemetry and optimization suite designed for smooth execution and quiet app deployment." Foreground="#A1A1AA" FontSize="14" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
       </StackPanel>
      </Border>

      <WrapPanel Orientation="Horizontal" HorizontalAlignment="Center">
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="12" Padding="20" Margin="10" Width="360">
        <StackPanel>
         <TextBlock Text="Developer Details" FontSize="18" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,15"/>
         <StackPanel Margin="0,4">
          <TextBlock Text="Developer Name:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="Amr Ahmed Abdel Fattah" Foreground="#FFFFFF" FontSize="15" FontWeight="SemiBold" Margin="0,2,0,0"/>
         </StackPanel>
         <StackPanel Margin="0,8,0,4">
          <TextBlock Text="Phone &amp; WhatsApp:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="01014716301" Foreground="#10B981" FontSize="15" FontWeight="Bold" Margin="0,2,0,0"/>
         </StackPanel>
         <StackPanel Margin="0,8,0,0">
          <TextBlock Text="Email Address:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="3mr10aa@gmail.com" Foreground="#3B82F6" FontSize="14" FontWeight="SemiBold" Margin="0,2,0,0"/>
         </StackPanel>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="12" Padding="20" Margin="10" Width="360">
        <StackPanel>
         <TextBlock Text="System &amp; Build Info" FontSize="18" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,15"/>
         <StackPanel Margin="0,4">
          <TextBlock Text="Environment:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="PowerShell 5.1 &amp; WPF (XAML)" Foreground="#FFFFFF" FontSize="14" FontWeight="SemiBold" Margin="0,2,0,0"/>
         </StackPanel>
         <StackPanel Margin="0,8,0,4">
          <TextBlock Text="Last Updated:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="06 / 11 / 2026" Foreground="#EAB308" FontSize="14" FontWeight="Bold" Margin="0,2,0,0"/>
         </StackPanel>
         <StackPanel Margin="0,8,0,0">
          <TextBlock Text="License &amp; Edition:" Foreground="#71717A" FontSize="13"/>
          <TextBlock Text="Personal Utility (All Rights Reserved)" Foreground="#A1A1AA" FontSize="13" Margin="0,2,0,0"/>
         </StackPanel>
        </StackPanel>
       </Border>
      </WrapPanel>

      <TextBlock Text="Built with precision for clean Windows administration." Foreground="#52525B" FontSize="13" HorizontalAlignment="Center" Margin="0,20,0,0"/>
     </StackPanel>
    </ScrollViewer>
   </TabItem>

  </TabControl>
  
  <Border Grid.Row="2" Background="#18181B" BorderBrush="#27272A" BorderThickness="0,1,0,0" Padding="15">
   <TextBlock Name="StatusText" Text="Ready" Foreground="#A1A1AA" FontSize="13"/>
  </Border>
 </Grid>
</Window>
'@

# --- 5. Window & Controls Mapping ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$script:Window = [Windows.Markup.XamlReader]::Load($reader)

function C { param([string]$Name) return $script:Window.FindName($Name) }

$script:Status        = C 'StatusText'
$script:ProgressBar   = C 'InstallProgressBar'
$script:ProgressText  = C 'ProgressText'
$script:LogControls['All']       = C 'LogConsoleAll'
$script:LogControls['System']    = C 'LogConsoleSystem'
$script:LogControls['Overview']  = C 'LogConsoleOverview'
$script:LogControls['Software']  = C 'LogConsoleSoftware'
$script:LogControls['Customize'] = C 'LogConsoleCustomize'
$script:LogControls['Cleanup']   = C 'LogConsoleCleanup'

# Logs Tab Actions
(C 'ClearAllLogsBtn').Add_Click({
    foreach ($ctl in $script:LogControls.Values) {
        if ($ctl) { $ctl.Text = "" }
    }
    Write-AMRLog "All log consoles cleared." INFO System
})

(C 'ExportLogsBtn').Add_Click({
    try {
        $exportPath = Join-Path $script:ExportDir ("AMR_Log_Export_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        Copy-Item -Path $script:LogFile -Destination $exportPath -Force
        Show-AMRMessage "Log exported successfully to:`n$exportPath" "Export Complete" OK Information | Out-Null
        Write-AMRLog "Exported log file to: $exportPath" SUCCESS System
    } catch {
        Show-AMRMessage "Failed to export logs: $_" "Export Error" OK Error | Out-Null
    }
})

# --- 6. OVERVIEW TELEMETRY ENGINE ---
function Update-AMROverviewData {
    # UI-safe Overview refresh: registry/environment only.
    # Deliberately avoids synchronous CIM/WMI, DNS, drive enumeration,
    # Defender/TPM providers and network queries on the WPF dispatcher.
    try {
        (C 'ovOS').Text = "OS: " + [Environment]::OSVersion.VersionString
        (C 'ovArch').Text = "Architecture: " + $(if ([Environment]::Is64BitOperatingSystem) {'64-bit'} else {'32-bit'})
        (C 'ovPCName').Text = "PC Name: " + [Environment]::MachineName
        (C 'ovDeviceType').Text = "Device Type: " + $(if ($env:SESSIONNAME -match 'RDP') {'Remote session'} else {'Computer'})
    } catch {}

    try {
        $cpuName = (Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name ProcessorNameString -ErrorAction Stop).ProcessorNameString
        (C 'ovCPU').Text = 'CPU: ' + $cpuName.Trim()
    } catch { (C 'ovCPU').Text = 'CPU: Information unavailable' }
    (C 'ovCPULoad').Text = 'CPU Usage: Open Task Manager for live usage'
    (C 'ovGPU').Text = 'GPU: See Device Manager for adapter details'

    # Avoid Get-CimInstance here: provider startup can stall the WPF UI.
    (C 'ovRAMTotal').Text = 'Total RAM: Open Task Manager for hardware details'
    (C 'ovRAMUsage').Text = 'RAM Usage: Open Task Manager for live usage'

    $osKey = $null
    try { $osKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop } catch {}
    try {
        $board = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -ErrorAction Stop
        (C 'ovMobo').Text = "Board: $($board.BaseBoardManufacturer) $($board.BaseBoardProduct)"
        (C 'ovBIOS').Text = "BIOS Version: $($board.BIOSVersion -join ' ')"
        (C 'ovBIOSDate').Text = "BIOS Date: $($board.BIOSReleaseDate -join ' ')"
    } catch {
        (C 'ovMobo').Text = 'Board: Information unavailable'
        (C 'ovBIOS').Text = 'BIOS Version: Information unavailable'
        (C 'ovBIOSDate').Text = 'BIOS Date: Information unavailable'
    }

    # DriveInfo and DNS lookups can block on sleeping/disconnected devices.
    # Keep these cards informative without performing blocking calls.
    try { (C 'ovDisks').ItemsSource = @([PSCustomObject]@{DisplayText='Storage details: Open This PC to view drive capacity'}) } catch {}
    (C 'ovIP').Text = 'IPv4 Address: Open Network Settings for connection details'

    (C 'ovUptime').Text = 'System Uptime: Open Task Manager for live details'
    (C 'ovProcesses').Text = 'Running Processes: Open Task Manager for live count'
    (C 'ovThreads').Text = 'CPU Cores / Threads: See Task Manager'
    (C 'ovRAMAvailable').Text = 'Available RAM: See Task Manager'
    try {
        if ($osKey) { (C 'ovBuild').Text = "Windows Build: $($osKey.CurrentBuildNumber) (Version $($osKey.DisplayVersion))" }
        else { (C 'ovBuild').Text = 'Windows Build: See Settings' }
    } catch { (C 'ovBuild').Text = 'Windows Build: Information unavailable' }
    (C 'ovLastBoot').Text = 'Last Boot: Open Task Manager for uptime details'
    (C 'ovDisplay').Text = 'Display: See Settings > System > Display'
    (C 'ovGPUDetails').Text = 'Graphics Memory: See Task Manager > Performance'

    # Provider-backed health checks are intentionally not run on the UI thread.
    (C 'ovDefender').Text = 'Microsoft Defender: Open Windows Security'
    (C 'ovFirewall').Text = 'Windows Firewall: Open Windows Security'
    (C 'ovTPM').Text = 'TPM: Open Windows Security > Device Security'
    (C 'ovSecureBoot').Text = 'Secure Boot: Check System Information (msinfo32)'
    (C 'ovWindowsActivation').Text = 'Windows Activation: Check Settings > Activation'
    (C 'ovBatteryCard').Visibility = 'Collapsed'
    (C 'ovNetworkAdapter').Text = 'Adapter: Open Settings > Network & Internet'
    (C 'ovGatewayDNS').Text = 'Gateway / DNS: Open Network Settings for details'
    (C 'ovLinkSpeed').Text = 'Link Speed: Open Network Settings for details'
    (C 'ovUpdate').Text = 'Latest Installed Update: Check Settings > Windows Update'
    (C 'ovLastRefresh').Text = 'Last updated: ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-AMRLog 'Overview refreshed using non-blocking local information only.' SUCCESS Overview
}

function Refresh-AMROverview {
    $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($wg) {
        (C 'WingetHeader').Text = 'WINGET ENGINE READY'
    } else {
        (C 'WingetHeader').Text = 'WINGET NOT FOUND'
    }
    Update-AMROverviewData
}

(C 'RefreshOverviewBtn').Add_Click({
    $btn = C 'RefreshOverviewBtn'
    if (-not (Get-Variable -Name OverviewRefreshing -Scope Script -ErrorAction SilentlyContinue)) { $script:OverviewRefreshing = $false }
    if ($script:OverviewRefreshing) { return }
    $script:OverviewRefreshing = $true
    $btn.IsEnabled = $false
    $btn.Content = 'Refreshing…'
    try {
        Update-AMROverviewData
    } finally {
        $btn.Content = '↻ Refresh'
        $btn.IsEnabled = $true
        $script:OverviewRefreshing = $false
    }
})

# ==========================================================
# 7. HIGH-PERFORMANCE MULTI-TIER ENGINE (SAFE POWERSHELL 5.1 RUNSPACE)
# ==========================================================

$script:AppsView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:SoftwareCatalog)
$script:AppsView.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription("Category")))

$script:AppsView.Filter = [System.Predicate[object]]{
    param($item)
    $searchText = (C 'SearchBox').Text
    if ([string]::IsNullOrWhiteSpace($searchText)) { return $true }
    $escaped = [regex]::Escape($searchText)
    return ($item.Name -match "(?i)$escaped") -or ($item.Id -match "(?i)$escaped")
}

(C 'SearchBox').Add_TextChanged({ $script:AppsView.Refresh() })
(C 'SoftwareGrid').ItemsSource = $script:AppsView

(C 'DeselectAllBtn').Add_Click({
    if ($script:InstallRunning) {
        Write-AMRLog "Cannot clear selection while an installation queue is running." WARNING Software
        return
    }
    foreach ($app in $script:SoftwareCatalog) { $app.IsSelected = $false }
    $script:AppsView.Refresh()
    Write-AMRLog "Cleared app selections." INFO Software
})

# Shared engine state
$script:InstallRunning = $false
$script:InstallPowerShell = $null
$script:InstallRunspace = $null
$script:InstallAsyncResult = $null
$script:InstallOutput = $null
$script:InstallResultQueue = $null
$script:InstallLogQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$script:InstallTimer = $null
$script:InstallActionName = ''
$script:InstallSelectedSnapshot = @()

# Worker code runs in dedicated Runspace & reports progress
$script:InstallWorkerCode = @'
param(
    [object[]]$Apps,
    [string]$ActionCommand,
    [string]$ActionName,
    [bool]$Interactive,
    [string]$DownloadDir,
    [System.Collections.Concurrent.ConcurrentQueue[string]]$LogQueue,
    [System.Collections.Concurrent.ConcurrentQueue[object]]$ResultQueue
)

$ErrorActionPreference = "Stop"
$script:ChocoCheckedPath = $null

function Write-WorkerLog {
    param([string]$Message, [string]$Level = "INFO", [int]$Percent = -1)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $pctPrefix = if ($Percent -ge 0) { "PROG:$Percent|" } else { "" }
    [void]$LogQueue.Enqueue("${pctPrefix}[$stamp] [$Level] [Software] $Message")
}

function Test-WorkerInstalled {
    param(
        [string]$AppName,
        [string]$AppId = '',
        [string]$ChocoId = ''
    )

    if ([string]::IsNullOrWhiteSpace($AppName)) { return $false }

    # 1. Direct Winget Verification (High Precision)
    if (-not [string]::IsNullOrWhiteSpace($AppId)) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($winget) {
            try {
                $checkCmd = & $winget.Source list --id $AppId --exact --accept-source-agreements 2>$null
                if ($LASTEXITCODE -eq 0 -and $checkCmd -match [regex]::Escape($AppId)) {
                    return $true
                }
            } catch {}
        }
    }

    # 2. Strict Windows Registry Verification
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    try {
        $cleanTarget = ($AppName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
        $cleanId     = if ($AppId) { ($AppId -replace "[^a-zA-Z0-9]", "").ToLowerInvariant() } else { '' }
        $cleanChoco  = if ($ChocoId) { ($ChocoId -replace "[^a-zA-Z0-9]", "").ToLowerInvariant() } else { '' }

        foreach ($item in @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue)) {
            $displayName = [string]$item.DisplayName
            $childName   = [string]$item.PSChildName
            if ([string]::IsNullOrWhiteSpace($displayName)) { continue }

            $candidate      = ($displayName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
            $candidateChild = ($childName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()

            # Exact Matches
            if ($candidate -eq $cleanTarget) { return $true }
            if ($cleanId -and ($candidate -eq $cleanId -or $candidateChild -eq $cleanId)) { return $true }
            if ($cleanChoco -and ($candidate -eq $cleanChoco -or $candidateChild -eq $cleanChoco)) { return $true }

            # No prefix matching: similarly named applications must not count as installed.
        }
    } catch {}
    return $false
}

function Resolve-WorkerWingetId {
    param([string]$AppName, [string]$ConfiguredId)

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { return $ConfiguredId }

    # First trust the catalog ID when Winget can see that exact installed package.
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredId)) {
        try {
            $byId = & $winget.Source list --id $ConfiguredId --exact --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0 -and ($byId -join "`n") -match [regex]::Escape($ConfiguredId)) {
                return $ConfiguredId
            }
        } catch {}
    }

    # Catalog IDs can change or differ from the ID used by an already-installed package.
    # Resolve the exact display name to the installed Winget ID before upgrade/repair.
    if ([string]::IsNullOrWhiteSpace($AppName)) { return $ConfiguredId }
    try {
        $listed = @(& $winget.Source list --name $AppName --exact --accept-source-agreements 2>$null)
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in $listed) {
                $text = ([string]$line).Trim()
                # Winget table columns can be separated by only one space when a name fills its column.
                # Since --name --exact was used, parse the ID immediately after the exact display name.
                if ($text.StartsWith($AppName.Trim(), [StringComparison]::OrdinalIgnoreCase)) {
                    $tail = $text.Substring($AppName.Trim().Length).TrimStart()
                    $columns = @($tail -split '\s+')
                    if ($columns.Count -ge 2 -and $columns[0] -and $columns[0] -notin @('Id','Version')) {
                        Write-WorkerLog "Resolved installed Winget ID for ${AppName}: $($columns[0])" "INFO"
                        return [string]$columns[0]
                    }
                }
            }
        }
    } catch {}
    return $ConfiguredId
}

function Invoke-WorkerMsiRepair {
    param([string]$AppName, [bool]$Interactive, [int]$BasePercent)

    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $entry = $null
    try {
        $entry = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and ([string]$_.DisplayName).Trim() -ieq $AppName.Trim() -and $_.WindowsInstaller -eq 1 } |
            Select-Object -First 1
    } catch {}

    if (-not $entry) { return $null }
    $productCode = $null
    $candidate = [string]$entry.UninstallString
    if ($candidate -match '(?i)\{[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}') {
        $productCode = $Matches[0]
    } elseif ([string]$entry.PSChildName -match '^\{[0-9a-fA-F-]{36}\}$') {
        $productCode = [string]$entry.PSChildName
    }
    if (-not $productCode) { return $null }

    $args = @('/fa', $productCode)
    if (-not $Interactive) { $args += @('/qn', '/norestart') }
    Write-WorkerLog "[MSI Repair] Running native Windows Installer repair for $AppName ($productCode)." "INFO" -Percent ($BasePercent + 10)
    try {
        $proc = Invoke-ProcessResult -FilePath 'msiexec.exe' -ArgumentList $args -ShowWindow:$Interactive
        $ok = Test-ExitSuccess -ExitCode $proc.ExitCode
        return [pscustomobject]@{ Success=$ok; ExitCode=$proc.ExitCode; Started=$true; Reboot=($proc.ExitCode -in @(1641,3010)) }
    } catch {
        Write-WorkerLog "[MSI Repair] $AppName failed: $_" "WARNING" -Percent $BasePercent
        return [pscustomobject]@{ Success=$false; ExitCode=-1; Started=$true; Reboot=$false }
    }
}

function Get-ChocoPath {
    if ($script:ChocoCheckedPath -and (Test-Path -LiteralPath $script:ChocoCheckedPath)) {
        return $script:ChocoCheckedPath
    }

    $command = Get-Command choco.exe -ErrorAction SilentlyContinue
    if ($command) {
        $script:ChocoCheckedPath = $command.Source
        return $script:ChocoCheckedPath
    }

    $defaultPath = Join-Path $env:ProgramData "chocolatey\bin\choco.exe"
    if (Test-Path -LiteralPath $defaultPath) {
        $script:ChocoCheckedPath = $defaultPath
        return $script:ChocoCheckedPath
    }
    return $null
}

function Ensure-Chocolatey {
    $existing = Get-ChocoPath
    if ($existing) { return $existing }

    Write-WorkerLog "Chocolatey is missing; attempting one-time initialization." "WARNING"
    $setupFile = Join-Path $DownloadDir ("choco_setup_{0}.ps1" -f [guid]::NewGuid().ToString("N"))

    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        Invoke-WebRequest -Uri "https://community.chocolatey.org/install.ps1" `
            -OutFile $setupFile -UseBasicParsing -ErrorAction Stop

        if (!(Test-Path -LiteralPath $setupFile) -or (Get-Item -LiteralPath $setupFile).Length -lt 1000) {
            throw "Chocolatey bootstrap script is missing or incomplete."
        }

        $process = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$setupFile`"") `
            -Wait -PassThru -NoNewWindow

        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $env:Path = "$machinePath;$userPath"

        $found = Get-ChocoPath
        if ($process.ExitCode -eq 0 -and $found) {
            Write-WorkerLog "Chocolatey initialized successfully." "SUCCESS"
            return $found
        }

        throw "Chocolatey setup failed (exit code $($process.ExitCode)); choco.exe was not verified."
    }
    catch {
        Write-WorkerLog "Chocolatey initialization error: $_" "ERROR"
        return $null
    }
    finally {
        if (Test-Path -LiteralPath $setupFile) {
            Remove-Item -LiteralPath $setupFile -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ProcessResult {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [bool]$ShowWindow
    )

    $startParams = @{
        FilePath = $FilePath
        ArgumentList = $ArgumentList
        Wait = $true
        PassThru = $true
        ErrorAction = "Stop"
    }
    if (-not $ShowWindow) { $startParams["WindowStyle"] = "Hidden" }

    return (Start-Process @startParams)
}

function Test-ExitSuccess {
    param([int]$ExitCode)
    return ($ExitCode -in @(0, 1641, 3010))
}

function Invoke-WingetUnelevated {
    param(
        [string]$WingetPath,
        [string[]]$Arguments,
        [bool]$ShowWindow = $false,
        [int]$TimeoutSeconds = 1800
    )

    $tempRoot = [IO.Path]::GetTempPath()
    $jobId = [guid]::NewGuid().ToString('N')
    $helperPath = Join-Path $tempRoot ("AMR_Winget_UserContext_{0}.ps1" -f $jobId)
    $payloadPath = Join-Path $tempRoot ("AMR_Winget_UserContext_{0}.json" -f $jobId)
    $resultPath = Join-Path $tempRoot ("AMR_Winget_UserContext_{0}.exit" -f $jobId)
    $helperCode = @"
param([Parameter(Mandatory=`$true)][string]`$PayloadPath, [Parameter(Mandatory=`$true)][string]`$ResultPath)
`$exitCode = -1
try {
    `$payload = Get-Content -LiteralPath `$PayloadPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    `$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    `$principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList `$identity
    if (`$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Explorer helper is still elevated; refusing to run an elevation-prohibited installer.' }
    `$proc = Start-Process -FilePath ([string]`$payload.WingetPath) -ArgumentList ([string[]]`$payload.Arguments) -Wait -PassThru -NoNewWindow -ErrorAction Stop
    `$exitCode = [int]`$proc.ExitCode
} catch {
    try { [IO.File]::WriteAllText(`$ResultPath, ('ERROR: ' + `$_.Exception.Message)) } catch {}
    exit
}
try { [IO.File]::WriteAllText(`$ResultPath, [string]`$exitCode) } catch {}
"@
    $payload = [pscustomobject]@{ WingetPath=$WingetPath; Arguments=@($Arguments); ResultPath=$resultPath }
    $shell = $null
    $shellWindow = $null
    $started = $false
    try {
        Set-Content -LiteralPath $helperPath -Value $helperCode -Encoding UTF8 -ErrorAction Stop
        $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $payloadPath -Encoding UTF8 -ErrorAction Stop
        $powerShellExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $powerShellExe)) { throw 'Windows PowerShell executable was not found.' }
        $parameters = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -PayloadPath "{1}" -ResultPath "{2}"' -f $helperPath, $payloadPath, $resultPath
        $show = if ($ShowWindow) { 1 } else { 0 }

        # Use Explorer's shell process to launch a standard-user helper from this elevated worker.
        $shell = New-Object -ComObject Shell.Application
        try {
            $explorerWindows = @($shell.Windows() | Where-Object { $_.FullName -match '(?i)\\explorer\.exe$' })
            if ($explorerWindows.Count -gt 0) { $shellWindow = $explorerWindows[0].Application }
        } catch { $shellWindow = $null }
        if ($shellWindow) {
            [void]$shellWindow.ShellExecute($powerShellExe, $parameters, $tempRoot, 'open', $show)
        } else {
            [void]$shell.ShellExecute($powerShellExe, $parameters, $tempRoot, 'open', $show)
        }
        $started = $true

        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while (-not (Test-Path -LiteralPath $resultPath) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
        if (-not (Test-Path -LiteralPath $resultPath)) {
            return [pscustomobject]@{ Started=$true; Success=$false; ExitCode=-1; TimedOut=$true }
        }
        $rawResult = (Get-Content -LiteralPath $resultPath -Raw -ErrorAction Stop).Trim()
        if ($rawResult -match '^ERROR:') {
            Write-WorkerLog "[Winget/User] Unelevated helper failed: $rawResult" 'ERROR'
            return [pscustomobject]@{ Started=$true; Success=$false; ExitCode=-1; TimedOut=$false }
        }
        $exitCode = -1
        if (-not [int]::TryParse($rawResult, [ref]$exitCode)) { $exitCode = -1 }
        return [pscustomobject]@{ Started=$true; Success=(Test-ExitSuccess -ExitCode $exitCode); ExitCode=$exitCode; TimedOut=$false }
    } catch {
        Write-WorkerLog "[Winget/User] Could not launch unelevated Winget: $($_.Exception.Message)" 'ERROR'
        return [pscustomobject]@{ Started=$started; Success=$false; ExitCode=-1; TimedOut=$false }
    } finally {
        if ($shellWindow) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shellWindow) } catch {} }
        if ($shell) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch {} }
        foreach ($file in @($helperPath,$payloadPath,$resultPath)) {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Install-ViaWinget {
    param(
        [string]$TargetId,
        [string]$ActionCommand,
        [string]$ExtraFlags = "",
        [bool]$Interactive = $false,
        [int]$BasePercent = 0
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-WorkerLog "Winget is unavailable." "WARNING" -Percent $BasePercent
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Started = $false; Reboot = $false }
    }

    $cmd = if ($ActionCommand -eq "repair") { "install" } else { $ActionCommand }
    # WhatsApp is currently distributed through the Microsoft Store source, not the community winget source.
    $wingetSource = if ($TargetId -eq '9NKSQGP7F2NH') { 'msstore' } else { 'winget' }
    Write-WorkerLog "[Winget] Using source '$wingetSource' for $TargetId." "INFO" -Percent $BasePercent
    $argumentList = @($cmd, "--id", $TargetId, "--exact",
                      "--source", $wingetSource, "--accept-source-agreements",
                      "--accept-package-agreements")

    if ($ActionCommand -eq "repair") { $argumentList += "--force" }

    if ($Interactive) {
        $argumentList += "--interactive"
    } else {
        $argumentList += @("--silent", "--disable-interactivity")
    }

    if ($ExtraFlags) {
        $argumentList += ($ExtraFlags -split "\s+" | Where-Object { $_ })
    }

    # Spotify's WinGet manifest prohibits elevation. This utility self-elevates,
    # so launch Spotify directly through Explorer's standard-user token for every action.
    if ($TargetId -eq 'Spotify.Spotify') {
        Write-WorkerLog "[Winget/User] Spotify requires a non-elevated context; launching directly as the signed-in user." "INFO" -Percent ($BasePercent + 5)
        $userResult = Invoke-WingetUnelevated -WingetPath $winget.Source -Arguments $argumentList -ShowWindow:$Interactive
        if ($userResult.Success) {
            Write-WorkerLog "[Winget/User] Spotify completed in the standard-user context (exit $($userResult.ExitCode))." "SUCCESS" -Percent ($BasePercent + 20)
            return [pscustomobject]@{ Success=$true; ExitCode=$userResult.ExitCode; Started=$true; Reboot=($userResult.ExitCode -in @(1641,3010)) }
        }
        $reason = if ($userResult.TimedOut) { 'timed out after 1800 seconds' } else { "failed (exit $($userResult.ExitCode))" }
        Write-WorkerLog "[Winget/User] Spotify $reason; no elevated retry or concurrent fallback will be launched." "ERROR" -Percent $BasePercent
        return [pscustomobject]@{ Success=$false; ExitCode=$userResult.ExitCode; Started=[bool]$userResult.Started; Reboot=$false }
    }

    try {
        Write-WorkerLog "[Winget] Executing $cmd $TargetId" "INFO" -Percent ($BasePercent + 5)
        $proc = Invoke-ProcessResult -FilePath $winget.Source -ArgumentList $argumentList -ShowWindow:$Interactive
        $ok = Test-ExitSuccess -ExitCode $proc.ExitCode
        $reboot = ($proc.ExitCode -in @(1641, 3010))
        if ($ok) {
            Write-WorkerLog "[Winget] Completed $TargetId (exit $($proc.ExitCode))." "SUCCESS" -Percent ($BasePercent + 20)
        } elseif ($proc.ExitCode -eq -1978335146) {
            Write-WorkerLog "[Winget] $TargetId prohibits elevated execution (0x8A150056); retrying once through the user's Explorer shell." "WARNING" -Percent $BasePercent
            $userResult = Invoke-WingetUnelevated -WingetPath $winget.Source -Arguments $argumentList -ShowWindow:$Interactive
            if ($userResult.Success) {
                Write-WorkerLog "[Winget/User] Completed $TargetId in the non-elevated user context (exit $($userResult.ExitCode))." "SUCCESS" -Percent ($BasePercent + 20)
                return [pscustomobject]@{ Success=$true; ExitCode=$userResult.ExitCode; Started=$true; Reboot=($userResult.ExitCode -in @(1641,3010)) }
            }
            if ($userResult.TimedOut) {
                Write-WorkerLog "[Winget/User] $TargetId exceeded the 1800 second wait window; no fallback will be launched." "ERROR" -Percent $BasePercent
            } else {
                Write-WorkerLog "[Winget/User] $TargetId failed in the non-elevated context (exit $($userResult.ExitCode)); no concurrent fallback will be launched." "ERROR" -Percent $BasePercent
            }
            return [pscustomobject]@{ Success=$false; ExitCode=$userResult.ExitCode; Started=$true; Reboot=$false }
        } else {
            Write-WorkerLog "[Winget] Returned code $($proc.ExitCode) for $TargetId." "WARNING" -Percent $BasePercent
        }
        return [pscustomobject]@{ Success = $ok; ExitCode = $proc.ExitCode; Started = $true; Reboot = $reboot }
    }
    catch {
        Write-WorkerLog "[Winget] Error for $TargetId : $_" "WARNING" -Percent $BasePercent
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Started = $false; Reboot = $false }
    }
}

function Install-ViaChocolatey {
    param(
        [string]$ChocoId,
        [ValidateSet("install", "upgrade")][string]$Action = "install",
        [bool]$Interactive = $false,
        [int]$BasePercent = 0
    )

    if ([string]::IsNullOrWhiteSpace($ChocoId)) {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reboot = $false; Started = $false }
    }

    $choco = Ensure-Chocolatey
    if (-not $choco) {
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reboot = $false; Started = $false }
    }

    $argumentList = @($Action, $ChocoId, "-y", "--no-progress")
    if (-not $Interactive) { $argumentList += "--no-color" }

    try {
        Write-WorkerLog "[Chocolatey] Executing $Action $ChocoId" "INFO" -Percent ($BasePercent + 10)
        $proc = Invoke-ProcessResult -FilePath $choco -ArgumentList $argumentList -ShowWindow:$Interactive
        $ok = Test-ExitSuccess -ExitCode $proc.ExitCode
        $reboot = ($proc.ExitCode -in @(1641, 3010))
        if ($ok) {
            Write-WorkerLog "[Chocolatey] Completed $ChocoId (exit $($proc.ExitCode))." "SUCCESS" -Percent ($BasePercent + 20)
        } else {
            Write-WorkerLog "[Chocolatey] Returned code $($proc.ExitCode) for $ChocoId." "WARNING" -Percent $BasePercent
        }
        return [pscustomobject]@{ Success = $ok; ExitCode = $proc.ExitCode; Reboot = $reboot; Started = $true }
    }
    catch {
        Write-WorkerLog "[Chocolatey] Error for $ChocoId : $_" "WARNING" -Percent $BasePercent
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reboot = $false; Started = $true }
    }
}

function Test-InstallerSignature {
    param([string]$Path, [string]$ExpectedPublisher)

    try {
        $signature = Get-AuthenticodeSignature -FilePath $Path
        if ($signature.Status -ne "Valid") { return $false }
        if ([string]::IsNullOrWhiteSpace($ExpectedPublisher)) { return $true }
        return ($signature.SignerCertificate.Subject -like "*$ExpectedPublisher*")
    } catch {
        return $false
    }
}

function Install-ViaDirectDownload {
    param(
        [string]$AppName,
        [string]$Url,
        [string]$InstallerArgs,
        [string]$ExpectedPublisher,
        [bool]$Interactive = $false,
        [int]$AppBasePercent = 0,
        [int]$AppStepWeight = 33
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        Write-WorkerLog "[Direct] No direct URL configured for $AppName; tier skipped." "WARNING" -Percent $AppBasePercent
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reboot = $false }
    }

    $downloadPath = $null
    $client = $null
    try {
        $uri = [uri]$Url
        if ($uri.Scheme -ne "https") { throw "HTTPS is required for direct downloads." }

        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $downloadPath = Join-Path $DownloadDir ("{0}_{1}.bin" -f
            ($AppName -replace "[^\w-]", "_"), [guid]::NewGuid().ToString("N"))

        Write-WorkerLog "[Direct] Downloading $AppName..." "INFO" -Percent ($AppBasePercent + 5)
        
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        
        $script:LastReportedPct = -1
        $client.add_DownloadProgressChanged({
            param($sender, $e)
            $downloadPct = $e.ProgressPercentage
            if ($downloadPct -ne $script:LastReportedPct -and ($downloadPct % 5 -eq 0)) {
                $script:LastReportedPct = $downloadPct
                $calculatedGlobalPct = $AppBasePercent + [math]::Round(($downloadPct / 100) * ($AppStepWeight * 0.6))
                $bytesMB = [math]::Round($e.BytesReceived / 1MB, 1)
                $totalMB = [math]::Round($e.TotalBytesToReceive / 1MB, 1)
                Write-WorkerLog "[Direct] $AppName Downloading ($downloadPct% - $bytesMB MB / $totalMB MB)..." "INFO" -Percent $calculatedGlobalPct
            }
        })
        
        $downloadTask = $client.DownloadFileTaskAsync($Url, $downloadPath)
        while (-not $downloadTask.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        if ($downloadTask.IsFaulted) { throw $downloadTask.Exception.InnerException }
        if (!(Test-Path -LiteralPath $downloadPath) -or (Get-Item -LiteralPath $downloadPath).Length -lt 10240) {
            throw "Downloaded payload is empty or too small."
        }

        $stream = [IO.File]::OpenRead($downloadPath)
        try {
            $header = New-Object byte[] 8
            $read = $stream.Read($header, 0, 8)
        } finally {
            $stream.Dispose()
        }

        $kind = $null
        if ($read -ge 2 -and $header[0] -eq 0x4D -and $header[1] -eq 0x5A) {
            $kind = "exe"
        } elseif ($read -ge 4 -and $header[0] -eq 0xD0 -and $header[1] -eq 0xCF -and
                  $header[2] -eq 0x11 -and $header[3] -eq 0xE0) {
            $kind = "msi"
        } elseif ($read -ge 8 -and $header[0] -eq 0xD0 -and $header[1] -eq 0xCF) {
            $kind = "msi"
        }

        if (-not $kind) { throw "Downloaded file is not recognized as an EXE or MSI installer." }

        $finalPath = [IO.Path]::ChangeExtension($downloadPath, ".$kind")
        Move-Item -LiteralPath $downloadPath -Destination $finalPath -Force
        $downloadPath = $finalPath

        if (-not (Test-InstallerSignature -Path $downloadPath -ExpectedPublisher $ExpectedPublisher)) {
            throw "Installer signature or publisher verification failed."
        }

        Write-WorkerLog "[Direct] Executing installer for $AppName..." "INFO" -Percent ($AppBasePercent + [math]::Round($AppStepWeight * 0.8))

        # Interactive Install must not inherit silent switches from the catalog's default install recipe.
        $effectiveInstallerArgs = [string]$InstallerArgs
        if ($Interactive -and $effectiveInstallerArgs) {
            $effectiveInstallerArgs = $effectiveInstallerArgs -replace '(?i)(^|\s)(--silent|/silent|/S|/quiet|--quiet|/verysilent|/qn)(?=\s|$)', ' '
            $effectiveInstallerArgs = ($effectiveInstallerArgs -replace '\s{2,}', ' ').Trim()
        }

        if ($kind -eq "msi") {
            $msiArgs = @("/i", "`"$downloadPath`"")
            if (-not $Interactive) { $msiArgs += @("/qn", "/norestart") }
            if ($effectiveInstallerArgs) { $msiArgs += ($effectiveInstallerArgs -split "\s+" | Where-Object { $_ }) }
            $proc = Invoke-ProcessResult -FilePath "msiexec.exe" -ArgumentList $msiArgs -ShowWindow:$Interactive
        } else {
            # Keep the EXE argument string intact so quoted paths (e.g. AnyDesk --install "C:\Program Files...") survive.
            $exeArgs = @()
            if ($effectiveInstallerArgs) { $exeArgs = @($effectiveInstallerArgs) }
            $proc = Invoke-ProcessResult -FilePath $downloadPath -ArgumentList $exeArgs -ShowWindow:$Interactive
        }

        $ok = Test-ExitSuccess -ExitCode $proc.ExitCode
        $reboot = ($proc.ExitCode -in @(1641, 3010))
        if ($ok) {
            Write-WorkerLog "[Direct] Installer finished for $AppName (exit $($proc.ExitCode))." "SUCCESS" -Percent ($AppBasePercent + $AppStepWeight)
        } else {
            Write-WorkerLog "[Direct] Installer failed for $AppName (exit $($proc.ExitCode))." "ERROR" -Percent $AppBasePercent
        }
        return [pscustomobject]@{ Success = $ok; ExitCode = $proc.ExitCode; Reboot = $reboot }
    }
    catch {
        Write-WorkerLog "[Direct] $AppName failed: $_" "ERROR" -Percent $AppBasePercent
        return [pscustomobject]@{ Success = $false; ExitCode = -1; Reboot = $false }
    }
    finally {
        if ($client) { try { $client.Dispose() } catch {} }
        if ($downloadPath -and (Test-Path -LiteralPath $downloadPath)) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$successCount = 0
$failedCount  = 0
$skippedCount = 0
$rebootNeeded = $false
$results = New-Object System.Collections.Generic.List[object]

$totalApps = $Apps.Count
$appIndex = 0

$wingetNotFoundOrFetchErrors = @(
    -1,           # Winget unavailable or process did not start
    0x80190194,   # HTTP 404 while resolving/downloading source data
    -1978335212,  # 0x8A150014 - NO_APPLICATIONS_FOUND
    -1978335209,  # 0x8A150017 - NO_MANIFEST_FOUND
    -1978335214   # 0x8A150012 - SOURCE_NAME_DOES_NOT_EXIST
)

foreach ($app in $Apps) {
    $appIndex++
    $appBasePercent = [math]::Round((($appIndex - 1) / $totalApps) * 100)
    $appStepWeight  = [math]::Round((1 / $totalApps) * 100)
    
    $name = [string]$app.Name
    $configuredId = [string]$app.Id
    $chocoId = [string]$app.ChocoId
    $wasInstalled = Test-WorkerInstalled -AppName $name -AppId $configuredId -ChocoId $chocoId
    $id = if ($ActionCommand -in @('upgrade','repair')) { Resolve-WorkerWingetId -AppName $name -ConfiguredId $configuredId } else { $configuredId }

    if ($ActionCommand -in @('upgrade','repair') -and -not $wasInstalled) {
        Write-WorkerLog "[$name] not detected as installed; $ActionCommand skipped." "INFO" -Percent ($appBasePercent + $appStepWeight)
        $skippedCount++
        [void]$results.Add([pscustomobject]@{ Name=$name; Status="NotInstalled"; ExitCode=0 })
        continue
    }

    if ($ActionCommand -eq "install" -and $wasInstalled) {
        Write-WorkerLog "[$name] already detected in system registry; skipped." "SUCCESS" -Percent ($appBasePercent + $appStepWeight)
        $skippedCount++
        [void]$results.Add([pscustomobject]@{ Name=$name; Status="Skipped"; ExitCode=0 })
        continue
    }

    Write-WorkerLog "Processing $name ($appIndex of $totalApps)..." "INFO" -Percent $appBasePercent
    $done = $false
    $appReboot = $false
    $lastExitCode = -1
    $chocoResult = $null

    # Tier 1: native MSI repair when the installed product exposes a Windows Installer product code.
    # Other installers use Winget's force-reinstall path as a best-effort repair fallback.
    if ($ActionCommand -eq 'repair') {
        $wingetResult = Invoke-WorkerMsiRepair -AppName $name -Interactive:$Interactive -BasePercent $appBasePercent
        if ($null -eq $wingetResult) {
            Write-WorkerLog "[$name] No native MSI repair entry found; attempting Winget force-reinstall as best-effort repair." "INFO" -Percent $appBasePercent
            $wingetResult = Install-ViaWinget -TargetId $id -ActionCommand $ActionCommand -ExtraFlags "" -Interactive:$Interactive -BasePercent $appBasePercent
        }
    } else {
        $wingetResult = Install-ViaWinget -TargetId $id -ActionCommand $ActionCommand -ExtraFlags "" -Interactive:$Interactive -BasePercent $appBasePercent
    }
    $lastExitCode = $wingetResult.ExitCode
    if ($wingetResult.Reboot) { $appReboot = $true }

    # Winget uses a non-zero HRESULT when an upgrade is not applicable.
    # This normally means there is no newer applicable version, not that installation failed.
    if ($ActionCommand -eq "upgrade" -and $wingetResult.ExitCode -eq -1978335189) {
        Write-WorkerLog "[$name] Already up to date (Winget: no applicable update found); no action required." "SUCCESS" -Percent ($appBasePercent + $appStepWeight)
        $skippedCount++
        [void]$results.Add([pscustomobject]@{ Name=$name; Status="UpToDate"; ExitCode=$wingetResult.ExitCode })
        continue
    }

    if ($wingetResult.Success) {
        # A successful exact-ID package-manager exit is authoritative for all actions.
        # Registry correlation is advisory only; it must never trigger a second installer.
        $done = $true
        if ($ActionCommand -eq "install" -and -not (Test-WorkerInstalled -AppName $name -AppId $id -ChocoId $chocoId)) {
            Write-WorkerLog "[$name] Winget reported success; registry correlation is not yet visible, accepting the verified package-manager result." "WARNING" -Percent $appBasePercent
        }
    } else {
        if ($wingetResult.Started -and ($wingetResult.ExitCode -notin $wingetNotFoundOrFetchErrors)) {
            # Do not launch a second installer after a real installer process failed or was cancelled.
            Write-WorkerLog "[$name] Winget installer started but failed (exit $($wingetResult.ExitCode)); fallback blocked to avoid concurrent or conflicting installation." "WARNING" -Percent $appBasePercent
        } else {
            Write-WorkerLog "[$name] Winget package/source unavailable; moving to Tier 2 (Chocolatey)." "INFO" -Percent $appBasePercent
        }
    }

    # Tier 2: Chocolatey fallback. In Interactive mode it is deliberately skipped because
    # Chocolatey package scripts commonly enforce silent installer switches regardless of console visibility.
    $allowFallback = ($wingetResult.Success -or -not $wingetResult.Started -or ($wingetResult.ExitCode -in $wingetNotFoundOrFetchErrors))
    if (-not $done -and $allowFallback -and $ActionCommand -ne "repair" -and -not $Interactive -and -not [string]::IsNullOrWhiteSpace($chocoId)) {
        $chocoAction = if ($ActionCommand -eq "install") { "install" } else { "upgrade" }
        $chocoResult = Install-ViaChocolatey -ChocoId $chocoId -Action $chocoAction -Interactive:$Interactive -BasePercent $appBasePercent
        $lastExitCode = $chocoResult.ExitCode
        if ($chocoResult.Reboot) { $appReboot = $true }

        if ($chocoResult.Success) {
            $done = $true
            if ($ActionCommand -eq "install" -and -not (Test-WorkerInstalled -AppName $name -AppId $id -ChocoId $chocoId)) {
                Write-WorkerLog "[$name] Chocolatey reported success; registry correlation is not yet visible, accepting the package-manager result." "WARNING" -Percent $appBasePercent
            }
        } else {
            Write-WorkerLog "[$name] Chocolatey failed (exit $($chocoResult.ExitCode)); attempting Direct Download..." "WARNING" -Percent $appBasePercent
        }
    }

    if (-not $done -and $allowFallback -and $Interactive -and $ActionCommand -ne "repair") {
        Write-WorkerLog "[$name] Chocolatey fallback skipped in Interactive mode to avoid package scripts forcing silent installation." "INFO" -Percent $appBasePercent
    }

    # Tier 3: Direct Download. Direct installers are permitted only for fresh installs. An EXE/MSI URL does not
    # guarantee a safe in-place upgrade and must never be used as an implicit upgrade path.
    $allowDirectFallback = $allowFallback -and ($null -eq $chocoResult -or $chocoResult.Success -or -not $chocoResult.Started)
    if (-not $done -and $allowDirectFallback -and $ActionCommand -eq "install") {

        $directResult = Install-ViaDirectDownload -AppName $name -Url ([string]$app.DirectUrl) `
            -InstallerArgs ([string]$app.DirectArgs) -ExpectedPublisher ([string]$app.Publisher) `
            -Interactive:$Interactive -AppBasePercent $appBasePercent -AppStepWeight $appStepWeight
        $lastExitCode = $directResult.ExitCode
        if ($directResult.Reboot) { $appReboot = $true }

        if ($directResult.Success) {
            if (Test-WorkerInstalled -AppName $name -AppId $id -ChocoId $chocoId) {
                $done = $true
            } else {
                Write-WorkerLog "[$name] Direct Download installer executed, but registry verification failed." "WARNING" -Percent $appBasePercent
            }
        }
    }

    if ($appReboot) { $rebootNeeded = $true }

    if ($done) {
        $successCount++
        $successDescription = if ($ActionCommand -eq "install") { "completed successfully and verified in the system" } else { "completed successfully (package-manager exit code verified)" }
        Write-WorkerLog "[$name] $successDescription." "SUCCESS" -Percent ($appBasePercent + $appStepWeight)
        [void]$results.Add([pscustomobject]@{ Name=$name; Status="Success"; ExitCode=$lastExitCode })
    } else {
        $failedCount++
        Write-WorkerLog "[$name] failed in all applicable tiers or unverified in registry; continuing queue." "ERROR" -Percent ($appBasePercent + $appStepWeight)
        [void]$results.Add([pscustomobject]@{ Name=$name; Status="Failed"; ExitCode=$lastExitCode })
    }
}

Write-WorkerLog "Queue completed." "SUCCESS" -Percent 100

$workerSummary = [pscustomobject]@{
    ActionName   = $ActionName
    SuccessCount = $successCount
    FailedCount  = $failedCount
    SkippedCount = $skippedCount
    RebootNeeded = $rebootNeeded
    Results      = @($results)
}
# Publish the summary through a thread-safe side channel before returning it to the pipeline.
# This keeps the UI completion path reliable even if PowerShell's EndInvoke output binder fails.
[void]$ResultQueue.Enqueue($workerSummary)
return
'@

function Set-AMRInstallButtonsEnabled {
    param([bool]$Enabled)

    foreach ($name in @('InstallSelectedBtn','InstallInteractiveBtn','UpdateSelectedBtn','RepairSelectedBtn','DeselectAllBtn')) {
        $button = C $name
        if ($button) { $button.IsEnabled = $Enabled }
    }
}

function Complete-AMRInstallQueue {
    param($Result, [string]$ErrorText = '')

    if ($script:InstallTimer) {
        $script:InstallTimer.Stop()
        $script:InstallTimer = $null
    }

    $line = $null
    while ($script:InstallLogQueue.TryDequeue([ref]$line)) {
        if ($line) {
            if ($line -match "^PROG:(\d+)\|(.*)$") {
                $script:ProgressBar.Value = [int]$matches[1]
                $line = $matches[2]
            }
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
            foreach ($key in @('All','Software')) {
                $control = $script:LogControls[$key]
                if ($control) {
                    $control.AppendText("$line`r`n")
                    $control.ScrollToEnd()
                }
            }
            $script:Status.Text = $line
            $script:ProgressText.Text = $line
        }
        $line = $null
    }

    if ($script:InstallPowerShell) {
        try { $script:InstallPowerShell.Dispose() } catch {}
        $script:InstallPowerShell = $null
    }
    if ($script:InstallRunspace) {
        try { $script:InstallRunspace.Close(); $script:InstallRunspace.Dispose() } catch {}
        $script:InstallRunspace = $null
    }

    $script:InstallAsyncResult = $null
    $script:InstallOutput = $null
    $script:InstallResultQueue = $null
    $script:InstallRunning = $false

    foreach ($app in $script:SoftwareCatalog) { $app.IsSelected = $false }
    $script:AppsView.Refresh()
    Set-AMRInstallButtonsEnabled -Enabled $true

    if ($ErrorText) {
        $script:ProgressBar.Value = 0
        $script:ProgressText.Text = "Installation failed with error."
        Write-AMRLog "Installation worker failed: $ErrorText" ERROR Software
        Show-AMRMessage "The installation worker stopped unexpectedly:`n`n$ErrorText" "Engine Error" OK Error | Out-Null
        return
    }

    if (-not $Result) {
        Show-AMRMessage "The operation finished without returning a result." "Engine Warning" OK Warning | Out-Null
        return
    }

    $summary = "$($Result.ActionName) Summary:`n`n" +
               "✔ Successfully processed: $($Result.SuccessCount)`n" +
               "⏭ Skipped (already installed): $($Result.SkippedCount)`n" +
               "❌ Failed: $($Result.FailedCount)"

    if ($Result.RebootNeeded) {
        $summary += "`n`n⚠ One or more installers requested a restart (1641/3010)."
    }

    $script:ProgressBar.Value = 100
    $script:ProgressText.Text = "Finished: $($Result.SuccessCount) Succeeded, $($Result.SkippedCount) Skipped, $($Result.FailedCount) Failed."
    Write-AMRLog "Queue finished. Success: $($Result.SuccessCount), Skipped: $($Result.SkippedCount), Failed: $($Result.FailedCount)." SUCCESS Software
    Show-AMRMessage $summary "Operation Summary" OK Information | Out-Null
}

function Execute-SmartMultiTierInstallAsync {
    param(
        [string]$ActionCommand,
        [string]$ActionName,
        [string]$ExtraFlags = '',
        [switch]$Interactive
    )

    if ($script:InstallRunning) {
        Write-AMRLog "An installation queue is already running." WARNING Software
        return
    }

    if ($ActionCommand -notin @('install','upgrade','repair')) {
        Show-AMRMessage "Unsupported software action: $ActionCommand" "Invalid Action" OK Error | Out-Null
        return
    }

    $selectedSnapshot = @(
        $script:SoftwareCatalog |
        Where-Object { $_.IsSelected -eq $true } |
        ForEach-Object {
            [pscustomobject]@{
                Name       = [string]$_.Name
                Category   = [string]$_.Category
                Id         = [string]$_.Id
                ChocoId    = [string]$_.ChocoId
                DirectUrl  = [string]$_.DirectUrl
                DirectArgs = [string]$_.DirectArgs
                Publisher  = [string]$_.Publisher
            }
        }
    )

    if ($selectedSnapshot.Count -eq 0) {
        Show-AMRMessage "Please select at least one application." "Selection Required" OK Warning | Out-Null
        return
    }

    $script:InstallRunning = $true
    $script:InstallActionName = $ActionName
    $script:InstallSelectedSnapshot = $selectedSnapshot
    $script:ProgressBar.Value = 0
    $script:ProgressText.Text = "Initializing $ActionName..."
    Set-AMRInstallButtonsEnabled -Enabled $false

    Write-AMRLog "Starting $ActionName for $($selectedSnapshot.Count) application(s)." INFO Software

    try {
        $discardedLine = $null
        while ($script:InstallLogQueue.TryDequeue([ref]$discardedLine)) {
            $discardedLine = $null
        }

        $script:InstallRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $script:InstallRunspace.ApartmentState = [System.Threading.ApartmentState]::MTA
        $script:InstallRunspace.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $script:InstallRunspace.Open()

        $script:InstallPowerShell = [PowerShell]::Create()
        $script:InstallPowerShell.Runspace = $script:InstallRunspace

        [void]$script:InstallPowerShell.AddScript($script:InstallWorkerCode)
        [void]$script:InstallPowerShell.AddArgument($selectedSnapshot)
        [void]$script:InstallPowerShell.AddArgument($ActionCommand)
        [void]$script:InstallPowerShell.AddArgument($ActionName)
        [void]$script:InstallPowerShell.AddArgument([bool]$Interactive)
        [void]$script:InstallPowerShell.AddArgument($script:DownloadDir)
        [void]$script:InstallPowerShell.AddArgument($script:InstallLogQueue)
        $script:InstallResultQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
        [void]$script:InstallPowerShell.AddArgument($script:InstallResultQueue)

        $script:InstallOutput = $null
        # Use the parameterless BeginInvoke overload and consume its result exactly once
        # with EndInvoke on the UI dispatcher after IsCompleted becomes true.
        $script:InstallAsyncResult = $script:InstallPowerShell.BeginInvoke()

        $script:InstallTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:InstallTimer.Interval = [TimeSpan]::FromMilliseconds(150)
        $script:InstallTimer.Add_Tick({
            $queuedLine = $null
            while ($script:InstallLogQueue.TryDequeue([ref]$queuedLine)) {
                if ($queuedLine) {
                    if ($queuedLine -match "^PROG:(\d+)\|(.*)$") {
                        $script:ProgressBar.Value = [int]$matches[1]
                        $queuedLine = $matches[2]
                    }
                    Add-Content -LiteralPath $script:LogFile -Value $queuedLine -Encoding UTF8 -ErrorAction SilentlyContinue
                    foreach ($key in @('All','Software')) {
                        $control = $script:LogControls[$key]
                        if ($control) {
                            $control.AppendText("$queuedLine`r`n")
                            $control.ScrollToEnd()
                        }
                    }
                    $script:Status.Text = $queuedLine
                    $script:ProgressText.Text = $queuedLine
                }
                $queuedLine = $null
            }

            if ($script:InstallAsyncResult -and $script:InstallAsyncResult.IsCompleted) {
                if ($script:InstallTimer) { $script:InstallTimer.Stop() }
                $resultObject = $null
                $errorMessage = ''
                $endInvokeWarning = ''
                try {
                    # The worker summary is delivered through InstallResultQueue; no complex
                    # objects are emitted into the pipeline. EndInvoke only closes the async call.
                    $asyncHandle = [System.IAsyncResult]$script:InstallAsyncResult
                    $endInvokeMethod = [System.Management.Automation.PowerShell].GetMethod('EndInvoke', [type[]]@([System.IAsyncResult]))
                    if (-not $endInvokeMethod) { throw 'PowerShell EndInvoke(IAsyncResult) method was not found.' }
                    # The worker summary is returned through InstallResultQueue, not pipeline output.
                    [void]$endInvokeMethod.Invoke($script:InstallPowerShell, [object[]]@($asyncHandle))
                } catch {
                    $endInvokeWarning = $_.Exception.Message
                }

                # Prefer the worker's thread-safe summary queue if EndInvoke could not materialize output.
                if (-not $resultObject -and $script:InstallResultQueue) {
                    $queuedSummary = $null
                    if ($script:InstallResultQueue.TryDequeue([ref]$queuedSummary)) {
                        $resultObject = $queuedSummary
                    }
                }

                if ($script:InstallPowerShell.Streams.Error.Count -gt 0) {
                    $streamErrors = ($script:InstallPowerShell.Streams.Error | ForEach-Object { $_.ToString() }) -join "`n"
                    if (-not $resultObject) { $errorMessage = $streamErrors }
                    else { Write-AMRLog "Worker reported non-terminating errors: $streamErrors" WARNING Software }
                }

                if ($resultObject -and $endInvokeWarning) {
                    Write-AMRLog "EndInvoke output retrieval warning (worker summary was recovered safely): $endInvokeWarning" WARNING Software
                } elseif (-not $resultObject) {
                    $errorMessage = if ($endInvokeWarning) { $endInvokeWarning } else { "The worker completed but did not return a valid summary object." }
                }

                Complete-AMRInstallQueue -Result $resultObject -ErrorText $errorMessage
            }
        })
        $script:InstallTimer.Start()
    }
    catch {
        Complete-AMRInstallQueue -Result $null -ErrorText $_.Exception.Message
    }
}

# BUTTON BINDINGS
(C 'InstallSelectedBtn').Add_Click({
    Execute-SmartMultiTierInstallAsync -ActionCommand 'install' -ActionName 'Smart Silent Install'
})

(C 'InstallInteractiveBtn').Add_Click({
    Execute-SmartMultiTierInstallAsync -ActionCommand 'install' -ActionName 'Interactive Install' -Interactive
})

(C 'UpdateSelectedBtn').Add_Click({
    Execute-SmartMultiTierInstallAsync -ActionCommand 'upgrade' -ActionName 'App Update'
})

(C 'RepairSelectedBtn').Add_Click({
    Execute-SmartMultiTierInstallAsync -ActionCommand 'repair' -ActionName 'App Repair'
})

# --- 8. MEGA CUSTOMIZE EXECUTION ENGINE (27 TOOLS & TWEAKS) ---
(C 'ApplyCustomizeBtn').Add_Click({
    Write-AMRLog "Applying selected Windows customizations..." INFO Customize
    $needsExplorerRestart = $false
    $appliedSuccessCount = 0

    # 1. Appearance & Visuals
    if ((C 'chkDarkMode').IsChecked -eq $true) {
        $r1 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        $r2 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
        if ($r1 -and $r2) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkDisableTransparency').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkDisableAccentColor').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 0) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkClassicVolume').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\MTCUVC" -Name "EnableMtcUvc" -Value 0) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableAnimations').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -PropertyType String) { $appliedSuccessCount++ }
    }

    # 2. Taskbar & Start Menu
    if ((C 'chkShowSeconds').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Value 1) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkDisableBingSearch').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkTaskbarLeft').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkHideWidgets').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkHideTaskView').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }

    # 3. File Explorer & View
    if ((C 'chkHiddenFiles').IsChecked -eq $true) {
        $r1 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
        $r2 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
        if ($r1 -and $r2) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkOpenThisPC').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkClassicContextMenu').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Classes\CLSID\{86ca3a0d-4a87-4447-a4cd-410b15471612}\InprocServer32" -Name "" -Value "" -PropertyType String) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkHideRecentFiles').IsChecked -eq $true) {
        $r1 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0
        $r2 = Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0
        if ($r1 -and $r2) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }
    if ((C 'chkSeparateFolderProcess').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "SeparateProcess" -Value 1) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }

    # 4. Behavior & Accessibility
    if ((C 'chkDisableStickyKeys').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -PropertyType String) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableAutoRebootUpdate').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Value 1) { $appliedSuccessCount++ }
    }
    if ((C 'chkShowBSODDetails').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableShortcutSuffix').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -Value ([byte[]]@(0,0,0,0)) -PropertyType Binary) { $appliedSuccessCount++; $needsExplorerRestart = $true }
    }

    # 5. Privacy & Tracking
    if ((C 'chkDisableAdvertisingID').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableLocationTracking').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -PropertyType String) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableFeedbackPrompts').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableTailoredExperiences').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Value 1) { $appliedSuccessCount++ }
    }

    # 6. Performance & Gaming Tools
    if ((C 'chkEnableGameMode').IsChecked -eq $true) {
        if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableSearchIndexing').IsChecked -eq $true) {
        Set-Service -Name "WSearch" -StartupType Manual -ErrorAction SilentlyContinue
        $appliedSuccessCount++
    }
    if ((C 'chkAddTakeOwnership').IsChecked -eq $true) {
        $cmd = 'cmd.exe /c takeown /f "%1" && icacls "%1" /grant administrators:F'
        if (Set-AMRRegistryKey -Path "HKCR:\*\shell\TakeOwnership\command" -Name "" -Value $cmd -PropertyType String) { $appliedSuccessCount++ }
    }
    if ((C 'chkDisableHibernation').IsChecked -eq $true) {
        powercfg -h off | Out-Null
        Write-AMRLog "Disabled system hibernation to free disk space." SUCCESS Customize
        $appliedSuccessCount++
    }

    if ($appliedSuccessCount -gt 0) {
        if ($needsExplorerRestart) {
            Write-AMRLog "Restarting File Explorer to apply desktop & registry changes..." INFO Customize
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        }
        Show-AMRMessage "Applied $appliedSuccessCount customization tweak(s) successfully!" "Customization Complete" OK Information | Out-Null
    } else {
        Show-AMRMessage "Please select at least one tweak to apply." "Notice" OK Warning | Out-Null
    }
})

# BASIC TWEAKS PRESETS - selecting a preset only checks options; it never executes them.
$script:AMRBasicPresetMap = @{
    Essential = @('btDisableTips','btDisableAds','btDisableFeedback','btDisableRecent','btShowExtensions','btActivityHistory','btConsumerFeatures','btDeliveryOptimization','btTailoredExperiences','btInputPersonalization','btLockScreenTips','btDisableGameDVR','btDisableAppLaunchTracking','btDisableWidgets','btDisableWebSearch','btDisableTransparency','btDisableStartAppSuggestions','btDisableSilentInstalls','btDisableSoftLanding','btDisableSettingsSuggestions','btDisableSyncNotifications','btDisableOnlineSpeech','btDisableHandwritingData')
    Minimal   = @('btDisableTips','btDisableAds','btDisableFeedback','btDisableRecent','btActivityHistory','btConsumerFeatures','btDeliveryOptimization','btDisableStartAppSuggestions','btDisableSoftLanding','btDisableSettingsSuggestions')
    Medium    = @('btDisableTips','btDisableAds','btDisableFeedback','btDisableRecent','btShowExtensions','btShowHidden','btThisPC','btActivityHistory','btConsumerFeatures','btDeliveryOptimization','btTailoredExperiences','btInputPersonalization','btLockScreenTips','btDisableGameDVR','btDisableAppLaunchTracking','btDisableWidgets','btDisableWebSearch','btDisableTransparency','btDisableAnimations','btGameMode','btDisableStartAppSuggestions','btDisableSilentInstalls','btDisableSoftLanding','btDisableSettingsSuggestions','btDisableSyncNotifications','btDisableOnlineSpeech','btDisableHandwritingData','btShowFullPath','btDisableAutoPlay','btDisableRecentDocsTracking','btDisableSearchHighlights','btUseCompactExplorer','btDisableLockScreenSlideShow')
    Advanced  = @('btTempFiles','btClearRecent','btDisableTips','btDisableTransparency','btDisableAnimations','btPowerHigh','btGameMode','btShowExtensions','btShowHidden','btThisPC','btDisableRecent','btDisableAds','btDisableFeedback','btDisableBackground','btDisableCortana','btActivityHistory','btConsumerFeatures','btDeliveryOptimization','btTailoredExperiences','btInputPersonalization','btLockScreenTips','btDisableTelemetryService','btDisableGameDVR','btDisableWebSearch','btDisableAppLaunchTracking','btDisableWidgets','btDisableHibernation','btDisableStartAppSuggestions','btDisableSilentInstalls','btDisableSoftLanding','btDisableSettingsSuggestions','btDisableSyncNotifications','btDisableOnlineSpeech','btDisableHandwritingData','btShowFullPath','btDisableAutoPlay','btDisableRecentDocsTracking','btDisableSearchHighlights','btUseCompactExplorer','btDisableLockScreenCamera','btDisableLockScreenSlideShow')
}
$script:AMRBasicCheckboxNames = @('btTempFiles','btEmptyRecycleBin','btClearRecent','btDisableTips','btDisableTransparency','btDisableAnimations','btPowerHigh','btGameMode','btShowExtensions','btShowHidden','btThisPC','btDisableRecent','btDisableAds','btDisableFeedback','btDisableBackground','btDisableCortana','btActivityHistory','btConsumerFeatures','btDeliveryOptimization','btTailoredExperiences','btInputPersonalization','btLockScreenTips','btDisableTelemetryService','btDisableGameDVR','btDisableWebSearch','btDisableAppLaunchTracking','btDisableWidgets','btDisableHibernation','btDisableStartAppSuggestions','btDisableSilentInstalls','btDisableSoftLanding','btDisableSettingsSuggestions','btDisableSyncNotifications','btDisableOnlineSpeech','btDisableHandwritingData','btShowFullPath','btDisableAutoPlay','btDisableRecentDocsTracking','btDisableSearchHighlights','btUseCompactExplorer','btDisableLockScreenCamera','btDisableLockScreenSlideShow')
$script:AMRCustomizeCheckboxNames = @('chkDarkMode','chkDisableTransparency','chkDisableAccentColor','chkClassicVolume','chkDisableAnimations','chkShowSeconds','chkDisableBingSearch','chkTaskbarLeft','chkHideWidgets','chkHideTaskView','chkHiddenFiles','chkOpenThisPC','chkClassicContextMenu','chkHideRecentFiles','chkSeparateFolderProcess','chkDisableStickyKeys','chkDisableAutoRebootUpdate','chkShowBSODDetails','chkDisableShortcutSuffix','chkDisableAdvertisingID','chkDisableLocationTracking','chkDisableFeedbackPrompts','chkDisableTailoredExperiences','chkEnableGameMode','chkDisableSearchIndexing','chkAddTakeOwnership','chkDisableHibernation')
function Update-AMRTweakSelectionCounts {
    # Each panel displays only its own selection count.
    $left = @($script:AMRCustomizeCheckboxNames | Where-Object { (C $_).IsChecked -eq $true }).Count
    $right = @($script:AMRBasicCheckboxNames | Where-Object { (C $_).IsChecked -eq $true }).Count
    $leftCounter = C 'CustomizeSelectionCount'
    if ($leftCounter -and ($leftCounter -is [System.Windows.Controls.TextBlock])) { $leftCounter.Text = "$left selected on left" }
    $rightCounter = C 'BasicSelectionCount'
    if ($rightCounter -and ($rightCounter -is [System.Windows.Controls.TextBlock])) { $rightCounter.Text = "$right selected on right" }
}
function Set-AMRBasicPreset {
    param([ValidateSet('Essential','Minimal','Medium','Advanced')][string]$Preset)
    foreach ($name in $script:AMRBasicCheckboxNames) { (C $name).IsChecked = $false }
    foreach ($name in $script:AMRBasicPresetMap[$Preset]) { (C $name).IsChecked = $true }
    (C 'BasicPresetStatus').Text = "$Preset preset selected. Review the checked options, then press Apply Selected Tweaks."
    Update-AMRTweakSelectionCounts
    Write-AMRLog "Selected $Preset local preset; no changes applied yet." INFO Customize
}
# Keep counters live without linking checkbox state between panels.
foreach ($name in $script:AMRCustomizeCheckboxNames) {
    $cb = C $name
    $cb.Add_Checked({ Update-AMRTweakSelectionCounts })
    $cb.Add_Unchecked({ Update-AMRTweakSelectionCounts })
}
foreach ($name in $script:AMRBasicCheckboxNames) {
    $cb = C $name
    $cb.Add_Checked({ Update-AMRTweakSelectionCounts })
    $cb.Add_Unchecked({ Update-AMRTweakSelectionCounts })
}

# LEFT panel: clear only the legacy Customize selections.
(C 'CancelCustomizeBtn').Add_Click({
    foreach ($name in $script:AMRCustomizeCheckboxNames) { (C $name).IsChecked = $false }
    Update-AMRTweakSelectionCounts
    Write-AMRLog 'Cleared selected tweaks in the left Customize panel.' INFO Customize
})

# RIGHT panel: clear only the Basic Tweaks selections.
(C 'CancelAllTweaksBtn').Add_Click({
    foreach ($name in $script:AMRBasicCheckboxNames) { (C $name).IsChecked = $false }
    (C 'BasicPresetStatus').Text = 'All right-side selections cleared. Choose a preset or select options manually.'
    Update-AMRTweakSelectionCounts
    Write-AMRLog 'Cleared selected tweaks in the right Basic Tweaks panel.' INFO Customize
})
(C 'BasicPresetEssentialBtn').Add_Click({ Set-AMRBasicPreset -Preset Essential })
(C 'BasicPresetMinimalBtn').Add_Click({ Set-AMRBasicPreset -Preset Minimal })
(C 'BasicPresetMediumBtn').Add_Click({ Set-AMRBasicPreset -Preset Medium })
Update-AMRTweakSelectionCounts
(C 'BasicPresetAdvancedBtn').Add_Click({
    $answer = Show-AMRMessage 'Advanced selects more system and privacy changes. Review each checked option before applying. Continue with selection only?' 'Advanced preset' YesNo Warning
    if ($answer -eq 'Yes') { Set-AMRBasicPreset -Preset Advanced }
})

# BASIC TWEAKS ENGINE - independent from the existing Customize engine
(C 'ApplyBasicTweaksBtn').Add_Click({
    $count = 0
    $restartExplorer = $false
    try {
        if ((C 'btTempFiles').IsChecked -eq $true) {
            $tempPath = [IO.Path]::GetTempPath()
            Get-ChildItem -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop; $count++ } catch { }
            }
            Write-AMRLog 'Attempted current-user temporary-file cleanup; in-use files were skipped.' INFO Customize
        }
        if ((C 'btEmptyRecycleBin').IsChecked -eq $true) {
            $answer = Show-AMRMessage 'This permanently empties the Recycle Bin. Continue?' 'Confirm Recycle Bin cleanup' YesNo Warning
            if ($answer -eq 'Yes') { Clear-RecycleBin -Force -ErrorAction Stop; $count++ }
        }
        if ((C 'btClearRecent').IsChecked -eq $true) {
            $recent = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
            if (Test-Path $recent) { Get-ChildItem -LiteralPath $recent -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue; $count++ }
        }
        if ((C 'btDisableTips').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0) { $count++ }
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SystemPaneSuggestionsEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableTransparency').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableAnimations').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name 'MinAnimate' -Value '0' -PropertyType String) { $count++ }
        }
        if ((C 'btPowerHigh').IsChecked -eq $true) {
            $plans = (& powercfg /list 2>$null) -join "`n"
            $match = [regex]::Match($plans, '([a-fA-F0-9-]{36}).*\(High performance\)', 'IgnoreCase')
            if ($match.Success) { & powercfg /setactive $match.Groups[1].Value; if ($LASTEXITCODE -eq 0) { $count++ } }
            else { Show-AMRMessage 'High Performance plan was not found on this device. No power plan was changed.' 'Power plan unavailable' OK Information | Out-Null }
        }
        if ((C 'btGameMode').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AllowAutoGameMode' -Value 1) { $count++ }
        }
        if ((C 'btShowExtensions').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0) { $count++; $restartExplorer=$true }
        }
        if ((C 'btShowHidden').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 1) { $count++; $restartExplorer=$true }
        }
        if ((C 'btThisPC').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -Value 1) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableRecent').IsChecked -eq $true) {
            $a = Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowRecent' -Value 0
            $b = Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowFrequent' -Value 0
            if ($a -and $b) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableAds').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableFeedback').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Siuf\Rules' -Name 'NumberOfSIUFInPeriod' -Value 0) { $count++ }
        }
        if ((C 'btDisableBackground').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1) { $count++ }
        }
        if ((C 'btDisableCortana').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0) { $count++ }
        }
        if ((C 'btActivityHistory').IsChecked -eq $true) {
            $p='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
            if (Set-AMRRegistryKey -Path $p -Name 'EnableActivityFeed' -Value 1) { $count++ }
            if (Set-AMRRegistryKey -Path $p -Name 'PublishUserActivities' -Value 0) { $count++ }
            if (Set-AMRRegistryKey -Path $p -Name 'UploadUserActivities' -Value 0) { $count++ }
        }
        if ((C 'btConsumerFeatures').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1) { $count++ }
        }
        if ((C 'btDeliveryOptimization').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name 'DODownloadMode' -Value 0) { $count++ }
        }
        if ((C 'btTailoredExperiences').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0) { $count++ }
        }
        if ((C 'btInputPersonalization').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection' -Value 1) { $count++ }
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -Value 1) { $count++ }
        }
        if ((C 'btLockScreenTips').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled' -Value 0) { $count++ }
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenOverlayEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableTelemetryService').IsChecked -eq $true) {
            try { Set-Service -Name 'DiagTrack' -StartupType Disabled -ErrorAction Stop; Stop-Service -Name 'DiagTrack' -Force -ErrorAction SilentlyContinue; $count++ }
            catch { Write-AMRLog ('Could not disable DiagTrack service: ' + $_.Exception.Message) WARNING Customize }
        }
        if ((C 'btDisableGameDVR').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0) { $count++ }
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableWebSearch').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1) { $count++ }
            if (Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0) { $count++ }
        }
        if ((C 'btDisableAppLaunchTracking').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_TrackProgs' -Value 0) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableWidgets').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableHibernation').IsChecked -eq $true) {
            $answer = Show-AMRMessage 'Disabling hibernation removes the hibernation file and disables Hibernate (and may disable Fast Startup). Continue?' 'Confirm hibernation change' YesNo Warning
            if ($answer -eq 'Yes') { & powercfg.exe /hibernate off; if ($LASTEXITCODE -eq 0) { $count++ } }
        }
        if ((C 'btDisableStartAppSuggestions').IsChecked -eq $true) {
            $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
            $ok1=Set-AMRRegistryKey -Path $p -Name 'SubscribedContent-338388Enabled' -Value 0
            $ok2=Set-AMRRegistryKey -Path $p -Name 'SubscribedContent-338389Enabled' -Value 0
            if ($ok1 -and $ok2) { $count++ }
        }
        if ((C 'btDisableSilentInstalls').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableSoftLanding').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SoftLandingEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableSettingsSuggestions').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338393Enabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableSyncNotifications').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowSyncProviderNotifications' -Value 0) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableOnlineSpeech').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' -Name 'HasAccepted' -Value 0) { $count++ }
        }
        if ((C 'btDisableHandwritingData').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' -Name 'HarvestContacts' -Value 0) { $count++ }
        }
        if ((C 'btShowFullPath').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' -Name 'FullPath' -Value 1) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableAutoPlay').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255) { $count++ }
        }
        if ((C 'btDisableRecentDocsTracking').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoRecentDocsHistory' -Value 1) { $count++ }
        }
        if ((C 'btDisableSearchHighlights').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsDynamicSearchBoxEnabled' -Value 0) { $count++ }
        }
        if ((C 'btUseCompactExplorer').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'UseCompactMode' -Value 1) { $count++; $restartExplorer=$true }
        }
        if ((C 'btDisableLockScreenCamera').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled' -Value 0) { $count++ }
        }
        if ((C 'btDisableLockScreenSlideShow').IsChecked -eq $true) {
            if (Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen' -Name 'SlideshowEnabled' -Value 0) { $count++ }
        }
        if ($restartExplorer) {
            $answer = Show-AMRMessage 'Some Explorer changes may need File Explorer to restart. Restart it now?' 'Refresh File Explorer' YesNo Question
            if ($answer -eq 'Yes') { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 700; Start-Process explorer.exe }
        }
        if ($count -gt 0) { Show-AMRMessage "Applied $count basic tweak action(s). Some changes may require sign-out or restart." 'Basic Tweaks' OK Information | Out-Null }
        else { Show-AMRMessage 'Select at least one tweak to apply.' 'Basic Tweaks' OK Warning | Out-Null }
    } catch {
        Write-AMRLog ("Basic tweaks error: {0}" -f $_.Exception.Message) ERROR Customize
        Show-AMRMessage ("A tweak could not be completed: {0}" -f $_.Exception.Message) 'Basic Tweaks Error' OK Error | Out-Null
    }
})

# OPTIMIZE ENGINE - searchable, categorized optimization toolbox
$script:AMROptimizeTools = @(
@{Name='Disable Temporary Diagnostic Tracking';Category='Privacy & Features';Key='TelemetryOff';Keywords='telemetry diagnostic tracking diagtrack data collection';},
@{Name='Disable Unnecessary Background Apps';Category='Startup & Background';Key='BackgroundOff';Keywords='background apps global access battery';},
@{Name='Disable Cortana Assistant';Category='Privacy & Features';Key='CortanaOff';Keywords='cortana assistant windows search';},
@{Name='Show Active Power Plan';Category='Performance & Power';Key='PowerPlan';Keywords='powercfg current plan'},
@{Name='Activate Ultimate Performance Plan';Category='Performance & Power';Key='Ultimate';Keywords='high ultimate performance power scheme'},
@{Name='Open Power Options';Category='Performance & Power';Key='PowerOptions';Keywords='power sleep lid settings'},
@{Name='Open Advanced Power Settings';Category='Performance & Power';Key='AdvancedPower';Keywords='processor sleep usb power'},
@{Name='Generate Power Efficiency Report';Category='Performance & Power';Key='EnergyReport';Keywords='powercfg energy report efficiency'},
@{Name='Show Battery Health Report';Category='Performance & Power';Key='BatteryReport';Keywords='battery health capacity laptop'},
@{Name='Disable Fast Startup';Category='Startup & Background';Key='FastStartupOff';Keywords='hiberboot shutdown boot'},
@{Name='Enable Fast Startup';Category='Startup & Background';Key='FastStartupOn';Keywords='hiberboot boot'},
@{Name='Open Startup Apps';Category='Startup & Background';Key='StartupApps';Keywords='task manager startup launch'},
@{Name='Open Task Manager';Category='Startup & Background';Key='TaskManager';Keywords='processes startup performance'},
@{Name='Show Running Processes';Category='Startup & Background';Key='Processes';Keywords='tasklist process memory cpu'},
@{Name='Open Windows Services';Category='Startup & Background';Key='Services';Keywords='services manager background service'},
@{Name='Open Storage Settings';Category='Storage & Cleanup';Key='StorageSettings';Keywords='storage disk space settings'},
@{Name='Open Disk Cleanup';Category='Storage & Cleanup';Key='CleanMgr';Keywords='cleanmgr temporary files'},
@{Name='Open Temporary Files Settings';Category='Storage & Cleanup';Key='TempSettings';Keywords='temporary files storage cleanup'},
@{Name='Open Optimize Drives';Category='Storage & Cleanup';Key='OptimizeDrives';Keywords='defrag trim ssd optimize drive'},
@{Name='Show Drive Free Space';Category='Storage & Cleanup';Key='DriveSpace';Keywords='disk free space volume'},
@{Name='Empty Current User Temp Folder';Category='Storage & Cleanup';Key='ClearUserTemp';Keywords='temp cache remove cleanup'},
@{Name='Empty Windows Temp Folder';Category='Storage & Cleanup';Key='ClearWindowsTemp';Keywords='windows temp cleanup admin'},
@{Name='Open Recycle Bin';Category='Storage & Cleanup';Key='RecycleBin';Keywords='deleted files restore empty'},
@{Name='Open Installed Apps';Category='Storage & Cleanup';Key='InstalledApps';Keywords='uninstall programs applications'},
@{Name='Open Default Apps Settings';Category='Windows Maintenance';Key='DefaultApps';Keywords='default applications file associations'},
@{Name='Open Windows Update';Category='Windows Maintenance';Key='WindowsUpdate';Keywords='updates patches install'},
@{Name='Check Windows Update Service';Category='Windows Maintenance';Key='UpdateService';Keywords='wuauserv service status'},
@{Name='Restart Windows Update Service';Category='Windows Maintenance';Key='RestartUpdate';Keywords='wuauserv restart update'},
@{Name='Run System File Checker';Category='Windows Maintenance';Key='SFC';Keywords='sfc scannow repair system files'},
@{Name='Run DISM Health Check';Category='Windows Maintenance';Key='DISMCheck';Keywords='dism checkhealth image corruption'},
@{Name='Repair Windows Component Store';Category='Windows Maintenance';Key='DISMRepair';Keywords='dism restorehealth repair'},
@{Name='Open Troubleshoot Settings';Category='Windows Maintenance';Key='Troubleshoot';Keywords='troubleshoot fix problems'},
@{Name='Open System Protection';Category='Windows Maintenance';Key='SystemProtection';Keywords='restore point recovery'},
@{Name='Create System Restore Point';Category='Windows Maintenance';Key='RestorePoint';Keywords='checkpoint restore recovery'},
@{Name='Open Visual Effects Settings';Category='Performance & Power';Key='VisualEffects';Keywords='performance appearance animation'},
@{Name='Open Virtual Memory Settings';Category='Performance & Power';Key='VirtualMemory';Keywords='pagefile paging file ram'},
@{Name='Open Graphics Settings';Category='Performance & Power';Key='GraphicsSettings';Keywords='gpu graphics performance'},
@{Name='Open Game Mode Settings';Category='Performance & Power';Key='GameMode';Keywords='gaming game mode'},
@{Name='Open Background Apps Permissions';Category='Startup & Background';Key='BackgroundSettings';Keywords='background permissions apps'},
@{Name='Open Startup Folder';Category='Startup & Background';Key='StartupFolder';Keywords='shell startup autostart'},
@{Name='Open Network Status';Category='Network & Responsiveness';Key='NetworkStatus';Keywords='network status internet connection'},
@{Name='Open Internet Options';Category='Network & Responsiveness';Key='InternetOptions';Keywords='inetcpl proxy cache'},
@{Name='Flush DNS Cache';Category='Network & Responsiveness';Key='FlushDNS';Keywords='ipconfig dns resolver cache'},
@{Name='Open Delivery Optimization Settings';Category='Network & Responsiveness';Key='DeliveryOptimization';Keywords='windows update peer to peer bandwidth'},
@{Name='Open Privacy Settings';Category='Privacy & Features';Key='Privacy';Keywords='privacy permissions diagnostics'},
@{Name='Open Search Permissions';Category='Privacy & Features';Key='SearchPrivacy';Keywords='search indexing cloud content'},
@{Name='Open Optional Features';Category='Privacy & Features';Key='OptionalFeatures';Keywords='windows features enable disable'},
@{Name='Open Reliability Monitor';Category='Diagnostics & Monitoring';Key='Reliability';Keywords='perfmon rel crashes reliability history'},
@{Name='Open Resource Monitor';Category='Diagnostics & Monitoring';Key='ResourceMonitor';Keywords='resmon cpu disk memory network'},
@{Name='Generate System Diagnostics Report';Category='Diagnostics & Monitoring';Key='PerfReport';Keywords='perfmon report diagnostics performance'}
)

function Invoke-AMROptimizeTool {
 param([string]$Key)
 try {
  switch ($Key) {
   'TelemetryOff' { Set-Service -Name 'DiagTrack' -StartupType Disabled -ErrorAction SilentlyContinue; Stop-Service -Name 'DiagTrack' -Force -ErrorAction SilentlyContinue; Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 | Out-Null; Show-AMRMessage 'Diagnostic tracking restrictions were applied where supported. Some Windows editions may ignore policy settings.' 'Optimize' OK Information | Out-Null; return }
   'BackgroundOff' { Set-AMRRegistryKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 | Out-Null; Show-AMRMessage 'Background app access was disabled for supported apps.' 'Optimize' OK Information | Out-Null; return }
   'CortanaOff' { Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0 | Out-Null; Show-AMRMessage 'Cortana policy was applied where supported. This setting may not affect newer Windows Search versions.' 'Optimize' OK Information | Out-Null; return }
   'PowerPlan' { powercfg /getactivescheme; return }
   'Ultimate' { $p=(powercfg /list | Select-String 'Ultimate Performance').ToString(); if($p -match '([a-fA-F0-9-]{36})'){ powercfg /setactive $matches[1] } else { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; Show-AMRMessage 'Ultimate Performance scheme was requested. Check Power Options to confirm availability.' 'Optimize' OK Information | Out-Null }; return }
   'PowerOptions' { Start-Process powercfg.cpl; return }
   'AdvancedPower' { Start-Process control.exe -ArgumentList '/name Microsoft.PowerOptions'; return }
   'EnergyReport' { $f=Join-Path ([Environment]::GetFolderPath('Desktop')) 'AMR-Energy-Report.html'; powercfg /energy /duration 60 /output $f; if(Test-Path $f){Start-Process $f}; return }
   'BatteryReport' { $f=Join-Path ([Environment]::GetFolderPath('Desktop')) 'AMR-Battery-Report.html'; powercfg /batteryreport /output $f; if(Test-Path $f){Start-Process $f}; return }
   'FastStartupOff' { Set-AMRRegistryKey -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 | Out-Null; Show-AMRMessage 'Fast Startup was disabled. Restart Windows to apply.' 'Optimize' OK Information | Out-Null; return }
   'FastStartupOn' { Set-AMRRegistryKey -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 1 | Out-Null; return }
   'StartupApps' { Start-Process 'ms-settings:startupapps'; return }
   'TaskManager' { Start-Process taskmgr.exe; return }
   'Processes' { Get-Process | Sort-Object CPU -Descending | Select-Object -First 25 ProcessName,Id,CPU,WorkingSet64 | Out-GridView -Title 'Top Processes' ; return }
   'Services' { Start-Process services.msc; return }
   'StorageSettings' { Start-Process 'ms-settings:storagesense'; return }
   'CleanMgr' { Start-Process cleanmgr.exe; return }
   'TempSettings' { Start-Process 'ms-settings:temporaryfiles'; return }
   'OptimizeDrives' { Start-Process dfrgui.exe; return }
   'DriveSpace' { Get-PSDrive -PSProvider FileSystem | Select-Object Name,Root,@{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}},@{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}} | Out-GridView -Title 'Drive Space'; return }
   'ClearUserTemp' { if((Show-AMRMessage 'Delete files from your current user TEMP folder? Files in use may remain.' 'Confirm Cleanup' YesNo Warning) -ne 'Yes'){return}; Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Show-AMRMessage 'User temporary-file cleanup completed (files in use may remain).' 'Optimize' OK Information | Out-Null; return }
   'ClearWindowsTemp' { if((Show-AMRMessage 'Delete files from the Windows TEMP folder? Administrator rights may be required.' 'Confirm Cleanup' YesNo Warning) -ne 'Yes'){return}; Get-ChildItem -LiteralPath (Join-Path $env:windir 'Temp') -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Show-AMRMessage 'Windows temporary-file cleanup attempted.' 'Optimize' OK Information | Out-Null; return }
   'RecycleBin' { Start-Process explorer.exe -ArgumentList 'shell:RecycleBinFolder'; return }
   'InstalledApps' { Start-Process 'ms-settings:appsfeatures'; return }
   'DefaultApps' { Start-Process 'ms-settings:defaultapps'; return }
   'WindowsUpdate' { Start-Process 'ms-settings:windowsupdate'; return }
   'UpdateService' { Get-Service wuauserv | Format-List Name,Status,StartType | Out-GridView -Title 'Windows Update Service'; return }
   'RestartUpdate' { if((Show-AMRMessage 'Restart the Windows Update service now?' 'Confirm Service Restart' YesNo Warning) -ne 'Yes'){return}; Restart-Service wuauserv -Force -ErrorAction Stop; return }
   'SFC' { if((Show-AMRMessage 'Run System File Checker? This may take several minutes.' 'Confirm Repair' YesNo Warning) -ne 'Yes'){return}; Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','sfc /scannow'; return }
   'DISMCheck' { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','DISM /Online /Cleanup-Image /CheckHealth'; return }
   'DISMRepair' { if((Show-AMRMessage 'Run DISM RestoreHealth? This may take a while and use Windows Update.' 'Confirm Repair' YesNo Warning) -ne 'Yes'){return}; Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','DISM /Online /Cleanup-Image /RestoreHealth'; return }
   'Troubleshoot' { Start-Process 'ms-settings:troubleshoot'; return }
   'SystemProtection' { Start-Process SystemPropertiesProtection.exe; return }
   'RestorePoint' { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','Checkpoint-Computer -Description "AMR Utility Restore Point" -RestorePointType MODIFY_SETTINGS'; return }
   'VisualEffects' { Start-Process SystemPropertiesPerformance.exe; return }
   'PerformanceOptions' { Start-Process SystemPropertiesPerformance.exe; return }
   'VirtualMemory' { Start-Process SystemPropertiesAdvanced.exe; return }
   'GraphicsSettings' { Start-Process 'ms-settings:display-advancedgraphics'; return }
   'GameMode' { Start-Process 'ms-settings:gaming-gamemode'; return }
   'BackgroundSettings' { Start-Process 'ms-settings:privacy-backgroundapps'; return }
   'StartupFolder' { Start-Process explorer.exe -ArgumentList 'shell:startup'; return }
   'NetworkStatus' { Start-Process 'ms-settings:network-status'; return }
   'InternetOptions' { Start-Process inetcpl.cpl; return }
   'FlushDNS' { ipconfig /flushdns; Show-AMRMessage 'DNS resolver cache flush command completed.' 'Optimize' OK Information | Out-Null; return }
   'DeliveryOptimization' { Start-Process 'ms-settings:delivery-optimization'; return }
   'Privacy' { Start-Process 'ms-settings:privacy'; return }
   'SearchPrivacy' { Start-Process 'ms-settings:search-permissions'; return }
   'OptionalFeatures' { Start-Process optionalfeatures.exe; return }
   'Reliability' { Start-Process perfmon.exe -ArgumentList '/rel'; return }
   'ResourceMonitor' { Start-Process resmon.exe; return }
   'PerfReport' { Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','perfmon /report'; return }
  }
 } catch { Show-AMRMessage ("Could not complete the selected optimization: " + $_.Exception.Message) 'Optimize' OK Error | Out-Null; Write-AMRLog ("Optimize tool failed [$Key]: " + $_.Exception.Message) ERROR Optimize }
}
function Update-AMROptimizeView {
 $query = ''; if ($null -ne (C 'OptSearchBox')) { $query = (C 'OptSearchBox').Text }
 $category = 'All Categories'; if ($null -ne (C 'OptCategoryFilter') -and (C 'OptCategoryFilter').SelectedItem) { $category = ([string](C 'OptCategoryFilter').SelectedItem.Content) -replace '^⚙️\s*','' }
 $grid = C 'OptToolsGrid'; if ($null -eq $grid) { return }; $grid.Children.Clear()
 $items = @($script:AMROptimizeTools | Where-Object { ($category -eq 'All Categories' -or $_.Category -eq $category) -and (($_.Name + ' ' + $_.Keywords + ' ' + $_.Category) -match [regex]::Escape($query)) })
 foreach ($tool in $items) { $button = New-Object System.Windows.Controls.Button; $button.Content = "⚙️  $($tool.Name)"; $button.Tag = $tool.Key; $button.Margin = '0,0,10,10'; $button.Padding = '12,10'; $button.HorizontalContentAlignment = 'Left'; $button.MinHeight = 48; $button.FontSize = 13; $button.Add_Click({ Invoke-AMROptimizeTool -Key ([string]$this.Tag) }.GetNewClosure()); [void]$grid.Children.Add($button) }
 (C 'OptResultsCount').Text = "Showing $($items.Count) of $($script:AMROptimizeTools.Count) optimization tools"
}
(C 'OptSearchBox').Add_TextChanged({ Update-AMROptimizeView })
(C 'OptCategoryFilter').Add_SelectionChanged({ Update-AMROptimizeView })
Update-AMROptimizeView

# SECURITY ENGINE - searchable, categorized security toolbox
$script:AMRSecurityTools = @(
@{Name='Enable Realtime Windows Defender';Category='Defender & Antivirus';Key='DefenderOn';Keywords='defender antivirus realtime protection'},
@{Name='Enable All Firewall Profiles';Category='Firewall & Network';Key='FirewallOn';Keywords='firewall domain private public enable'},
@{Name='Disable Windows Activity History Collection';Category='Privacy & Tracking';Key='ActivityOff';Keywords='activity history tracking privacy'},
@{Name='Open Windows Security';Category='Defender & Antivirus';Key='OpenSecurity';Keywords='windows security center defender'},
@{Name='Open Virus & Threat Protection';Category='Defender & Antivirus';Key='VirusUI';Keywords='virus threat scan protection'},
@{Name='Run Quick Defender Scan';Category='Defender & Antivirus';Key='QuickScan';Keywords='quick antivirus malware scan'},
@{Name='Run Full Defender Scan';Category='Defender & Antivirus';Key='FullScan';Keywords='full antivirus malware scan'},
@{Name='Update Defender Security Intelligence';Category='Defender & Antivirus';Key='DefenderUpdate';Keywords='update signatures definitions antivirus'},
@{Name='Show Defender Status';Category='Auditing & Reports';Key='DefenderStatus';Keywords='get-mpcomputerstatus realtime antivirus'},
@{Name='Show Defender Threat History';Category='Auditing & Reports';Key='ThreatHistory';Keywords='protection history detected threats'},
@{Name='Open Firewall Advanced Settings';Category='Firewall & Network';Key='FirewallAdvanced';Keywords='wf.msc inbound outbound rules'},
@{Name='Show Firewall Profiles Status';Category='Auditing & Reports';Key='FirewallStatus';Keywords='get-netfirewallprofile status'},
@{Name='Open Network Protection Settings';Category='Firewall & Network';Key='NetworkSettings';Keywords='network firewall protection settings'},
@{Name='Open Proxy Settings';Category='Firewall & Network';Key='Proxy';Keywords='proxy settings internet'},
@{Name='Open VPN Settings';Category='Firewall & Network';Key='VPN';Keywords='vpn settings network'},
@{Name='Open Windows Update Security';Category='Security Settings';Key='UpdateSecurity';Keywords='windows update security patches'},
@{Name='Check Windows Security Center';Category='Auditing & Reports';Key='SecurityCenter';Keywords='security center status wscui'},
@{Name='Open SmartScreen Settings';Category='Defender & Antivirus';Key='SmartScreen';Keywords='smartscreen reputation based protection'},
@{Name='Open App & Browser Control';Category='Defender & Antivirus';Key='AppBrowser';Keywords='app browser control reputation'},
@{Name='Open Ransomware Protection';Category='Defender & Antivirus';Key='Ransomware';Keywords='controlled folder access ransomware'},
@{Name='Open Device Security';Category='Encryption & Protection';Key='DeviceSecurity';Keywords='device security core isolation tpm'},
@{Name='Open Core Isolation Settings';Category='Encryption & Protection';Key='CoreIsolation';Keywords='memory integrity core isolation'},
@{Name='Open BitLocker Management';Category='Encryption & Protection';Key='BitLocker';Keywords='bitlocker drive encryption manage-bde'},
@{Name='Check BitLocker Status';Category='Auditing & Reports';Key='BitLockerStatus';Keywords='manage-bde status encryption'},
@{Name='Open TPM Management';Category='Encryption & Protection';Key='TPM';Keywords='tpm.msc trusted platform module'},
@{Name='Open Sign-in Options';Category='Accounts & Sign-in';Key='SignIn';Keywords='windows hello pin sign in'},
@{Name='Open User Account Settings';Category='Accounts & Sign-in';Key='Accounts';Keywords='ms-settings yourinfo accounts'},
@{Name='Open Credential Manager';Category='Accounts & Sign-in';Key='Credentials';Keywords='control keymgr.dll saved credentials'},
@{Name='Open Local Users and Groups';Category='Accounts & Sign-in';Key='LocalUsers';Keywords='lusrmgr.msc users groups'},
@{Name='Open UAC Settings';Category='Accounts & Sign-in';Key='UAC';Keywords='user account control consent'},
@{Name='Review Recent Security Events';Category='Auditing & Reports';Key='SecurityEvents';Keywords='event viewer security log audit'},
@{Name='Open Event Viewer Security Log';Category='Auditing & Reports';Key='SecurityLog';Keywords='eventvwr security log'},
@{Name='Export Defender Status Report';Category='Auditing & Reports';Key='DefenderReport';Keywords='export antivirus status report'},
@{Name='Show Active Firewall Rules';Category='Auditing & Reports';Key='FirewallRules';Keywords='get-netfirewallrule enabled'},
@{Name='Show Local Administrators';Category='Auditing & Reports';Key='Admins';Keywords='local administrators group members'},
@{Name='Show Failed Sign-in Events';Category='Auditing & Reports';Key='FailedLogons';Keywords='security event 4625 logon failures'},
@{Name='Open Privacy Settings';Category='Privacy & Tracking';Key='Privacy';Keywords='ms-settings privacy'},
@{Name='Open Activity History Settings';Category='Privacy & Tracking';Key='ActivitySettings';Keywords='activity history privacy settings'},
@{Name='Open Diagnostic Data Settings';Category='Privacy & Tracking';Key='Diagnostics';Keywords='diagnostic data telemetry privacy'},
@{Name='Open Location Privacy Settings';Category='Privacy & Tracking';Key='Location';Keywords='location privacy permission'},
@{Name='Open Camera Privacy Settings';Category='Privacy & Tracking';Key='Camera';Keywords='camera app permissions privacy'},
@{Name='Open Microphone Privacy Settings';Category='Privacy & Tracking';Key='Microphone';Keywords='microphone app permissions privacy'},
@{Name='Open App Permissions';Category='Privacy & Tracking';Key='AppPermissions';Keywords='privacy app permissions'},
@{Name='Open Startup Apps Review';Category='Security Settings';Key='StartupReview';Keywords='startup apps review unwanted apps'},
@{Name='Open Installed Apps Review';Category='Security Settings';Key='AppsReview';Keywords='installed apps review uninstall'},
@{Name='Open Windows Backup Settings';Category='Security Settings';Key='BackupSettings';Keywords='windows backup recovery'},
@{Name='Open Recovery Settings';Category='Security Settings';Key='RecoverySettings';Keywords='recovery reset windows'},
@{Name='Open Security and Maintenance';Category='Security Settings';Key='Maintenance';Keywords='security maintenance status'},
@{Name='Open Windows Activation Status';Category='Security Settings';Key='Activation';Keywords='windows activation licensing'},
@{Name='Open Windows Firewall Settings';Category='Firewall & Network';Key='FirewallUI';Keywords='windows firewall settings'}
)
function Invoke-AMRSecurityTool {
 param([Parameter(Mandatory=$true)][string]$Key)
 try {
  $adminKeys=@('DefenderOn','FirewallOn','ActivityOff','QuickScan','FullScan','DefenderUpdate')
  if ($Key -in $adminKeys -and -not (Test-AMRAdmin)) { Show-AMRMessage 'This action may require Administrator privileges. Reopen Amr Utility as Administrator and try again.' 'Administrator Required' OK Warning | Out-Null; return }
  switch ($Key) {
   'DefenderOn' { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop; $msg='Microsoft Defender real-time protection was enabled.'; break }
   'FirewallOn' { Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -ErrorAction Stop; $msg='Windows Firewall was enabled for Domain, Private, and Public profiles.'; break }
   'ActivityOff' { Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name PublishUserActivities -Value 0 | Out-Null; Set-AMRRegistryKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name UploadUserActivities -Value 0 | Out-Null; $msg='Activity History collection policy was disabled.'; break }
   'OpenSecurity' { Start-Process 'windowsdefender:'; return }
   'VirusUI' { Start-Process 'windowsdefender://threat'; return }
   'QuickScan' { if((Show-AMRMessage 'Start a Microsoft Defender quick scan now?' 'Confirm Quick Scan' YesNo Warning) -ne 'Yes'){return}; Start-MpScan -ScanType QuickScan -ErrorAction Stop; $msg='Quick scan request completed.'; break }
   'FullScan' { if((Show-AMRMessage 'Start a full Microsoft Defender scan? It may take a long time.' 'Confirm Full Scan' YesNo Warning) -ne 'Yes'){return}; Start-MpScan -ScanType FullScan -ErrorAction Stop; $msg='Full scan request completed.'; break }
   'DefenderUpdate' { Update-MpSignature -ErrorAction Stop; $msg='Microsoft Defender security intelligence update requested.'; break }
   'DefenderStatus' { $msg=(Get-MpComputerStatus | Format-List * | Out-String); break }
   'ThreatHistory' { Start-Process 'windowsdefender://history'; return }
   'FirewallAdvanced' { Start-Process wf.msc; return }
   'FirewallStatus' { $msg=(Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize | Out-String); break }
   'NetworkSettings' { Start-Process 'windowsdefender://network'; return }
   'Proxy' { Start-Process 'ms-settings:network-proxy'; return }
   'VPN' { Start-Process 'ms-settings:network-vpn'; return }
   'UpdateSecurity' { Start-Process 'ms-settings:windowsupdate'; return }
   'SecurityCenter' { Start-Process 'wscui.cpl'; return }
   'SmartScreen' { Start-Process 'windowsdefender://appbrowser'; return }
   'AppBrowser' { Start-Process 'windowsdefender://appbrowser'; return }
   'Ransomware' { Start-Process 'windowsdefender://ransomware'; return }
   'DeviceSecurity' { Start-Process 'windowsdefender://devicesecurity'; return }
   'CoreIsolation' { Start-Process 'windowsdefender://devicesecurity'; return }
   'BitLocker' { Start-Process 'control.exe' -ArgumentList '/name Microsoft.BitLockerDriveEncryption'; return }
   'BitLockerStatus' { $msg=(manage-bde.exe -status 2>&1 | Out-String); break }
   'TPM' { Start-Process tpm.msc; return }
   'SignIn' { Start-Process 'ms-settings:signinoptions'; return }
   'Accounts' { Start-Process 'ms-settings:yourinfo'; return }
   'Credentials' { Start-Process 'rundll32.exe' -ArgumentList 'keymgr.dll,KRShowKeyMgr'; return }
   'LocalUsers' { Start-Process lusrmgr.msc; return }
   'UAC' { Start-Process UserAccountControlSettings.exe; return }
   'SecurityEvents' { $msg=(Get-WinEvent -FilterHashtable @{LogName='Security';Level=1,2,3;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 30 -ErrorAction Stop | Select-Object TimeCreated,Id,ProviderName,Message | Format-List | Out-String); break }
   'SecurityLog' { Start-Process eventvwr.msc; return }
   'DefenderReport' { $p=Join-Path $env:USERPROFILE 'Desktop\AMR-Defender-Status.txt'; Get-MpComputerStatus | Format-List * | Out-File -LiteralPath $p -Encoding utf8; Start-Process notepad.exe -ArgumentList ('"{0}"' -f $p); $msg="Defender status report saved to $p"; break }
   'FirewallRules' { $msg=(Get-NetFirewallRule -Enabled True -ErrorAction Stop | Select-Object DisplayName,Direction,Action,Profile | Format-Table -AutoSize | Out-String); break }
   'Admins' { $msg=(Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | Select-Object Name,ObjectClass,PrincipalSource | Format-Table -AutoSize | Out-String); break }
   'FailedLogons' { $msg=(Get-WinEvent -FilterHashtable @{LogName='Security';Id=4625;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 30 -ErrorAction Stop | Select-Object TimeCreated,Id,Message | Format-List | Out-String); break }
   'Privacy' { Start-Process 'ms-settings:privacy'; return }
   'ActivitySettings' { Start-Process 'ms-settings:privacy-activityhistory'; return }
   'Diagnostics' { Start-Process 'ms-settings:privacy-feedback'; return }
   'Location' { Start-Process 'ms-settings:privacy-location'; return }
   'Camera' { Start-Process 'ms-settings:privacy-webcam'; return }
   'Microphone' { Start-Process 'ms-settings:privacy-microphone'; return }
   'AppPermissions' { Start-Process 'ms-settings:privacy'; return }
   'StartupReview' { Start-Process 'ms-settings:startupapps'; return }
   'AppsReview' { Start-Process 'ms-settings:appsfeatures'; return }
   'BackupSettings' { Start-Process 'ms-settings:backup'; return }
   'RecoverySettings' { Start-Process 'ms-settings:recovery'; return }
   'Maintenance' { Start-Process control.exe -ArgumentList '/name Microsoft.SecurityAndMaintenance'; return }
   'Activation' { $msg=(cscript.exe //nologo "$env:windir\system32\slmgr.vbs" /xpr 2>&1 | Out-String); break }
   'FirewallUI' { Start-Process 'ms-settings:windowsdefender'; return }
   default { throw 'Unknown security tool.' }
  }
  Write-AMRLog ("Security tool completed: {0}" -f $Key) SUCCESS Security
  if ([string]::IsNullOrWhiteSpace([string]$msg)) {$msg='Command completed.'}
  Show-AMRMessage ([string]$msg) 'Security Tool Result' OK Information | Out-Null
 } catch { Write-AMRLog ("Security tool failed ({0}): {1}" -f $Key,$_.Exception.Message) ERROR Security; Show-AMRMessage ("Security tool failed:`n$($_.Exception.Message)") 'Security Tool Error' OK Error | Out-Null }
}
function Update-AMRSecurityView {
 $grid=C 'SecToolsGrid'; $grid.Children.Clear(); $search=[string](C 'SecSearchBox').Text
 $selected=(C 'SecCategoryFilter').SelectedItem; $category='All Categories'; if($selected){$category=([string]$selected.Content -replace '^🛡️\s*','')}
 $visible=0
 foreach($tool in $script:AMRSecurityTools){
  if($category -ne 'All Categories' -and $tool.Category -ne $category){continue}
  $haystack=('{0} {1} {2}' -f $tool.Name,$tool.Category,$tool.Keywords)
  if(-not [string]::IsNullOrWhiteSpace($search) -and $haystack -notlike "*$search*"){continue}
  $button=New-Object System.Windows.Controls.Button; $button.Content=('🛡️  ' + $tool.Name); $button.Tag=$tool.Key; $button.Margin='0,0,10,10'; $button.Padding='12,10'; $button.MinHeight=48; $button.HorizontalContentAlignment='Left'; $button.ToolTip=("{0} • {1}" -f $tool.Category,$tool.Keywords)
  $button.Add_Click({Invoke-AMRSecurityTool -Key ([string]$this.Tag)}.GetNewClosure()); [void]$grid.Children.Add($button); $visible++
 }
 (C 'SecResultsCount').Text=('{0} security tools shown' -f $visible)
}
(C 'SecSearchBox').Add_TextChanged({Update-AMRSecurityView})
(C 'SecCategoryFilter').Add_SelectionChanged({Update-AMRSecurityView})
Update-AMRSecurityView


# SYSTEM ENGINE
$script:AMRSystemTools = @(
@{Name='Show Active Power Plan';Category='Performance & Power';Key='PowerPlan';Keywords='powercfg current plan energy performance'},
@{Name='Activate Ultimate Performance Plan';Category='Performance & Power';Key='Ultimate';Keywords='high performance power scheme'},
@{Name='Open Power Options';Category='Performance & Power';Key='PowerOptions';Keywords='control powercfg.cpl'},
@{Name='Open Advanced Power Settings';Category='Performance & Power';Key='AdvancedPower';Keywords='power configuration sleep processor'},
@{Name='Generate Power Efficiency Report';Category='Performance & Power';Key='PowerReport';Keywords='powercfg energy battery report'},
@{Name='Show Battery Report';Category='Performance & Power';Key='BatteryReport';Keywords='laptop battery health capacity'},
@{Name='Disable Fast Startup';Category='Startup & Boot';Key='FastStartupOff';Keywords='hiberboot boot errors shutdown'},
@{Name='Enable Fast Startup';Category='Startup & Boot';Key='FastStartupOn';Keywords='hiberboot boot'},
@{Name='Open Startup Apps';Category='Startup & Boot';Key='StartupApps';Keywords='task manager startup launch'},
@{Name='Open System Configuration';Category='Startup & Boot';Key='MsConfig';Keywords='msconfig boot services'},
@{Name='Open Boot Advanced Options';Category='Startup & Boot';Key='BootAdvanced';Keywords='system configuration boot processor memory'},
@{Name='Open Startup Repair Options';Category='Startup & Boot';Key='StartupRepair';Keywords='recovery advanced startup repair'},
@{Name='Show Boot Configuration';Category='Startup & Boot';Key='BCD';Keywords='bcdedit boot loader'},
@{Name='Open Recovery Settings';Category='Recovery & Repair';Key='Recovery';Keywords='reset pc recovery options'},
@{Name='Open System Protection';Category='Recovery & Repair';Key='Protection';Keywords='restore point system restore'},
@{Name='Create System Restore Point';Category='Recovery & Repair';Key='RestorePoint';Keywords='checkpoint restore recovery'},
@{Name='Run System File Checker';Category='Recovery & Repair';Key='SFC';Keywords='sfc scannow repair protected files'},
@{Name='Run DISM Health Check';Category='Recovery & Repair';Key='DISMCheck';Keywords='dism image health corruption'},
@{Name='Repair Windows Image';Category='Recovery & Repair';Key='DISMRepair';Keywords='dism restorehealth component store'},
@{Name='Check Disk Online Scan';Category='Recovery & Repair';Key='CHKDSK';Keywords='chkdsk scan filesystem drive errors'},
@{Name='Open Troubleshoot Settings';Category='Recovery & Repair';Key='Troubleshoot';Keywords='settings troubleshoot repair'},
@{Name='Open Event Viewer';Category='Diagnostics & Reports';Key='EventViewer';Keywords='eventvwr logs errors warnings'},
@{Name='Open Reliability Monitor';Category='Diagnostics & Reports';Key='Reliability';Keywords='perfmon rel system crashes history'},
@{Name='Open Resource Monitor';Category='Diagnostics & Reports';Key='ResourceMonitor';Keywords='resmon cpu disk memory network'},
@{Name='Open Performance Monitor';Category='Diagnostics & Reports';Key='PerfMon';Keywords='perfmon counters performance'},
@{Name='Export System Information';Category='Diagnostics & Reports';Key='SystemInfo';Keywords='msinfo32 hardware software report'},
@{Name='Show Windows Version';Category='Diagnostics & Reports';Key='WinVersion';Keywords='winver build edition version'},
@{Name='List Recent System Errors';Category='Diagnostics & Reports';Key='RecentErrors';Keywords='event log critical error last week'},
@{Name='Show Running Processes';Category='Services & Processes';Key='Processes';Keywords='tasklist process memory cpu'},
@{Name='Open Task Manager';Category='Services & Processes';Key='TaskManager';Keywords='taskmgr processes startup'},
@{Name='Open Windows Services';Category='Services & Processes';Key='Services';Keywords='services.msc service manager'},
@{Name='Show Automatic Services';Category='Services & Processes';Key='AutoServices';Keywords='get-service startup automatic'},
@{Name='Restart Windows Update Service';Category='Services & Processes';Key='RestartWuauserv';Keywords='wuauserv update service restart'},
@{Name='Open Device Manager';Category='Storage & Devices';Key='DeviceManager';Keywords='devmgmt.msc drivers hardware'},
@{Name='Show Disk Health Summary';Category='Storage & Devices';Key='DiskHealth';Keywords='get-physicaldisk health status'},
@{Name='Show Disk Volumes';Category='Storage & Devices';Key='Volumes';Keywords='get-volume drive filesystem'},
@{Name='Open Disk Management';Category='Storage & Devices';Key='DiskMgmt';Keywords='diskmgmt.msc partitions'},
@{Name='Open Optimize Drives';Category='Storage & Devices';Key='OptimizeDrives';Keywords='dfrgui defrag trim ssd'},
@{Name='Open Windows Update';Category='Windows Settings';Key='WindowsUpdate';Keywords='settings update security'},
@{Name='Open Installed Apps';Category='Windows Settings';Key='InstalledApps';Keywords='settings apps uninstall programs'},
@{Name='Open System About Page';Category='Windows Settings';Key='About';Keywords='device specifications computer name'},
@{Name='Open System Properties';Category='Windows Settings';Key='SysProperties';Keywords='sysdm.cpl computer name hardware advanced'},
@{Name='Open Environment Variables';Category='Windows Settings';Key='Environment';Keywords='system properties environment path'},
@{Name='Open User Accounts';Category='Windows Settings';Key='UserAccounts';Keywords='netplwiz users accounts'},
@{Name='Open Registry Editor';Category='Windows Settings';Key='Regedit';Keywords='regedit registry editor'},
@{Name='Open Local Group Policy';Category='Windows Settings';Key='GroupPolicy';Keywords='gpedit.msc policy'},
@{Name='Open Windows Security';Category='Security & Maintenance';Key='WindowsSecurity';Keywords='defender firewall protection security'},
@{Name='Check Windows Activation';Category='Security & Maintenance';Key='Activation';Keywords='slmgr licensing activation'},
@{Name='Open Maintenance Center';Category='Security & Maintenance';Key='Maintenance';Keywords='security maintenance action center'},
@{Name='Open Backup Settings';Category='Security & Maintenance';Key='Backup';Keywords='file history backup restore'}
)
function Invoke-AMRSystemTool {
 param([Parameter(Mandatory=$true)][string]$Key)
 try {
  $adminKeys=@('Ultimate','FastStartupOff','FastStartupOn','RestorePoint','SFC','DISMRepair','RestartWuauserv')
  if ($Key -in $adminKeys -and -not (Test-AMRAdmin)) { Show-AMRMessage 'This action requires Administrator privileges. Reopen Amr Utility as Administrator and try again.' 'Administrator Required' OK Warning | Out-Null; return }
  switch ($Key) {
   'PowerPlan' { $msg=(powercfg /getactivescheme 2>&1 | Out-String); break }
   'Ultimate' { powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null; $scheme=(powercfg /list | Select-String 'Ultimate Performance' | Select-Object -First 1); if($scheme -and $scheme.Line -match '([a-f0-9-]{36})'){powercfg /setactive $matches[1] | Out-Null}; $msg='Ultimate Performance plan command completed. Check the active plan in Power Options.'; break }
   'PowerOptions' { Start-Process powercfg.cpl; return }
   'AdvancedPower' { Start-Process control.exe -ArgumentList '/name Microsoft.PowerOptions'; return }
   'PowerReport' { $p=Join-Path $env:USERPROFILE 'Desktop\AMR-Power-Efficiency-Report.html'; powercfg /energy /duration 60 /output $p | Out-Null; if(Test-Path $p){Start-Process $p}; $msg="Power efficiency report: $p"; break }
   'BatteryReport' { $p=Join-Path $env:USERPROFILE 'Desktop\AMR-Battery-Report.html'; powercfg /batteryreport /output $p | Out-Null; if(Test-Path $p){Start-Process $p}; $msg="Battery report: $p"; break }
   'FastStartupOff' { Set-AMRRegistryKey -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 | Out-Null; $msg='Fast Startup disabled. Restart Windows for a clean test.'; break }
   'FastStartupOn' { Set-AMRRegistryKey -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 1 | Out-Null; $msg='Fast Startup enabled.'; break }
   'StartupApps' { Start-Process 'ms-settings:startupapps'; return }
   'MsConfig' { Start-Process msconfig.exe; return }
   'BootAdvanced' { Start-Process msconfig.exe; $msg='In System Configuration, open the Boot tab and choose Advanced options.'; break }
   'StartupRepair' { Start-Process 'ms-settings:recovery'; return }
   'BCD' { $msg=(bcdedit /enum 2>&1 | Out-String); break }
   'Recovery' { Start-Process 'ms-settings:recovery'; return }
   'Protection' { Start-Process SystemPropertiesProtection.exe; return }
   'RestorePoint' { if((Show-AMRMessage 'Create a Windows restore point now? This may take a moment.' 'Confirm Restore Point' YesNo Warning) -ne 'Yes'){return}; Checkpoint-Computer -Description ('AMR Utility {0:yyyy-MM-dd HH:mm}' -f (Get-Date)) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; $msg='System restore point creation requested successfully.'; break }
   'SFC' { if((Show-AMRMessage 'Run System File Checker now? It may take several minutes.' 'Confirm SFC Scan' YesNo Warning) -ne 'Yes'){return}; Start-Process cmd.exe -Verb RunAs -ArgumentList '/k sfc /scannow'; return }
   'DISMCheck' { $msg=(DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String); break }
   'DISMRepair' { if((Show-AMRMessage 'Run DISM RestoreHealth? This may take a long time and requires internet access in some cases.' 'Confirm DISM Repair' YesNo Warning) -ne 'Yes'){return}; Start-Process cmd.exe -Verb RunAs -ArgumentList '/k DISM /Online /Cleanup-Image /RestoreHealth'; return }
   'CHKDSK' { $msg=(chkdsk.exe $env:SystemDrive /scan 2>&1 | Out-String); break }
   'Troubleshoot' { Start-Process 'ms-settings:troubleshoot'; return }
   'EventViewer' { Start-Process eventvwr.msc; return }
   'Reliability' { Start-Process perfmon.exe -ArgumentList '/rel'; return }
   'ResourceMonitor' { Start-Process resmon.exe; return }
   'PerfMon' { Start-Process perfmon.exe; return }
   'SystemInfo' { $p=Join-Path $env:USERPROFILE 'Desktop\AMR-System-Information.txt'; msinfo32.exe /report $p; $msg="System information report requested: $p"; break }
   'WinVersion' { Start-Process winver.exe; return }
   'RecentErrors' { $msg=(Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 30 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Format-List | Out-String); break }
   'Processes' { $msg=(Get-Process | Sort-Object CPU -Descending | Select-Object -First 35 Name,Id,CPU,WorkingSet64 | Format-Table -AutoSize | Out-String); break }
   'TaskManager' { Start-Process taskmgr.exe; return }
   'Services' { Start-Process services.msc; return }
   'AutoServices' { $msg=(Get-CimInstance Win32_Service | Where-Object {$_.StartMode -eq 'Auto'} | Select-Object Name,State,StartMode,DisplayName | Sort-Object Name | Format-Table -AutoSize | Out-String); break }
   'RestartWuauserv' { if((Show-AMRMessage 'Restart the Windows Update service? Downloads or updates in progress may be interrupted.' 'Confirm Service Restart' YesNo Warning) -ne 'Yes'){return}; Restart-Service wuauserv -Force -ErrorAction Stop; $msg='Windows Update service restarted.'; break }
   'DeviceManager' { Start-Process devmgmt.msc; return }
   'DiskHealth' { $msg=(Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Format-Table -AutoSize | Out-String); break }
   'Volumes' { $msg=(Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,Size,SizeRemaining | Format-Table -AutoSize | Out-String); break }
   'DiskMgmt' { Start-Process diskmgmt.msc; return }
   'OptimizeDrives' { Start-Process dfrgui.exe; return }
   'WindowsUpdate' { Start-Process 'ms-settings:windowsupdate'; return }
   'InstalledApps' { Start-Process 'ms-settings:appsfeatures'; return }
   'About' { Start-Process 'ms-settings:about'; return }
   'SysProperties' { Start-Process sysdm.cpl; return }
   'Environment' { Start-Process rundll32.exe -ArgumentList 'sysdm.cpl,EditEnvironmentVariables'; return }
   'UserAccounts' { Start-Process netplwiz.exe; return }
   'Regedit' { Start-Process regedit.exe; return }
   'GroupPolicy' { if(Test-Path "$env:windir\System32\gpedit.msc"){Start-Process gpedit.msc}else{$msg='Local Group Policy Editor is not available on this Windows edition.';break}; return }
   'WindowsSecurity' { Start-Process 'windowsdefender:'; return }
   'Activation' { $msg=(cscript.exe //nologo "$env:windir\system32\slmgr.vbs" /xpr 2>&1 | Out-String); break }
   'Maintenance' { Start-Process control.exe -ArgumentList '/name Microsoft.SecurityAndMaintenance'; return }
   'Backup' { Start-Process 'ms-settings:backup'; return }
   default { throw 'Unknown system tool.' }
  }
  Write-AMRLog ("System tool completed: {0}" -f $Key) SUCCESS System
  if ([string]::IsNullOrWhiteSpace([string]$msg)) {$msg='Command completed.'}
  Show-AMRMessage ([string]$msg) 'System Tool Result' OK Information | Out-Null
 } catch { Write-AMRLog ("System tool failed ({0}): {1}" -f $Key,$_.Exception.Message) ERROR System; Show-AMRMessage ("System tool failed:`n$($_.Exception.Message)") 'System Tool Error' OK Error | Out-Null }
}
function Update-AMRSystemView {
 $grid=C 'SysToolsGrid'; $grid.Children.Clear(); $search=[string](C 'SysSearchBox').Text
 $selected=(C 'SysCategoryFilter').SelectedItem; $category='All Categories'; if($selected){$category=([string]$selected.Content -replace '^⚙️\s*','')}
 $visible=0
 foreach($tool in $script:AMRSystemTools){
  if($category -ne 'All Categories' -and $tool.Category -ne $category){continue}
  $haystack=('{0} {1} {2}' -f $tool.Name,$tool.Category,$tool.Keywords)
  if(-not [string]::IsNullOrWhiteSpace($search) -and $haystack -notlike "*$search*"){continue}
  $button=New-Object System.Windows.Controls.Button; $button.Content=('⚙️  ' + $tool.Name); $button.Tag=$tool.Key; $button.Margin='0,0,10,10'; $button.Padding='12,10'; $button.MinHeight=48; $button.HorizontalContentAlignment='Left'; $button.ToolTip=("{0} • {1}" -f $tool.Category,$tool.Keywords)
  $button.Add_Click({Invoke-AMRSystemTool -Key ([string]$this.Tag)}.GetNewClosure()); [void]$grid.Children.Add($button); $visible++
 }
 (C 'SysResultsCount').Text=('{0} system tools shown' -f $visible)
}
(C 'SysSearchBox').Add_TextChanged({Update-AMRSystemView})
(C 'SysCategoryFilter').Add_SelectionChanged({Update-AMRSystemView})
Update-AMRSystemView

# NETWORK ENGINE - searchable, categorized network toolbox
$script:AMRNetworkTools = @(
@{Name='Flush System DNS Cache';Category='DNS & IP';Key='FlushDNS';Keywords='clear resolver cache ipconfig dns'},
@{Name='Display DNS Cache';Category='DNS & IP';Key='ShowDNS';Keywords='resolver cache inspect'},
@{Name='Renew DHCP IP Address';Category='DNS & IP';Key='RenewIP';Keywords='dhcp obtain lease'},
@{Name='Release DHCP IP Address';Category='DNS & IP';Key='ReleaseIP';Keywords='dhcp lease disconnect'},
@{Name='Show Full IP Configuration';Category='DNS & IP';Key='IPConfig';Keywords='ipconfig ipv4 ipv6 gateway dns'},
@{Name='Show IPv4 Configuration';Category='DNS & IP';Key='IPv4';Keywords='address subnet gateway'},
@{Name='Show IPv6 Configuration';Category='DNS & IP';Key='IPv6';Keywords='address'},
@{Name='Show Default Gateway';Category='DNS & IP';Key='Gateway';Keywords='router route'},
@{Name='Show DNS Servers';Category='DNS & IP';Key='DNSServers';Keywords='resolver'},
@{Name='Show DHCP Status';Category='DNS & IP';Key='DHCP';Keywords='lease configuration'},
@{Name='Display ARP Cache';Category='DNS & IP';Key='ARP';Keywords='neighbor mac address'},
@{Name='Clear ARP Cache';Category='DNS & IP';Key='ClearARP';Keywords='neighbor reset'},
@{Name='Show Routing Table';Category='DNS & IP';Key='Routes';Keywords='route print gateway'},
@{Name='Flush DNS and Renew IP';Category='Repair & Reset';Key='DNSRenew';Keywords='flush renew dhcp'},
@{Name='Reset TCP/IP Stack';Category='Repair & Reset';Key='ResetTCP';Keywords='netsh int ip reset'},
@{Name='Reset Winsock Catalog';Category='Repair & Reset';Key='ResetWinsock';Keywords='socket catalog reset'},
@{Name='Reset TCP/IP and Winsock';Category='Repair & Reset';Key='ResetBoth';Keywords='full reset restart'},
@{Name='Restart DNS Client Service';Category='Repair & Reset';Key='RestartDNS';Keywords='service resolver'},
@{Name='Open Network Troubleshooter';Category='Repair & Reset';Key='Troubleshooter';Keywords='settings diagnose windows'},
@{Name='Open Network Reset Settings';Category='Repair & Reset';Key='NetworkReset';Keywords='settings adapter reinstall'},
@{Name='List Network Adapters';Category='Adapters & Wi-Fi';Key='Adapters';Keywords='get-netadapter ethernet wireless'},
@{Name='Show Adapter Status';Category='Adapters & Wi-Fi';Key='AdapterStatus';Keywords='connected disconnected'},
@{Name='Show MAC Addresses';Category='Adapters & Wi-Fi';Key='MAC';Keywords='physical address hardware'},
@{Name='Show Wi-Fi Interface Details';Category='Adapters & Wi-Fi';Key='WiFi';Keywords='wlan wireless signal ssid'},
@{Name='Show Saved Wi-Fi Profiles';Category='Adapters & Wi-Fi';Key='WiFiProfiles';Keywords='wlan profiles'},
@{Name='Open Wi-Fi Settings';Category='Adapters & Wi-Fi';Key='WiFiSettings';Keywords='wireless settings'},
@{Name='Open Network Connections';Category='Adapters & Wi-Fi';Key='Connections';Keywords='ncpa.cpl adapter'},
@{Name='Open Adapter Properties';Category='Adapters & Wi-Fi';Key='AdapterProperties';Keywords='ncpa.cpl'},
@{Name='Show Network Connection Profiles';Category='Adapters & Wi-Fi';Key='Profiles';Keywords='public private domain'},
@{Name='Show Active TCP Connections';Category='Connections & Ports';Key='TCP';Keywords='netstat connections established'},
@{Name='Show Listening Ports';Category='Connections & Ports';Key='Listening';Keywords='netstat ports server'},
@{Name='Show UDP Endpoints';Category='Connections & Ports';Key='UDP';Keywords='netstat datagram'},
@{Name='Show TCP Statistics';Category='Connections & Ports';Key='TCPStats';Keywords='netstat statistics'},
@{Name='Show All Network Statistics';Category='Connections & Ports';Key='Netstat';Keywords='netstat -e -s'},
@{Name='Ping Internet DNS (1.1.1.1)';Category='Diagnostics';Key='PingCloudflare';Keywords='latency packet loss internet'},
@{Name='Ping Google DNS (8.8.8.8)';Category='Diagnostics';Key='PingGoogle';Keywords='latency internet'},
@{Name='Test DNS Resolution';Category='Diagnostics';Key='DNSResolve';Keywords='resolve-dnsname lookup domain'},
@{Name='Trace Route to Cloudflare';Category='Diagnostics';Key='TraceCloudflare';Keywords='tracert route hops'},
@{Name='Trace Route to Google';Category='Diagnostics';Key='TraceGoogle';Keywords='tracert route hops'},
@{Name='Test HTTPS Connectivity';Category='Diagnostics';Key='HTTPS';Keywords='tcp 443 web internet'},
@{Name='Test DNS Port 53';Category='Diagnostics';Key='TestDNSPort';Keywords='tcp udp port test-netconnection'},
@{Name='Test HTTP Port 80';Category='Diagnostics';Key='TestHTTP';Keywords='tcp web port'},
@{Name='Test HTTPS Port 443';Category='Diagnostics';Key='TestHTTPS';Keywords='tcp ssl tls port'},
@{Name='Test Microsoft Connectivity';Category='Diagnostics';Key='TestMicrosoft';Keywords='test connection microsoft.com'},
@{Name='Show Proxy Settings';Category='Reports & Settings';Key='Proxy';Keywords='winhttp proxy'},
@{Name='Show Firewall Profiles';Category='Reports & Settings';Key='Firewall';Keywords='windows defender firewall domain private public'},
@{Name='Open Windows Firewall';Category='Reports & Settings';Key='FirewallUI';Keywords='wf.msc security'},
@{Name='Show Hosts File';Category='Reports & Settings';Key='Hosts';Keywords='system drivers etc hostname'},
@{Name='Open Internet Options';Category='Reports & Settings';Key='InternetOptions';Keywords='inetcpl.cpl proxy'},
@{Name='Open Windows Network Status';Category='Reports & Settings';Key='NetworkStatus';Keywords='settings status'},
@{Name='Export Network Diagnostics Report';Category='Reports & Settings';Key='Report';Keywords='ipconfig all netstat report'}
)
function Invoke-AMRNetworkTool {
 param([Parameter(Mandatory=$true)][string]$Key)
 try {
  $adminKeys=@('ReleaseIP','RenewIP','ClearARP','ResetTCP','ResetWinsock','ResetBoth','RestartDNS')
  if ($Key -in $adminKeys -and -not (Test-AMRAdmin)) { Show-AMRMessage 'This action requires Administrator privileges. Reopen Amr Utility as Administrator and try again.' 'Administrator Required' OK Warning | Out-Null; return }
  switch ($Key) {
   'FlushDNS' { Clear-DnsClientCache -ErrorAction Stop; $msg='System DNS cache flushed successfully.'; break }
   'ShowDNS' { $msg=(ipconfig /displaydns 2>&1 | Out-String); break }
   'RenewIP' { ipconfig /renew | Out-Null; $msg='DHCP IP address renewal command completed.'; break }
   'ReleaseIP' { if ((Show-AMRMessage 'This temporarily disconnects network interfaces using DHCP. Continue?' 'Confirm IP Release' YesNo Warning) -ne 'Yes') { return }; ipconfig /release | Out-Null; $msg='DHCP release command completed.'; break }
   'IPConfig' { $msg=(ipconfig /all 2>&1 | Out-String); break }
   'IPv4' { $msg=(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Format-Table -AutoSize | Out-String); break }
   'IPv6' { $msg=(Get-NetIPAddress -AddressFamily IPv6 -ErrorAction Stop | Format-Table -AutoSize | Out-String); break }
   'Gateway' { $msg=(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Format-Table -AutoSize | Out-String); break }
   'DNSServers' { $msg=(Get-DnsClientServerAddress | Format-Table -AutoSize | Out-String); break }
   'DHCP' { $msg=(Get-NetIPInterface | Select-Object InterfaceAlias,AddressFamily,Dhcp,ConnectionState | Format-Table -AutoSize | Out-String); break }
   'ARP' { $msg=(arp -a | Out-String); break }
   'ClearARP' { netsh interface ip delete arpcache | Out-Null; $msg='ARP cache clear command completed.'; break }
   'Routes' { $msg=(route print | Out-String); break }
   'DNSRenew' { Clear-DnsClientCache -ErrorAction SilentlyContinue; ipconfig /renew | Out-Null; $msg='DNS cache cleared and DHCP renewal requested.'; break }
   'ResetTCP' { if ((Show-AMRMessage 'Resetting TCP/IP can affect network configuration and may require a restart. Continue?' 'Confirm TCP/IP Reset' YesNo Warning) -ne 'Yes') { return }; netsh int ip reset | Out-Null; $msg='TCP/IP reset requested. Restart Windows to complete the reset.'; break }
   'ResetWinsock' { if ((Show-AMRMessage 'Resetting Winsock can affect networking software and may require a restart. Continue?' 'Confirm Winsock Reset' YesNo Warning) -ne 'Yes') { return }; netsh winsock reset | Out-Null; $msg='Winsock reset requested. Restart Windows to complete the reset.'; break }
   'ResetBoth' { if ((Show-AMRMessage 'This resets TCP/IP and Winsock and may require a restart. Continue?' 'Confirm Network Reset' YesNo Warning) -ne 'Yes') { return }; netsh int ip reset | Out-Null; netsh winsock reset | Out-Null; $msg='TCP/IP and Winsock reset commands completed. Restart Windows.'; break }
   'RestartDNS' { Restart-Service Dnscache -Force -ErrorAction Stop; $msg='DNS Client service restart requested.'; break }
   'Troubleshooter' { Start-Process 'ms-settings:network-status'; return }
   'NetworkReset' { Start-Process 'ms-settings:network-advancedsettings'; return }
   'Adapters' { $msg=(Get-NetAdapter | Format-Table -AutoSize | Out-String); break }
   'AdapterStatus' { $msg=(Get-NetAdapter | Select-Object Name,Status,LinkSpeed,MediaType,MacAddress | Format-Table -AutoSize | Out-String); break }
   'MAC' { $msg=(Get-NetAdapter | Select-Object Name,MacAddress,Status | Format-Table -AutoSize | Out-String); break }
   'WiFi' { $msg=(netsh wlan show interfaces | Out-String); break }
   'WiFiProfiles' { $msg=(netsh wlan show profiles | Out-String); break }
   'WiFiSettings' { Start-Process 'ms-settings:network-wifi'; return }
   'Connections' { Start-Process ncpa.cpl; return }
   'AdapterProperties' { Start-Process ncpa.cpl; return }
   'Profiles' { $msg=(Get-NetConnectionProfile | Format-Table -AutoSize | Out-String); break }
   'TCP' { $msg=(Get-NetTCPConnection -ErrorAction Stop | Sort-Object State,RemoteAddress | Format-Table -AutoSize | Out-String); break }
   'Listening' { $msg=(Get-NetTCPConnection -State Listen -ErrorAction Stop | Select-Object LocalAddress,LocalPort,OwningProcess | Sort-Object LocalPort | Format-Table -AutoSize | Out-String); break }
   'UDP' { $msg=(Get-NetUDPEndpoint -ErrorAction Stop | Select-Object LocalAddress,LocalPort,OwningProcess | Sort-Object LocalPort | Format-Table -AutoSize | Out-String); break }
   'TCPStats' { $msg=(netstat -s -p tcp | Out-String); break }
   'Netstat' { $msg=(netstat -e -s | Out-String); break }
   'PingCloudflare' { $msg=(ping.exe -n 4 1.1.1.1 | Out-String); break }
   'PingGoogle' { $msg=(ping.exe -n 4 8.8.8.8 | Out-String); break }
   'DNSResolve' { $msg=(Resolve-DnsName 'example.com' -ErrorAction Stop | Format-Table -AutoSize | Out-String); break }
   'TraceCloudflare' { $msg=(tracert.exe -d -h 12 -w 700 1.1.1.1 | Out-String); break }
   'TraceGoogle' { $msg=(tracert.exe -d -h 12 -w 700 8.8.8.8 | Out-String); break }
   'HTTPS' { $r=Test-NetConnection www.microsoft.com -Port 443 -WarningAction SilentlyContinue; $msg=($r | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded | Out-String); break }
   'TestDNSPort' { $r=Test-NetConnection 1.1.1.1 -Port 53 -WarningAction SilentlyContinue; $msg=($r | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded | Out-String); break }
   'TestHTTP' { $r=Test-NetConnection example.com -Port 80 -WarningAction SilentlyContinue; $msg=($r | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded | Out-String); break }
   'TestHTTPS' { $r=Test-NetConnection example.com -Port 443 -WarningAction SilentlyContinue; $msg=($r | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded | Out-String); break }
   'TestMicrosoft' { $r=Test-NetConnection microsoft.com -Port 443 -WarningAction SilentlyContinue; $msg=($r | Format-List ComputerName,RemoteAddress,RemotePort,TcpTestSucceeded | Out-String); break }
   'Proxy' { $msg=(netsh winhttp show proxy | Out-String); break }
   'Firewall' { $msg=(Get-NetFirewallProfile | Format-Table Name,Enabled,DefaultInboundAction,DefaultOutboundAction -AutoSize | Out-String); break }
   'FirewallUI' { Start-Process wf.msc; return }
   'Hosts' { $msg=(Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction Stop | Out-String); break }
   'InternetOptions' { Start-Process inetcpl.cpl; return }
   'NetworkStatus' { Start-Process 'ms-settings:network-status'; return }
   'Report' { $dir=Join-Path $env:ProgramData 'AMR-Utility\NetworkReports'; New-Item -ItemType Directory -Path $dir -Force | Out-Null; $file=Join-Path $dir ('NetworkReport-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date)); ("AMR Utility Network Diagnostics Report`r`nGenerated: {0}`r`n`r`n" -f (Get-Date)) | Set-Content -LiteralPath $file -Encoding UTF8; $reportLines = @(& ipconfig /all; ''; & route print; ''; & arp -a; ''; & netstat -e -s); $reportLines | Add-Content -LiteralPath $file -Encoding UTF8; Start-Process notepad.exe -ArgumentList ('"{0}"' -f $file); Write-AMRLog ("Network report saved: {0}" -f $file) SUCCESS Network; return }
   default { throw 'Unknown network tool.' }
  }
  Write-AMRLog ("Network tool completed: {0}" -f $Key) SUCCESS Network
  if ([string]::IsNullOrWhiteSpace([string]$msg)) { $msg='Command completed. No output was returned.' }
  Show-AMRMessage ([string]$msg) 'Network Tool Result' OK Information | Out-Null
 } catch {
  Write-AMRLog ("Network tool failed ({0}): {1}" -f $Key,$_.Exception.Message) ERROR Network
  Show-AMRMessage ("Network tool failed:`n$($_.Exception.Message)") 'Network Tool Error' OK Error | Out-Null
 }
}
function Update-AMRNetworkView {
 $grid=C 'NetToolsGrid'; $grid.Children.Clear(); $search=[string](C 'NetSearchBox').Text
 $selected=(C 'NetCategoryFilter').SelectedItem; $category='All Categories'; if($selected){$category=([string]$selected.Content -replace '^⚙️\s*','')}
 $visible=0
 foreach($tool in $script:AMRNetworkTools){
  if($category -ne 'All Categories' -and $tool.Category -ne $category){continue}
  $haystack=('{0} {1} {2}' -f $tool.Name,$tool.Category,$tool.Keywords)
  if(-not [string]::IsNullOrWhiteSpace($search) -and $haystack -notlike "*$search*"){continue}
  $button=New-Object System.Windows.Controls.Button; $button.Content=('⚙️  ' + $tool.Name); $button.Tag=$tool.Key; $button.Margin='0,0,10,10'; $button.Padding='12,10'; $button.MinHeight=48; $button.HorizontalContentAlignment='Left'; $button.ToolTip=("{0} • {1}" -f $tool.Category,$tool.Keywords)
  $button.Add_Click({ Invoke-AMRNetworkTool -Key ([string]$this.Tag) }.GetNewClosure()); [void]$grid.Children.Add($button); $visible++
 }
 (C 'NetResultsCount').Text=('{0} network tools shown' -f $visible)
}
(C 'NetSearchBox').Add_TextChanged({ Update-AMRNetworkView })
(C 'NetCategoryFilter').Add_SelectionChanged({ Update-AMRNetworkView })
Update-AMRNetworkView

# ADVANCED DISK ANALYSIS - read-only inventory; no arbitrary drive deletion
function Get-AMRFolderBytes {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return [int64]0 }
    $items = @(Get-AMRCleanupFiles -Roots @($Path))
    $sum = [int64]0
    foreach ($item in $items) { try { $sum += [int64]$item.Length } catch {} }
    return $sum
}

(C 'CleanupDriveAnalyzeBtn').Add_Click({
    $button = C 'CleanupDriveAnalyzeBtn'; $button.IsEnabled = $false
    $report = New-Object System.Collections.Generic.List[string]
    try {
        Write-AMRLog 'Started fixed-drive analysis (read-only).' INFO Cleanup
        $report.Add('DRIVE OVERVIEW (read-only)')
        foreach ($drive in @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop)) {
            $size = [double]$drive.Size; $free = [double]$drive.FreeSpace
            $report.Add(('{0}  Total: {1:N2} GB  Free: {2:N2} GB  Used: {3:N2} GB' -f $drive.DeviceID,($size/1GB),($free/1GB),(($size-$free)/1GB)))
            Write-AMRLog ("Drive {0}: total {1:N2} GB, free {2:N2} GB, used {3:N2} GB." -f $drive.DeviceID,($size/1GB),($free/1GB),(($size-$free)/1GB)) INFO Cleanup
            $oldPath = Join-Path ($drive.DeviceID + '\') 'Windows.old'
            if (Test-Path -LiteralPath $oldPath -PathType Container) {
                $oldBytes = Get-AMRFolderBytes -Path $oldPath
                $report.Add(('  Windows.old: {0:N2} GB (review only; removal must use Windows Settings)' -f ($oldBytes/1GB)))
                Write-AMRLog ("Found Windows.old on {0}: {1:N2} GB (report only; not deleted)." -f $drive.DeviceID,($oldBytes/1GB)) INFO Cleanup
            }
            $binPath = Join-Path ($drive.DeviceID + '\') '$Recycle.Bin'
            if (Test-Path -LiteralPath $binPath -PathType Container) {
                $binBytes = Get-AMRFolderBytes -Path $binPath
                $report.Add(('  Recycle Bin data: {0:N2} GB (review only; empty separately after confirmation)' -f ($binBytes/1GB)))
                Write-AMRLog ("Found Recycle Bin data on {0}: {1:N2} GB (report only; not deleted)." -f $drive.DeviceID,($binBytes/1GB)) INFO Cleanup
            }
        }
        $report.Add('')
        $report.Add('SYSTEM RESTORE / SHADOW STORAGE (read-only)')
        $shadow = (& vssadmin.exe list shadowstorage 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0 -and $shadow.Trim()) { $report.Add($shadow.Trim()) } else { $report.Add('Shadow storage information is unavailable or access was denied.') }
        (C 'CleanupAdvancedReport').Text = ($report -join "`r`n")
        Write-AMRLog 'Advanced drive analysis completed (read-only).' SUCCESS Cleanup
    } catch {
        (C 'CleanupAdvancedReport').Text = ('Drive analysis failed: ' + $_.Exception.Message)
        Write-AMRLog "Advanced drive analysis failed: $_" ERROR Cleanup
    } finally { $button.IsEnabled = $true }
})

# Run DISM outside the WPF UI thread; poll its state with a DispatcherTimer.
$script:AMRDISMState = @{ Current = $null }
function Start-AMRDISMOperation {
    param(
        [ValidateSet('Analyze','Clean')][string]$Operation,
        [string[]]$Arguments
    )
    # Use a shared reference object for state updates from DispatcherTimer closures.
    # In Windows PowerShell 5.1, assigning a script-scoped variable inside a
    # GetNewClosure() event handler may update a different dynamic module scope.
    $currentJob = $script:AMRDISMState.Current
    if ($currentJob) {
        $stillRunning = $false
        try {
            $currentJob.Process.Refresh()
            $stillRunning = -not $currentJob.Process.HasExited
        } catch { $stillRunning = $false }
        if ($stillRunning -and -not $currentJob.Completed) {
            Write-AMRLog 'A DISM operation is already running.' WARNING Cleanup
            return
        }
        # Recover from stale state left by a completed process/timer.
        try { if ($currentJob.Timer) { $currentJob.Timer.Stop() } } catch {}
        try { if ($currentJob.Process) { $currentJob.Process.Dispose() } } catch {}
        foreach ($stalePath in @($currentJob.StdOut,$currentJob.StdErr)) {
            if ($stalePath) { Remove-Item -LiteralPath $stalePath -Force -ErrorAction SilentlyContinue }
        }
        $script:AMRDISMState.Current = $null
    }

    $analyzeButton = C 'CleanupComponentAnalyzeBtn'
    $cleanButton = C 'CleanupComponentRunBtn'
    if ($analyzeButton) { $analyzeButton.IsEnabled = $false }
    if ($cleanButton) { $cleanButton.IsEnabled = $false }

    $stamp = [Guid]::NewGuid().ToString('N')
    $stdoutPath = Join-Path $env:TEMP ("AMR-DISM-{0}.out.txt" -f $stamp)
    $stderrPath = Join-Path $env:TEMP ("AMR-DISM-{0}.err.txt" -f $stamp)
    try {
        Set-Content -LiteralPath $stdoutPath -Value '' -Encoding UTF8
        Set-Content -LiteralPath $stderrPath -Value '' -Encoding UTF8
        $dismPath = Join-Path $env:windir 'System32\dism.exe'
        $process = Start-Process -FilePath $dismPath -ArgumentList $Arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -ErrorAction Stop
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromMilliseconds(500)
        $script:AMRDISMState.Current = [pscustomobject]@{
            Process = $process; Timer = $timer; Operation = $Operation
            StdOut = $stdoutPath; StdErr = $stderrPath; Completed = $false
        }
        # Capture the operation object itself. GetNewClosure() creates a dynamic
        # module in Windows PowerShell 5.1; reading a script-scoped variable from
        # that event closure can resolve to a different script scope and return $null
        # on every tick, leaving the UI forever at "running in the background".
        $jobState = $script:AMRDISMState
        if ($Operation -eq 'Analyze') {
            Update-AMRCleanupProgress 10 'DISM analysis is running in the background...'
            Write-AMRLog 'DISM component store analysis started asynchronously.' INFO Cleanup
        } else {
            Update-AMRCleanupProgress 10 'DISM component cleanup is running in the background...'
            Write-AMRLog 'DISM StartComponentCleanup started asynchronously.' INFO Cleanup
        }
        $timer.Add_Tick({
            $job = $jobState.Current
            if (-not $job -or $job.Completed) { return }
            $exitCode = -999
            try {
                # Refresh is required for a reliable exit-state check when polling a process started asynchronously.
                $job.Process.Refresh()
                if (-not $job.Process.HasExited) {
                    if ((C 'CleanupProgressText')) { (C 'CleanupProgressText').Text = ('DISM {0} is running... The app remains available.' -f $job.Operation) }
                    return
                }
                $exitCode = $job.Process.ExitCode
            } catch {
                # Do not leave the UI stuck forever if the process handle can no longer be queried.
                Write-AMRLog ("DISM process state check failed: {0}" -f $_.Exception.Message) WARNING Cleanup
                try { if ($job.Process -and $job.Process.HasExited) { $exitCode = $job.Process.ExitCode } } catch {}
                if ($exitCode -eq -999) {
                    $job.Timer.Stop()
                    $job.Completed = $true
                    (C 'CleanupAdvancedReport').Text = ('DISM {0} process ended or became unavailable, but its exit code could not be read. Check C:\Windows\Logs\DISM\dism.log.' -f $job.Operation)
                    Update-AMRCleanupProgress 0 'DISM result could not be read. Check Cleanup Logs and the Windows DISM log.'
                    Write-AMRLog 'DISM process handle became unavailable before its exit code could be read.' ERROR Cleanup
                    foreach ($path in @($job.StdOut,$job.StdErr)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
                    try { $job.Process.Dispose() } catch {}
                    if ($jobState.Current -eq $job) { $jobState.Current = $null }
                    if ((C 'CleanupComponentAnalyzeBtn')) { (C 'CleanupComponentAnalyzeBtn').IsEnabled = $true }
                    if ((C 'CleanupComponentRunBtn')) { (C 'CleanupComponentRunBtn').IsEnabled = $false }
                    return
                }
            }
            $job.Timer.Stop()
            $job.Completed = $true
            try {
                $job.Process.WaitForExit()
                $stdout = if (Test-Path -LiteralPath $job.StdOut) { Get-Content -LiteralPath $job.StdOut -Raw -ErrorAction SilentlyContinue } else { '' }
                $stderr = if (Test-Path -LiteralPath $job.StdErr) { Get-Content -LiteralPath $job.StdErr -Raw -ErrorAction SilentlyContinue } else { '' }
                $parts = @($stdout,$stderr) | Where-Object { $_ -and $_.Trim() }
                $combined = ($parts -join "`r`n").Trim()
                if (-not $combined) { $combined = 'DISM did not return any text output.' }
                # Read the exit code only after output collection. In some Windows PowerShell 5.1
                # event-closure cases the first property read can be empty; retry from the process.
                $exitCode = $null
                try { $exitCode = [int]$job.Process.ExitCode } catch {}
                # If the exit code is unavailable but DISM explicitly reports success, do not
                # incorrectly disable the cleanup button. Keep genuine failures disabled.
                if (($null -eq $exitCode -or $exitCode -eq -999) -and $combined -match '(?im)The operation completed successfully\.') { $exitCode = 0 }
                if ($null -eq $exitCode -or $exitCode -eq -999) { $exitCode = 1 }
                if ($job.Operation -eq 'Analyze') {
                    (C 'CleanupAdvancedReport').Text = (('DISM Component Store Analysis (exit code {0})' -f $exitCode) + [Environment]::NewLine + $combined)
                    if ($exitCode -eq 0) {
                        (C 'CleanupComponentRunBtn').IsEnabled = $true
                        Write-AMRLog 'DISM component store analysis completed successfully.' SUCCESS Cleanup
                        Update-AMRCleanupProgress 100 'Component store analysis finished.'
                    } else {
                        (C 'CleanupComponentRunBtn').IsEnabled = $false
                        Write-AMRLog ("DISM component store analysis returned exit code {0}." -f $exitCode) WARNING Cleanup
                        Update-AMRCleanupProgress 0 'Component store analysis failed. Review the report and Cleanup Logs.'
                    }
                } else {
                    (C 'CleanupAdvancedReport').Text = (('DISM Component Cleanup (exit code {0})' -f $exitCode) + [Environment]::NewLine + $combined)
                    if ($exitCode -eq 0) {
                        Write-AMRLog 'DISM StartComponentCleanup completed successfully.' SUCCESS Cleanup
                        Update-AMRCleanupProgress 100 'DISM component cleanup finished.'
                        Show-AMRMessage 'Windows component cleanup completed. Run Analyze Component Store again to review the updated state.' 'Cleanup' OK Information | Out-Null
                    } else {
                        Write-AMRLog ("DISM component cleanup failed with exit code {0}." -f $exitCode) ERROR Cleanup
                        Update-AMRCleanupProgress 0 'DISM cleanup failed. Review the report and Cleanup Logs.'
                        Show-AMRMessage ("DISM component cleanup returned exit code {0}. Review the report and logs." -f $exitCode) 'Cleanup' OK Warning | Out-Null
                    }
                }
            } catch {
                (C 'CleanupAdvancedReport').Text = ('DISM result processing failed: ' + $_.Exception.Message)
                Write-AMRLog ("DISM result processing failed: {0}" -f $_.Exception.Message) ERROR Cleanup
            } finally {
                foreach ($path in @($job.StdOut,$job.StdErr)) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
                $job.Process.Dispose()
                if ($jobState.Current -eq $job) { $jobState.Current = $null }
                if ((C 'CleanupComponentAnalyzeBtn')) { (C 'CleanupComponentAnalyzeBtn').IsEnabled = $true }
                if ((C 'CleanupComponentRunBtn')) {
                    if ($job.Operation -eq 'Clean') { (C 'CleanupComponentRunBtn').IsEnabled = $true }
                    elseif ($exitCode -ne 0) { (C 'CleanupComponentRunBtn').IsEnabled = $false }
                }
            }
        }.GetNewClosure())
        $timer.Start()
    } catch {
        $script:AMRDISMState.Current = $null
        if ($analyzeButton) { $analyzeButton.IsEnabled = $true }
        if ($cleanButton) { $cleanButton.IsEnabled = $false }
        (C 'CleanupAdvancedReport').Text = ('Unable to start DISM: ' + $_.Exception.Message)
        Update-AMRCleanupProgress 0 'Unable to start DISM.'
        Write-AMRLog ("Unable to start DISM {0}: {1}" -f $Operation,$_.Exception.Message) ERROR Cleanup
        Remove-Item -LiteralPath $stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
    }
}

(C 'CleanupComponentAnalyzeBtn').Add_Click({
    Start-AMRDISMOperation -Operation Analyze -Arguments @('/Online','/Cleanup-Image','/AnalyzeComponentStore')
})

(C 'CleanupComponentRunBtn').Add_Click({
    $answer = Show-AMRMessage 'Run the Microsoft DISM StartComponentCleanup operation? This cleans superseded component versions using Windows servicing rules. It does not use ResetBase, but the operation can take time. Continue?' 'Confirm Windows Component Cleanup' YesNo Warning
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { Write-AMRLog 'User cancelled the selected cleanup operation at confirmation.' INFO Cleanup; return }
    Start-AMRDISMOperation -Operation Clean -Arguments @('/Online','/Cleanup-Image','/StartComponentCleanup')
})

# CLEANUP ENGINE - scan/review/confirm workflow (no deletion during scan)
$script:CleanupScanResults = @{}
$script:CleanupCategories = @(
    [pscustomobject]@{ Key='UserTemp'; Check='CleanupUserTempCheck'; Info='CleanupUserTempInfo'; Label='User temporary files'; Paths=@($env:TEMP) },
    [pscustomobject]@{ Key='WindowsTemp'; Check='CleanupWindowsTempCheck'; Info='CleanupWindowsTempInfo'; Label='Windows temporary files'; Paths=@((Join-Path $env:windir 'Temp')) },
    [pscustomobject]@{ Key='Update'; Check='CleanupUpdateCheck'; Info='CleanupUpdateInfo'; Label='Windows Update download cache'; Paths=@((Join-Path $env:windir 'SoftwareDistribution\Download')) },
    [pscustomobject]@{ Key='WER'; Check='CleanupWerCheck'; Info='CleanupWerInfo'; Label='Windows error reports'; Paths=@((Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'),(Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')) },
    [pscustomobject]@{ Key='Shader'; Check='CleanupShaderCheck'; Info='CleanupShaderInfo'; Label='DirectX shader cache'; Paths=@((Join-Path $env:LOCALAPPDATA 'D3DSCache')) },
    [pscustomobject]@{ Key='Delivery'; Check='CleanupDeliveryCheck'; Info='CleanupDeliveryInfo'; Label='Delivery Optimization cache'; Paths=@((Join-Path $env:ProgramData 'Microsoft\Windows\DeliveryOptimization\Cache')) }
)

function Get-AMRCleanupFiles {
    param([string[]]$Roots)
    $found = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $stack = New-Object System.Collections.Generic.Stack[string]
    foreach ($root in $Roots) { if ($root -and (Test-Path -LiteralPath $root -PathType Container)) { $stack.Push($root) } }
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($item in [System.IO.Directory]::EnumerateFileSystemEntries($current)) {
                try {
                    $attributes = [System.IO.File]::GetAttributes($item)
                    if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    if (($attributes -band [IO.FileAttributes]::Directory) -ne 0) { $stack.Push($item) }
                    else { $found.Add((New-Object -TypeName System.IO.FileInfo -ArgumentList $item)) }
                } catch { }
            }
        } catch { }
    }
    return $found.ToArray()
}

function Update-AMRCleanupProgress {
    param([int]$Value,[string]$Message)
    $ctl = C 'CleanupProgress'
    $txt = C 'CleanupProgressText'
    if ($ctl) { $ctl.Value = [Math]::Max(0,[Math]::Min(100,$Value)) }
    if ($txt) { $txt.Text = $Message }
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-AMRCleanupSelectedSummary {
    $selectedBytes = [int64]0
    $selectedFiles = 0
    foreach ($category in $script:CleanupCategories) {
        $check = C $category.Check
        if ($check -and $check.IsChecked -eq $true -and $script:CleanupScanResults.ContainsKey($category.Key)) {
            $result = $script:CleanupScanResults[$category.Key]
            $selectedBytes += [int64]$result.Bytes
            $selectedFiles += [int]$result.Count
        }
    }
    $summary = C 'CleanupSelectedSummary'
    if ($summary) {
        $summary.Text = ('Selected: {0:N0} files • {1:N2} MB' -f $selectedFiles,($selectedBytes / 1MB))
    }
}

# Update the selected total immediately when the user changes any category checkbox.
foreach ($category in $script:CleanupCategories) {
    $checkBox = C $category.Check
    if ($checkBox) {
        $checkBox.Add_Click({ Update-AMRCleanupSelectedSummary })
    }
}

(C 'CleanupScanBtn').Add_Click({
    $scanButton = C 'CleanupScanBtn'
    $runButton = C 'CleanupRunBtn'
    $scanButton.IsEnabled = $false; $runButton.IsEnabled = $false
    $script:CleanupScanResults = @{}
    $totalBytes = [int64]0; $totalFiles = 0; $index = 0
    try {
        Write-AMRLog 'Cleanup category scan started.' INFO Cleanup
        foreach ($category in $script:CleanupCategories) {
            $index++
            Update-AMRCleanupProgress ([int](($index - 1) * 100 / $script:CleanupCategories.Count)) ("Scanning: {0}" -f $category.Label)
            $files = @(Get-AMRCleanupFiles -Roots $category.Paths)
            $bytes = [int64]0
            foreach ($file in $files) { try { $bytes += $file.Length } catch {} }
            $script:CleanupScanResults[$category.Key] = [pscustomobject]@{ Files=$files; Bytes=$bytes; Count=$files.Count }
            $info = C $category.Info
            if ($info) { $info.Text = ('{0:N0} files • {1:N2} MB' -f $files.Count,($bytes / 1MB)) }
            $totalBytes += $bytes; $totalFiles += $files.Count
            Write-AMRLog ("Scanned {0}: {1:N0} files, {2:N2} MB." -f $category.Label,$files.Count,($bytes/1MB)) INFO Cleanup
        }
        (C 'CleanupScanSummary').Text = ('Scan complete: {0:N0} files • {1:N2} MB potentially recoverable.' -f $totalFiles,($totalBytes / 1MB))
        $runButton.IsEnabled = $true
        Update-AMRCleanupSelectedSummary
        Update-AMRCleanupProgress 100 'Scan complete. Review the categories and select what you want to clean.'
        Write-AMRLog ("Cleanup scan completed: {0} files, {1:N2} MB found." -f $totalFiles,($totalBytes / 1MB)) INFO Cleanup
    } catch {
        Update-AMRCleanupProgress 0 'Scan failed. Check the application log.'
        Write-AMRLog "Cleanup scan failed: $_" ERROR Cleanup
        Show-AMRMessage "Cleanup scan failed:`n$_" 'Cleanup' OK Error | Out-Null
    } finally { $scanButton.IsEnabled = $true }
})

(C 'CleanupRunBtn').Add_Click({
    $selected = @($script:CleanupCategories | Where-Object { (C $_.Check).IsChecked -eq $true })
    if ($selected.Count -eq 0) {
        Show-AMRMessage 'Select at least one scanned category first.' 'Cleanup' OK Warning | Out-Null
        return
    }
    $notScanned = @($selected | Where-Object { -not $script:CleanupScanResults.ContainsKey($_.Key) })
    if ($notScanned.Count -gt 0) {
        Show-AMRMessage 'Please run Scan Now before cleaning.' 'Cleanup' OK Warning | Out-Null
        return
    }
    $estimate = [int64]0; $filesEstimate = 0
    foreach ($cat in $selected) { $estimate += $script:CleanupScanResults[$cat.Key].Bytes; $filesEstimate += $script:CleanupScanResults[$cat.Key].Count }
    $names = ($selected | ForEach-Object { $_.Label }) -join "`n• "
    $answer = Show-AMRMessage ("You are about to remove the selected temporary/cache files:`n`n• $names`n`nEstimated: {0:N0} files ({1:N2} MB).`n`nThis cannot be undone. Continue?" -f $filesEstimate,($estimate / 1MB)) 'Confirm Cleanup' YesNo Warning
    if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { Write-AMRLog 'User cancelled the selected cleanup operation at confirmation.' INFO Cleanup; return }
    Write-AMRLog ("Cleanup confirmed. Selected categories: {0}; estimate: {1:N0} files, {2:N2} MB." -f (($selected | ForEach-Object { $_.Label }) -join ', '),$filesEstimate,($estimate/1MB)) INFO Cleanup

    $runButton = C 'CleanupRunBtn'; $scanButton = C 'CleanupScanBtn'
    $runButton.IsEnabled = $false; $scanButton.IsEnabled = $false
    $deleted = 0; $failed = 0; $done = 0
    $updateWasRunning = $false; $updateServiceTouched = $false
    try {
        if ($selected.Key -contains 'Update') {
            $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') { $updateWasRunning = $true }
            if ($svc) { Stop-Service -Name wuauserv -Force -ErrorAction Stop; $updateServiceTouched = $true }
        }
        foreach ($cat in $selected) {
            $result = $script:CleanupScanResults[$cat.Key]
            $fileList = @($result.Files)
            $fileIndex = 0
            Write-AMRLog ("Cleaning category {0}: {1} files." -f $cat.Label,$fileList.Count) INFO Cleanup
            foreach ($file in $fileList) {
                $fileIndex++
                try {
                    if (Test-Path -LiteralPath $file.FullName -PathType Leaf) {
                        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                        $deleted++
                        Write-AMRLog ("Deleted file: {0} ({1:N2} MB)." -f $file.FullName,([double]$file.Length/1MB)) SUCCESS Cleanup
                    } else {
                        $failed++
                        Write-AMRLog ("Skipped file because it no longer exists or is inaccessible: {0}" -f $file.FullName) WARNING Cleanup
                    }
                } catch { $failed++; Write-AMRLog ("Failed to delete file: {0}. Reason: {1}" -f $file.FullName,$_.Exception.Message) WARNING Cleanup }
                if (($fileIndex % 40) -eq 0 -or $fileIndex -eq $fileList.Count) {
                    $pct = [int](($done + $fileIndex) * 100 / [Math]::Max(1,$filesEstimate))
                    Update-AMRCleanupProgress $pct ("Cleaning {0}: {1}/{2} files • removed {3}" -f $cat.Label,$fileIndex,$fileList.Count,$deleted)
                }
            }
            $done += $fileList.Count
        }
    } catch {
        $failed++
        Write-AMRLog "Cleanup operation error: $_" ERROR Cleanup
    } finally {
        if ($updateServiceTouched -and $updateWasRunning) { try { Start-Service -Name wuauserv -ErrorAction Stop } catch { $failed++; Write-AMRLog "Could not restart Windows Update service: $_" ERROR Cleanup } }
        $runButton.IsEnabled = $true; $scanButton.IsEnabled = $true
    }
    $summary = "Cleanup finished.`nRemoved: $deleted files`nSkipped/failed: $failed files`nRun Scan Now again to refresh the estimates."
    Update-AMRCleanupProgress 100 ("Finished • removed {0} • skipped/failed {1}" -f $deleted,$failed)
    (C 'CleanupScanSummary').Text = 'Cleanup finished. Scan again to refresh the results.'
    foreach ($cat in $selected) { (C $cat.Info).Text = 'Rescan required' }
    $script:CleanupScanResults = @{}
    Update-AMRCleanupSelectedSummary
    Write-AMRLog ("Cleanup completed. Removed: {0}; skipped/failed: {1}." -f $deleted,$failed) SUCCESS Cleanup
    Show-AMRMessage $summary 'Cleanup Results' OK Information | Out-Null
})

# BACKUP ENGINE - searchable catalog; all actions export/report unless explicitly creating restore point
$script:BackupActions = @(
@{Name='Create System Restore Point';Category='Recovery';Key='RestorePoint'},
@{Name='Export Safety Registry Backup';Category='Registry & System';Key='Registry'},
@{Name='Export All User Registry (HKCU)';Category='Registry & System';Key='HKCU'},
@{Name='Export Machine Software Registry';Category='Registry & System';Key='HKLMSoftware'},
@{Name='Export Installed Programs';Category='Configuration & Reports';Key='Programs'},
@{Name='Export Installed Windows Features';Category='Configuration & Reports';Key='Features'},
@{Name='Export Optional Features';Category='Configuration & Reports';Key='OptionalFeatures'},
@{Name='Export Drivers List';Category='Drivers & Hardware';Key='DriversList'},
@{Name='Export Third-Party Drivers';Category='Drivers & Hardware';Key='DriverExport'},
@{Name='Export Network Adapter Configuration';Category='Network';Key='IPConfig'},
@{Name='Export IP Routing Table';Category='Network';Key='Routes'},
@{Name='Export DNS Cache';Category='Network';Key='DNSCache'},
@{Name='Export Wi-Fi Profiles';Category='Network';Key='WifiProfiles'},
@{Name='Export Wi-Fi Profiles (XML)';Category='Network';Key='WifiXml'},
@{Name='Export Firewall Rules';Category='Security';Key='Firewall'},
@{Name='Export Firewall Configuration';Category='Security';Key='FirewallCfg'},
@{Name='Export Local Users';Category='Security';Key='Users'},
@{Name='Export Local Groups';Category='Security';Key='Groups'},
@{Name='Export Local Group Membership';Category='Security';Key='GroupMembers'},
@{Name='Export Services List';Category='Configuration & Reports';Key='Services'},
@{Name='Export Running Services';Category='Configuration & Reports';Key='RunningServices'},
@{Name='Export Scheduled Tasks';Category='Configuration & Reports';Key='Tasks'},
@{Name='Export Startup Commands';Category='Configuration & Reports';Key='Startup'},
@{Name='Export Environment Variables';Category='Configuration & Reports';Key='Environment'},
@{Name='Export System Information';Category='Configuration & Reports';Key='SystemInfo'},
@{Name='Export Windows Version';Category='Configuration & Reports';Key='WindowsVersion'},
@{Name='Export Boot Configuration (BCD)';Category='Recovery';Key='BCD'},
@{Name='Export Disk Partition Layout';Category='Recovery';Key='Disks'},
@{Name='Export Volume List';Category='Recovery';Key='Volumes'},
@{Name='Export BitLocker Status';Category='Security';Key='BitLocker'},
@{Name='Export Certificates (Current User)';Category='Security';Key='Certificates'},
@{Name='Export Trusted Root Certificates';Category='Security';Key='RootCerts'},
@{Name='Export Hosts File';Category='Network';Key='Hosts'},
@{Name='Export Proxy Settings';Category='Network';Key='Proxy'},
@{Name='Export Windows Update History';Category='Configuration & Reports';Key='Updates'},
@{Name='Export Restore Point Inventory';Category='Recovery';Key='RestoreInventory'},
@{Name='Export Shadow Storage';Category='Recovery';Key='ShadowStorage'},
@{Name='Export System Protection Status';Category='Recovery';Key='Protection'},
@{Name='Export Event Log List';Category='Configuration & Reports';Key='EventLogs'},
@{Name='Export Recent System Errors';Category='Configuration & Reports';Key='SystemErrors'},
@{Name='Export Disk Health Summary';Category='Drivers & Hardware';Key='DiskHealth'},
@{Name='Export PnP Device List';Category='Drivers & Hardware';Key='Devices'},
@{Name='Export Audio Devices';Category='Drivers & Hardware';Key='Audio'},
@{Name='Export Printer List';Category='Drivers & Hardware';Key='Printers'},
@{Name='Export SMB Shares';Category='Network';Key='Shares'},
@{Name='Export Network Profiles';Category='Network';Key='NetProfiles'},
@{Name='Export Windows Defender Status';Category='Security';Key='Defender'},
@{Name='Export Defender Threat History';Category='Security';Key='Threats'},
@{Name='Export Power Plans';Category='Configuration & Reports';Key='PowerPlans'},
@{Name='Open Backup Folder';Category='Recovery';Key='OpenFolder'}
)

function Invoke-AMRBackupAction {
 param([string]$Key)
 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
 $out=Join-Path $script:BackupDir ("Backup_{0}_{1}.txt" -f $Key,$stamp)
 try {
  switch ($Key) {
   'RestorePoint' {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer -Description "AMR-Utility Restore Point $stamp" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    # A restore point is stored by Windows, not as a desktop file. Add a desktop shortcut to launch System Protection.
    try { $desk=[Environment]::GetFolderPath('Desktop'); $lnk=Join-Path $desk 'AMR System Protection.lnk'; $w=New-Object -ComObject WScript.Shell; $sc=$w.CreateShortcut($lnk); $sc.TargetPath="$env:windir\System32\SystemPropertiesProtection.exe"; $sc.Description='Open Windows System Protection and restore point settings'; $sc.Save() } catch { Write-AMRLog "Restore point created; desktop shortcut could not be created: $_" WARNING System }
    Write-AMRLog 'Created System Restore Point.' SUCCESS System
    Show-AMRMessage "Restore point created successfully.`nA desktop shortcut to System Protection was added (if permitted)." 'Backup' OK Information | Out-Null; return
   }
   'Registry' { & reg.exe export 'HKCU\Software' (Join-Path $script:BackupDir ("HKCU_Backup_{0}.reg" -f $stamp)) /y | Out-Null; if($LASTEXITCODE -ne 0){throw "reg.exe returned exit code $LASTEXITCODE"}; $out=Join-Path $script:BackupDir ("HKCU_Backup_{0}.reg" -f $stamp); break }
   'HKCU' { & reg.exe export HKCU $out.Replace('.txt','.reg') /y | Out-Null; if($LASTEXITCODE -ne 0){throw "reg.exe returned exit code $LASTEXITCODE"}; $out=$out.Replace('.txt','.reg'); break }
   'HKLMSoftware' { & reg.exe export 'HKLM\SOFTWARE' $out.Replace('.txt','.reg') /y | Out-Null; if($LASTEXITCODE -ne 0){throw "reg.exe returned exit code $LASTEXITCODE"}; $out=$out.Replace('.txt','.reg'); break }
   'RegHives' { & reg.exe query HKLM | Out-File $out -Encoding UTF8; break }
   'Programs' { Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*,HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | Sort-Object DisplayName | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Features' { Get-WindowsOptionalFeature -Online | Select-Object FeatureName,State | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'OptionalFeatures' { Get-WindowsOptionalFeature -Online | Format-Table -AutoSize | Out-String | Set-Content $out -Encoding UTF8; break }
   'DriversList' { Get-CimInstance Win32_PnPSignedDriver | Select-Object DeviceName,Manufacturer,DriverVersion,DriverDate,InfName | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'DriverExport' { $dest=Join-Path $script:BackupDir ("Drivers_{0}" -f $stamp); New-Item -ItemType Directory -Path $dest -Force | Out-Null; & pnputil.exe /export-driver '*' $dest 2>&1 | Out-File $out -Encoding UTF8; break }
   'IPConfig' { & ipconfig.exe /all | Out-File $out -Encoding UTF8; break }
   'Routes' { & route.exe print | Out-File $out -Encoding UTF8; break }
   'DNSCache' { & ipconfig.exe /displaydns | Out-File $out -Encoding UTF8; break }
   'WifiProfiles' { & netsh.exe wlan show profiles | Out-File $out -Encoding UTF8; break }
   'WifiXml' { $dest=Join-Path $script:BackupDir ("WiFiProfiles_{0}" -f $stamp); New-Item -ItemType Directory -Path $dest -Force | Out-Null; & netsh.exe wlan export profile folder="$dest" 2>&1 | Out-File $out -Encoding UTF8; break }
   'Firewall' { & netsh.exe advfirewall export (Join-Path $script:BackupDir ("Firewall_{0}.wfw" -f $stamp)) | Out-File $out -Encoding UTF8; break }
   'FirewallCfg' { Get-NetFirewallProfile | Format-List * | Out-File $out -Encoding UTF8; break }
   'Users' { Get-LocalUser | Select-Object Name,Enabled,LastLogon,PasswordRequired,Description | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Groups' { Get-LocalGroup | Select-Object Name,Description | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'GroupMembers' { Get-LocalGroup | ForEach-Object { $g=$_.Name; Get-LocalGroupMember -Group $g -ErrorAction SilentlyContinue | Select-Object @{n='Group';e={$g}},Name,ObjectClass,PrincipalSource } | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Services' { Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,StartMode,StartName,PathName | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'RunningServices' { Get-Service | Where-Object Status -eq Running | Select-Object Name,DisplayName,Status | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Tasks' { Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Description | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Startup' { Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Environment' { Get-ChildItem Env: | Sort-Object Name | Format-Table -AutoSize | Out-String | Set-Content $out -Encoding UTF8; break }
   'SystemInfo' { & systeminfo.exe | Out-File $out -Encoding UTF8; break }
   'WindowsVersion' { Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsBuildNumber,OsArchitecture,WindowsInstallationType | Format-List | Out-File $out -Encoding UTF8; break }
   'BCD' { & bcdedit.exe /enum all | Out-File $out -Encoding UTF8; break }
   'Disks' { Get-Disk | Select-Object Number,FriendlyName,SerialNumber,PartitionStyle,OperationalStatus,Size | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Volumes' { Get-Volume | Select-Object DriveLetter,FileSystemLabel,FileSystem,HealthStatus,Size,SizeRemaining | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'BitLocker' { Get-BitLockerVolume | Select-Object MountPoint,VolumeType,VolumeStatus,ProtectionStatus,EncryptionMethod,EncryptionPercentage | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Certificates' { Get-ChildItem Cert:\CurrentUser\My | Select-Object Subject,Issuer,Thumbprint,NotBefore,NotAfter | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'RootCerts' { Get-ChildItem Cert:\CurrentUser\Root | Select-Object Subject,Issuer,Thumbprint,NotBefore,NotAfter | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Hosts' { Copy-Item "$env:windir\System32\drivers\etc\hosts" (Join-Path $script:BackupDir ("hosts_{0}.txt" -f $stamp)) -Force; $out=Join-Path $script:BackupDir ("hosts_{0}.txt" -f $stamp); break }
   'Proxy' { Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable,ProxyServer,ProxyOverride,AutoConfigURL | Format-List | Out-File $out -Encoding UTF8; break }
   'Updates' { Get-HotFix | Select-Object HotFixID,Description,InstalledBy,InstalledOn | Sort-Object InstalledOn -Descending | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'RestoreInventory' { Get-ComputerRestorePoint -ErrorAction Stop | Select-Object SequenceNumber,Description,CreationTime,RestorePointType,EventType | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'ShadowStorage' { & vssadmin.exe list shadowstorage | Out-File $out -Encoding UTF8; break }
   'Protection' { & powershell.exe -NoProfile -Command "Get-ComputerRestorePoint | Select-Object SequenceNumber,Description,CreationTime | Format-Table -AutoSize" | Out-File $out -Encoding UTF8; break }
   'EventLogs' { Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Select-Object LogName,RecordCount,IsEnabled,MaximumSizeInBytes | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'SystemErrors' { Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 300 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'DiskHealth' { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,Size | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Devices' { Get-PnpDevice -PresentOnly | Select-Object Class,FriendlyName,Status,InstanceId | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Audio' { Get-CimInstance Win32_SoundDevice | Select-Object Name,Manufacturer,Status,PNPDeviceID | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Printers' { Get-Printer | Select-Object Name,DriverName,PortName,PrinterStatus,Shared | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Shares' { Get-SmbShare | Select-Object Name,Path,Description,ShareState | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'NetProfiles' { Get-NetConnectionProfile | Select-Object Name,InterfaceAlias,NetworkCategory,IPv4Connectivity,IPv6Connectivity | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'Defender' { Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureLastUpdated,QuickScanAge,FullScanAge | Format-List | Out-File $out -Encoding UTF8; break }
   'Threats' { Get-MpThreatDetection | Select-Object InitialDetectionTime,ThreatID,ThreatStatusID,ActionSuccess,Resources | Export-Csv $out -NoTypeInformation -Encoding UTF8; break }
   'PowerPlans' { & powercfg.exe /list | Out-File $out -Encoding UTF8; break }
   'OpenFolder' { Start-Process explorer.exe -ArgumentList $script:BackupDir; return }
   default { throw 'Unknown backup action.' }
  }
  Write-AMRLog ("Backup export completed: {0} -> {1}" -f $Key,$out) SUCCESS System
  Show-AMRMessage ("Backup/export completed.`nSaved to:`n$out") 'Backup' OK Information | Out-Null
 } catch {
  Write-AMRLog ("Backup action failed ({0}): {1}" -f $Key,$_.Exception.Message) ERROR System
  Show-AMRMessage ("Backup action failed:`n$($_.Exception.Message)") 'Backup Error' OK Error | Out-Null
 }
}

function Update-AMRBackupView {
 $grid=C 'BackupActionsGrid'; $grid.Children.Clear(); $search=[string](C 'BackupSearchBox').Text
 $selected=(C 'BackupCategoryFilter').SelectedItem; $category='All Categories'; if($selected){$category=([string]$selected.Content -replace '^⚙️\s*','')}
 $visible=0
 foreach($a in $script:BackupActions){
  if($category -ne 'All Categories' -and $a.Category -ne $category){continue}
  if(-not [string]::IsNullOrWhiteSpace($search) -and ($a.Name -notlike "*$search*" -and $a.Category -notlike "*$search*")){continue}
  $b=New-Object System.Windows.Controls.Button; $b.Content=$a.Name; $b.Tag=$a.Key; $b.Margin='0,0,10,10'; $b.Padding='12,10'; $b.MinHeight=48; $b.HorizontalContentAlignment='Left'; $b.ToolTip=("Category: {0}" -f $a.Category)
  $b.Add_Click({ Invoke-AMRBackupAction -Key ([string]$this.Tag) }.GetNewClosure()); [void]$grid.Children.Add($b); $visible++
 }
 (C 'BackupResultsCount').Text=('{0} backup actions shown' -f $visible)
}
(C 'BackupSearchBox').Add_TextChanged({ Update-AMRBackupView })
(C 'BackupCategoryFilter').Add_SelectionChanged({ Update-AMRBackupView })
Update-AMRBackupView

# UTILITIES ENGINE
function Start-AMRUtility {
    param([Parameter(Mandatory=$true)][string]$Name, [Parameter(Mandatory=$true)][string]$File, [string]$Arguments = '')
    try {
        if ([string]::IsNullOrWhiteSpace($Arguments)) { Start-Process -FilePath $File -ErrorAction Stop | Out-Null }
        else { Start-Process -FilePath $File -ArgumentList $Arguments -ErrorAction Stop | Out-Null }
        Write-AMRLog ("Opened utility: {0}" -f $Name) SUCCESS System
    } catch {
        $message = ("Could not open {0}: {1}" -f $Name, $_.Exception.Message)
        Write-AMRLog $message WARNING System
        Show-AMRMessage $message 'Utility unavailable' OK Warning | Out-Null
    }
}
(C 'UtilControlPanelBtn').Add_Click({ Start-AMRUtility 'Classic Control Panel' 'control.exe' })
(C 'UtilRegeditBtn').Add_Click({ Start-AMRUtility 'Registry Editor' 'regedit.exe' })
(C 'UtilDevMgmtBtn').Add_Click({ Start-AMRUtility 'Device Manager' 'devmgmt.msc' })
(C 'UtilSysInfoBtn').Add_Click({ Start-AMRUtility 'System Information' 'msinfo32.exe' })
(C 'UtilTaskMgrBtn').Add_Click({ Start-AMRUtility 'Task Manager' 'taskmgr.exe' })
(C 'UtilServicesBtn').Add_Click({ Start-AMRUtility 'Services' 'services.msc' })
(C 'UtilEventViewerBtn').Add_Click({ Start-AMRUtility 'Event Viewer' 'eventvwr.msc' })
(C 'UtilResourceMonitorBtn').Add_Click({ Start-AMRUtility 'Resource Monitor' 'resmon.exe' })
(C 'UtilPerformanceMonitorBtn').Add_Click({ Start-AMRUtility 'Performance Monitor' 'perfmon.exe' })
(C 'UtilDiskMgmtBtn').Add_Click({ Start-AMRUtility 'Disk Management' 'diskmgmt.msc' })
(C 'UtilComputerMgmtBtn').Add_Click({ Start-AMRUtility 'Computer Management' 'compmgmt.msc' })
(C 'UtilTaskSchedulerBtn').Add_Click({ Start-AMRUtility 'Task Scheduler' 'taskschd.msc' })
(C 'UtilFirewallAdvancedBtn').Add_Click({ Start-AMRUtility 'Advanced Firewall' 'wf.msc' })
(C 'UtilNetworkConnectionsBtn').Add_Click({ Start-AMRUtility 'Network Connections' 'ncpa.cpl' })
(C 'UtilSystemPropertiesBtn').Add_Click({ Start-AMRUtility 'System Properties' 'sysdm.cpl' })
(C 'UtilProgramsFeaturesBtn').Add_Click({ Start-AMRUtility 'Programs and Features' 'appwiz.cpl' })
(C 'UtilWindowsFeaturesBtn').Add_Click({ Start-AMRUtility 'Windows Features' 'optionalfeatures.exe' })
(C 'UtilPowerOptionsBtn').Add_Click({ Start-AMRUtility 'Power Options' 'powercfg.cpl' })
(C 'UtilSoundBtn').Add_Click({ Start-AMRUtility 'Sound Settings' 'mmsys.cpl' })
(C 'UtilMemoryDiagnosticBtn').Add_Click({ Start-AMRUtility 'Windows Memory Diagnostic' 'mdsched.exe' })
(C 'UtilCertificatesBtn').Add_Click({ Start-AMRUtility 'Certificate Manager' 'certmgr.msc' })
(C 'UtilCredentialManagerBtn').Add_Click({ Start-AMRUtility 'Credential Manager' 'control.exe' '/name Microsoft.CredentialManager' })
(C 'UtilGroupPolicyBtn').Add_Click({ Start-AMRUtility 'Local Group Policy' 'gpedit.msc' })
(C 'UtilLocalUsersBtn').Add_Click({ Start-AMRUtility 'Local Users and Groups' 'lusrmgr.msc' })
(C 'UtilTPMBtn').Add_Click({ Start-AMRUtility 'TPM Management' 'tpm.msc' })
(C 'UtilSystemConfigBtn').Add_Click({ Start-AMRUtility 'System Configuration' 'msconfig.exe' })
(C 'UtilAboutWindowsBtn').Add_Click({ Start-AMRUtility 'About Windows' 'winver.exe' })
(C 'UtilAdvancedStartupBtn').Add_Click({ Start-AMRUtility 'Advanced Startup Options' 'control.exe' '/name Microsoft.Recovery' })
(C 'UtilRecoveryBtn').Add_Click({ Start-AMRUtility 'Recovery Options' 'SystemPropertiesProtection.exe' })
(C 'UtilWindowsUpdateBtn').Add_Click({ Start-AMRUtility 'Windows Update' 'cmd.exe' '/c start ms-settings:windowsupdate' })
(C 'UtilStorageSettingsBtn').Add_Click({ Start-AMRUtility 'Storage Settings' 'cmd.exe' '/c start ms-settings:storagesense' })
(C 'UtilAppsSettingsBtn').Add_Click({ Start-AMRUtility 'Installed Apps' 'cmd.exe' '/c start ms-settings:appsfeatures' })
(C 'UtilPrivacySettingsBtn').Add_Click({ Start-AMRUtility 'Privacy Settings' 'cmd.exe' '/c start ms-settings:privacy' })
(C 'UtilProxySettingsBtn').Add_Click({ Start-AMRUtility 'Proxy Settings' 'cmd.exe' '/c start ms-settings:network-proxy' })
(C 'UtilBluetoothBtn').Add_Click({ Start-AMRUtility 'Bluetooth Settings' 'cmd.exe' '/c start ms-settings:bluetooth' })
(C 'UtilDisplaySettingsBtn').Add_Click({ Start-AMRUtility 'Display Settings' 'cmd.exe' '/c start ms-settings:display' })
(C 'UtilMouseSettingsBtn').Add_Click({ Start-AMRUtility 'Mouse Settings' 'main.cpl' })
(C 'UtilKeyboardSettingsBtn').Add_Click({ Start-AMRUtility 'Keyboard Settings' 'control.exe' 'keyboard' })
(C 'UtilPrintersBtn').Add_Click({ Start-AMRUtility 'Printers and Scanners' 'cmd.exe' '/c start ms-settings:printers' })
(C 'UtilDateTimeBtn').Add_Click({ Start-AMRUtility 'Date and Time Settings' 'timedate.cpl' })
(C 'UtilRegionBtn').Add_Click({ Start-AMRUtility 'Region Settings' 'intl.cpl' })
(C 'UtilEnvVariablesBtn').Add_Click({ Start-AMRUtility 'Environment Variables' 'rundll32.exe' 'sysdm.cpl,EditEnvironmentVariables' })
(C 'UtilWindowsDefenderBtn').Add_Click({ Start-AMRUtility 'Windows Security' 'cmd.exe' '/c start windowsdefender:' })
(C 'UtilReliabilityBtn').Add_Click({ Start-AMRUtility 'Reliability Monitor' 'perfmon.exe' '/rel' })
(C 'UtilStepsRecorderBtn').Add_Click({ Start-AMRUtility 'Steps Recorder' 'psr.exe' })
(C 'UtilDiskCleanupBtn').Add_Click({ Start-AMRUtility 'Disk Cleanup' 'cleanmgr.exe' })
(C 'UtilNetworkResetBtn').Add_Click({ Start-AMRUtility 'Network Status' 'cmd.exe' '/c start ms-settings:network-status' })
(C 'UtilIndexingBtn').Add_Click({ Start-AMRUtility 'Indexing Options' 'control.exe' 'srchadmin.dll' })
(C 'UtilFontsBtn').Add_Click({ Start-AMRUtility 'Fonts' 'control.exe' 'fonts' })
(C 'UtilColorMgmtBtn').Add_Click({ Start-AMRUtility 'Color Management' 'colorcpl.exe' })

# Utilities search and category filtering (only affects Utilities tab)
$script:UtilityButtons = @((C 'UtilButtonsPanel').Children | Where-Object { $_ -is [System.Windows.Controls.Button] })
function Update-AMRUtilitiesView {
    $query = [string](C 'UtilSearchBox').Text
    $selected = (C 'UtilCategoryFilter').SelectedItem
    $category = if ($selected -and $selected.Content) { [string]$selected.Content } else { 'All Categories' }
    $visible = 0
    foreach ($button in $script:UtilityButtons) {
        $name = [string]$button.Content
        $tag = [string]$button.Tag
        if ([string]::IsNullOrWhiteSpace($tag)) {
            if ($name -match 'Device|Sound|Memory Diagnostic|TPM|Bluetooth|Display|Mouse|Keyboard|Printers|Color Management') { $tag = 'Hardware & Devices' }
            elseif ($name -match 'Firewall|Network|Credential|Certificate|Privacy|Proxy|Security|TPM') { $tag = 'Network & Security' }
            elseif ($name -match 'Task Manager|Services|Event Viewer|Performance|System|Control Panel|Registry|Programs|Features|Power|Windows Update|Storage|Indexing') { $tag = 'System & Performance' }
            else { $tag = 'Administration' }
        }
        $categoryMatch = ($category -eq 'All Categories' -or $tag -eq $category)
        $searchMatch = ([string]::IsNullOrWhiteSpace($query) -or $name.IndexOf($query,[System.StringComparison]::OrdinalIgnoreCase) -ge 0)
        $button.Visibility = if ($categoryMatch -and $searchMatch) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        if ($button.Visibility -eq [System.Windows.Visibility]::Visible) { $visible++ }
    }
    (C 'UtilResultsCount').Text = ('{0} utilities shown' -f $visible)
}
(C 'UtilSearchBox').Add_TextChanged({ Update-AMRUtilitiesView })
(C 'UtilCategoryFilter').Add_SelectionChanged({ Update-AMRUtilitiesView })
Update-AMRUtilitiesView

# --- 9. Launch Suite ---
Write-AMRLog 'Amr | windows_utility V0.1 initialized.' INFO System
Refresh-AMROverview
Write-AMRLog 'Utility Ready.' SUCCESS System
[void]$script:Window.ShowDialog()
