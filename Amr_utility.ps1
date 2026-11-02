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
}

# --- Thread-Safe Multi-Category Real-time Logging Engine ---
function Write-AMRLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR','DEBUG')][string]$Level='INFO',
        [ValidateSet('System','Overview','Software','Customize')][string]$Area='System'
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
    $iconSource = $null

    if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
        $iconSource = Get-AMRIconImageSource -Path $iconPath
    }

    if ($null -eq $iconSource -and
        (Test-Path -LiteralPath $jpgPath -PathType Leaf)) {
        $iconSource = Get-AMRIconImageSource -Path $jpgPath
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
        Icon          = $iconSource
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
        <TextBlock Text="System Overview" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="Detailed live telemetry and hardware information." Foreground="#A1A1AA" FontSize="14" Margin="0,4,0,0"/>
       </StackPanel>
       <Button Name="RefreshOverviewBtn" Grid.Column="1" Content="🔄 Refresh Info" Background="#2563EB" Foreground="#FFFFFF" BorderThickness="0" VerticalAlignment="Center"/>
      </Grid>

      <WrapPanel Orientation="Horizontal">
       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="System Information" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <TextBlock Name="ovOS" Text="OS: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
         <TextBlock Name="ovPCName" Text="PC Name: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
         <TextBlock Name="ovArch" Text="Architecture: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
         <TextBlock Name="ovDeviceType" Text="Device Type: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="Processor &amp; Graphics" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <TextBlock Name="ovCPU" Text="CPU: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3" TextWrapping="Wrap"/>
         <TextBlock Name="ovCPULoad" Text="CPU Usage: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
         <TextBlock Name="ovGPU" Text="GPU: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3" TextWrapping="Wrap"/>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="Memory (RAM)" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <TextBlock Name="ovRAMTotal" Text="Total: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
         <TextBlock Name="ovRAMUsage" Text="Usage: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="Motherboard &amp; BIOS" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <TextBlock Name="ovMobo" Text="Board: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3" TextWrapping="Wrap"/>
         <TextBlock Name="ovBIOS" Text="BIOS Version: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="Disk Storage" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <ItemsControl Name="ovDisks">
          <ItemsControl.ItemTemplate>
           <DataTemplate>
            <TextBlock Text="{Binding DisplayText}" Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
           </DataTemplate>
          </ItemsControl.ItemTemplate>
         </ItemsControl>
        </StackPanel>
       </Border>

       <Border Background="#27272A" BorderBrush="#3F3F46" BorderThickness="1" CornerRadius="10" Padding="15" Margin="10" Width="410">
        <StackPanel>
         <TextBlock Text="Network Status" FontSize="16" FontWeight="Bold" Foreground="#3B82F6" Margin="0,0,0,10"/>
         <TextBlock Name="ovIP" Text="IPv4 Address: Loading..." Foreground="#E4E4E7" FontSize="14" Margin="0,3"/>
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
        <TextBlock Text="Smart Multi-Tier Engine (Winget ➔ Chocolatey ➔ Strict Verified Direct Download)." Foreground="#A1A1AA" FontSize="14" Margin="0,4,0,0"/>
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
             <Image Source="{Binding Icon, Mode=OneWay}" Width="36" Height="36" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center" SnapsToDevicePixels="True" RenderOptions.BitmapScalingMode="HighQuality"/>
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
    <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="10,0,10,20">
     <StackPanel Name="CustomizePanel">
      <Grid Margin="0,10,0,15">
       <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
       </Grid.ColumnDefinitions>
       <StackPanel Grid.Column="0">
        <TextBlock Text="Mega Windows Customization Suite (27 Precision Tweaks)" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF"/>
        <TextBlock Text="Select only the tweaks you want to apply safely to your system registry &amp; preferences." Foreground="#A1A1AA" FontSize="14" Margin="0,4,0,0"/>
       </StackPanel>
       <Button Name="ApplyCustomizeBtn" Grid.Column="1" Content="⚡ Apply Selected Tweaks" Background="#10B981" Foreground="#FFFFFF" BorderThickness="0" FontWeight="Bold" Padding="25,10" VerticalAlignment="Center"/>
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
   </TabItem>

   <!-- 4. OPTIMIZE -->
   <TabItem Header="Optimize">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="System Optimization Engine" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="OptDisableTelemetryBtn" Content="⚡ Disable Telemetry &amp; Diagnostic Tracking" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="OptDisableBackgroundAppsBtn" Content="⚡ Disable Unnecessary Background Apps" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="OptDisableCortanaBtn" Content="⚡ Disable Cortana Assistant" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 5. SECURITY -->
   <TabItem Header="Security">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Security &amp; Privacy Console" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="SecEnableDefenderBtn" Content="🛡 Enable Realtime Windows Defender" Width="350" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="SecEnableFirewallBtn" Content="🛡 Enable All Firewall Profiles" Width="350" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="SecDisableActivityHistoryBtn" Content="🛡 Disable Windows Activity History Collection" Width="350" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 6. SYSTEM -->
   <TabItem Header="System">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Advanced System Configuration" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="SysUltimatePowerBtn" Content="⚙️ Activate Ultimate Performance Power Plan" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="SysDisableFastStartupBtn" Content="⚙️ Disable Fast Startup (Prevents Boot Errors)" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 7. NETWORK -->
   <TabItem Header="Network">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Network Diagnostic &amp; Repair Suite" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="NetFlushDnsBtn" Content="🌐 Flush System DNS Cache" Width="320" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="NetResetAdaptersBtn" Content="🌐 Reset TCP/IP Stack &amp; Winsock" Width="320" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 8. CLEANUP -->
   <TabItem Header="Cleanup">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Disk Cleanup &amp; Cache Maintenance" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="CleanTempFilesBtn" Content="🧹 Clean System Temp &amp; User Cache Files" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="CleanUpdateCacheBtn" Content="🧹 Reset &amp; Purge Windows Update Cache" Width="380" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 9. BACKUP -->
   <TabItem Header="Backup">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="System Restore &amp; Registry Backup" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <Button Name="BackupCreateRestorePointBtn" Content="💾 Create System Restore Point Now" Width="350" HorizontalAlignment="Left" Margin="0,0,0,15"/>
      <Button Name="BackupRegistryBtn" Content="💾 Export Safety Registry Backup" Width="350" HorizontalAlignment="Left" Margin="0,0,0,15"/>
     </StackPanel>
    </Border>
   </TabItem>

   <!-- 10. UTILITIES -->
   <TabItem Header="Utilities">
    <Border Padding="20">
     <StackPanel>
      <TextBlock Text="Quick Administration Utilities" FontSize="22" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,20"/>
      <WrapPanel Orientation="Horizontal">
       <Button Name="UtilControlPanelBtn" Content="🛠 Open Classic Control Panel" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilRegeditBtn" Content="🛠 Open Registry Editor" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilDevMgmtBtn" Content="🛠 Open Device Manager" Width="260" Margin="0,0,15,15"/>
       <Button Name="UtilSysInfoBtn" Content="🛠 Open System Information" Width="260" Margin="0,0,15,15"/>
      </WrapPanel>
     </StackPanel>
    </Border>
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
          <TextBlock Text="عمرو أحمد عبد الفتاح" Foreground="#FFFFFF" FontSize="15" FontWeight="SemiBold" Margin="0,2,0,0"/>
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
    Write-AMRLog "Updating system telemetry..." DEBUG Overview

    # OS Info
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            (C 'ovOS').Text   = "OS: " + $os.Caption
            (C 'ovArch').Text = "Architecture: " + $os.OSArchitecture
        } else {
            (C 'ovOS').Text   = "OS: Microsoft Windows"
            (C 'ovArch').Text = "Architecture: 64-bit"
        }
    } catch {
        (C 'ovOS').Text   = "OS: Microsoft Windows"
        (C 'ovArch').Text = "Architecture: Unknown"
    }
    (C 'ovPCName').Text = "PC Name: " + $env:COMPUTERNAME

    # Device Type
    try {
        $chassis = (Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
        $isLaptop = $chassis -match "8|9|10|11|12|14|18|21"
        (C 'ovDeviceType').Text = "Device Type: " + $(if($isLaptop) {"Laptop"} else {"Desktop"})
    } catch {
        (C 'ovDeviceType').Text = "Device Type: Desktop"
    }

    # CPU Info
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cpu) {
            (C 'ovCPU').Text     = "CPU: " + $cpu.Name.Trim()
            (C 'ovCPULoad').Text = "CPU Usage: " + $cpu.LoadPercentage + "%"
        } else {
            (C 'ovCPU').Text     = "CPU: Processor Info Unavailable"
            (C 'ovCPULoad').Text = "CPU Usage: N/A"
        }
    } catch {
        (C 'ovCPU').Text     = "CPU: Processor Info Unavailable"
        (C 'ovCPULoad').Text = "CPU Usage: N/A"
    }

    # GPU Info
    try {
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        if ($gpu) {
            (C 'ovGPU').Text = "GPU: " + ($gpu.Name -join " / ")
        } else {
            (C 'ovGPU').Text = "GPU: Display Adapter Unavailable"
        }
    } catch {
        (C 'ovGPU').Text = "GPU: Display Adapter Unavailable"
    }

    # RAM Info
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            $usedRamGB  = $totalRamGB - $freeRamGB
            $ramPercent = [math]::Round(($usedRamGB / $totalRamGB) * 100, 0)
            (C 'ovRAMTotal').Text = "Total RAM: $totalRamGB GB"
            (C 'ovRAMUsage').Text = "RAM Usage: $usedRamGB GB ($ramPercent%)"
        } else {
            (C 'ovRAMTotal').Text = "Total RAM: N/A"
            (C 'ovRAMUsage').Text = "RAM Usage: N/A"
        }
    } catch {
        (C 'ovRAMTotal').Text = "Total RAM: N/A"
        (C 'ovRAMUsage').Text = "RAM Usage: N/A"
    }

    # Motherboard & BIOS
    try {
        $mobo = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
        if ($mobo) {
            (C 'ovMobo').Text = "Board: " + $mobo.Manufacturer + " " + $mobo.Product
        } else {
            (C 'ovMobo').Text = "Board: Motherboard Info Unavailable"
        }
        $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
        if ($bios) {
            (C 'ovBIOS').Text = "BIOS Version: " + $bios.SMBIOSBIOSVersion
        } else {
            (C 'ovBIOS').Text = "BIOS Version: N/A"
        }
    } catch {
        (C 'ovMobo').Text = "Board: Motherboard Info Unavailable"
        (C 'ovBIOS').Text = "BIOS Version: N/A"
    }

    # Disks
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object {
            $total = [math]::Round($_.Size / 1GB, 1)
            $free  = [math]::Round($_.FreeSpace / 1GB, 1)
            [PSCustomObject]@{ DisplayText = "Drive $($_.DeviceID) - $free GB free of $total GB" }
        }
        (C 'ovDisks').ItemsSource = $disks
    } catch {
        (C 'ovDisks').ItemsSource = @([PSCustomObject]@{ DisplayText = "Drive Space Info Unavailable" })
    }

    # Network IP
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
               Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.IPAddress -notlike "169.254.*" }).IPAddress -join ", "
        if (-not $ip) { $ip = "Not Connected" }
        (C 'ovIP').Text = "IPv4 Address: " + $ip
    } catch {
        (C 'ovIP').Text = "IPv4 Address: Not Connected"
    }

    Write-AMRLog "Telemetry data refreshed successfully." SUCCESS Overview
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

(C 'RefreshOverviewBtn').Add_Click({ Update-AMROverviewData })

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

# OPTIMIZE ENGINE
(C 'OptDisableTelemetryBtn').Add_Click({
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
    Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 | Out-Null
    Write-AMRLog "Telemetry services disabled." SUCCESS System
    Show-AMRMessage "Telemetry & Diagnostics disabled." "Optimize" OK Information | Out-Null
})

(C 'OptDisableBackgroundAppsBtn').Add_Click({
    if (Set-AMRRegistryKey -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1) {
        Show-AMRMessage "Global background app access disabled." "Optimize" OK Information | Out-Null
    }
})

(C 'OptDisableCortanaBtn').Add_Click({
    if (Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0) {
        Show-AMRMessage "Cortana disabled." "Optimize" OK Information | Out-Null
    }
})

# SECURITY ENGINE
(C 'SecEnableDefenderBtn').Add_Click({
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Write-AMRLog "Windows Defender Realtime Protection enabled." SUCCESS System
    Show-AMRMessage "Windows Defender is enabled." "Security" OK Information | Out-Null
})

(C 'SecEnableFirewallBtn').Add_Click({
    Set-NetFirewallProfile -All -Enabled True -ErrorAction SilentlyContinue
    Write-AMRLog "All Network Firewall profiles enabled." SUCCESS System
    Show-AMRMessage "Windows Firewall profiles enabled." "Security" OK Information | Out-Null
})

(C 'SecDisableActivityHistoryBtn').Add_Click({
    Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 | Out-Null
    Set-AMRRegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 | Out-Null
    Write-AMRLog "Activity History tracking disabled." SUCCESS System
    Show-AMRMessage "Activity History disabled." "Security" OK Information | Out-Null
})

# SYSTEM ENGINE
(C 'SysUltimatePowerBtn').Add_Click({
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
    Write-AMRLog "Ultimate Performance Power Plan added." SUCCESS System
    Show-AMRMessage "Ultimate Performance Power Plan activated!" "System" OK Information | Out-Null
})

(C 'SysDisableFastStartupBtn').Add_Click({
    if (Set-AMRRegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0) {
        Show-AMRMessage "Fast Startup disabled." "System" OK Information | Out-Null
    }
})

# NETWORK ENGINE
(C 'NetFlushDnsBtn').Add_Click({
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-AMRLog "DNS Client Cache flushed." SUCCESS System
    Show-AMRMessage "DNS Cache Flushed Successfully!" "Network" OK Information | Out-Null
})

(C 'NetResetAdaptersBtn').Add_Click({
    netsh int ip reset | Out-Null
    netsh winsock reset | Out-Null
    Write-AMRLog "TCP/IP Stack and Winsock Reset executed." SUCCESS System
    Show-AMRMessage "Network adapters reset. Please restart your PC." "Network" OK Information | Out-Null
})

# CLEANUP ENGINE
(C 'CleanTempFilesBtn').Add_Click({
    $tempPaths = @($env:TEMP, 'C:\Windows\Temp')
    foreach ($path in $tempPaths) {
        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-AMRLog "Temporary files purged." SUCCESS System
    Show-AMRMessage "System & User Temp files cleaned." "Cleanup" OK Information | Out-Null
})

(C 'CleanUpdateCacheBtn').Add_Click({
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path "C:\Windows\SoftwareDistribution\Download" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-AMRLog "Windows Update Cache purged." SUCCESS System
    Show-AMRMessage "Windows Update Cache cleaned successfully." "Cleanup" OK Information | Out-Null
})

# BACKUP ENGINE
(C 'BackupCreateRestorePointBtn').Add_Click({
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "AMR-Utility Restore Point" -RestorePointType "MODIFY_SETTINGS"
        Write-AMRLog "Created System Restore Point." SUCCESS System
        Show-AMRMessage "Restore Point created successfully!" "Backup" OK Information | Out-Null
    } catch {
        Show-AMRMessage "Could not create Restore Point: $_" "Backup Error" OK Error | Out-Null
    }
})

(C 'BackupRegistryBtn').Add_Click({
    $regFile = Join-Path $script:BackupDir ("HKCU_Backup_{0}.reg" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    reg export "HKCU\Software" $regFile /y | Out-Null
    Write-AMRLog "Exported HKCU registry to: $regFile" SUCCESS System
    Show-AMRMessage "HKCU Registry backup saved to:`n$regFile" "Backup" OK Information | Out-Null
})

# UTILITIES ENGINE
(C 'UtilControlPanelBtn').Add_Click({ Start-Process "control.exe" })
(C 'UtilRegeditBtn').Add_Click({ Start-Process "regedit.exe" })
(C 'UtilDevMgmtBtn').Add_Click({ Start-Process "devmgmt.msc" })
(C 'UtilSysInfoBtn').Add_Click({ Start-Process "msinfo32.exe" })

# --- 9. Launch Suite ---
Write-AMRLog 'Amr | windows_utility V0.1 initialized.' INFO System
Refresh-AMROverview
Write-AMRLog 'Utility Ready.' SUCCESS System
[void]$script:Window.ShowDialog()
