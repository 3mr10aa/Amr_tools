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

# --- 1. Admin Privilege Check ---
function Test-AMRAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-AMRAdmin)) {
    # طلب صلاحيات المسؤول وإعادة تشغيل السكربت
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

# --- 3. EXPANDED MASSIVE SOFTWARE CATALOG (200+ VERIFIED APPLICATIONS) ---
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
    [pscustomobject]@{ Name='AnyDesk'; Category='05. System Utilities'; Id='AnyDeskSoftwareGmbH.AnyDesk'; ChocoId='anydesk'; DirectUrl=''; DirectArgs=''; Publisher='AnyDesk Software GmbH' },
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
    [pscustomobject]@{ Name='Insomnia API Client'; Category='06. Development'; Id='Kong.Insomnia'; ChocoId='insomnia-rest-client'; DirectUrl=''; DirectArgs=''; Publisher='Kong Inc.' },

    # 07. Communication & Social (15 Apps)
    [pscustomobject]@{ Name='Discord'; Category='07. Communication'; Id='Discord.Discord'; ChocoId='discord'; DirectUrl=''; DirectArgs=''; Publisher='Discord Inc.' },
    [pscustomobject]@{ Name='Telegram Desktop'; Category='07. Communication'; Id='Telegram.TelegramDesktop'; ChocoId='telegram'; DirectUrl=''; DirectArgs=''; Publisher='Telegram FZ-LLC' },
    [pscustomobject]@{ Name='WhatsApp'; Category='07. Communication'; Id='WhatsApp.WhatsApp'; ChocoId='whatsapp'; DirectUrl=''; DirectArgs=''; Publisher='Meta Platforms' },
    [pscustomobject]@{ Name='Zoom'; Category='07. Communication'; Id='Zoom.Zoom'; ChocoId='zoom'; DirectUrl=''; DirectArgs=''; Publisher='Zoom Video Communications' },
    [pscustomobject]@{ Name='Signal'; Category='07. Communication'; Id='Signal.Signal'; ChocoId='signal'; DirectUrl=''; DirectArgs=''; Publisher='Signal Foundation' },
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
    [pscustomobject]@{ Name='Razer Synapse'; Category='08. Gaming'; Id='Razer.Synapse.3'; ChocoId='razer-synapse'; DirectUrl=''; DirectArgs=''; Publisher='Razer Inc.' },

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
    [pscustomobject]@{ Name='Paint.NET'; Category='10. Design & Graphics'; Id='dotPDN.PaintNET'; ChocoId='paint.net'; DirectUrl=''; DirectArgs=''; Publisher='dotPDN LLC' },
    [pscustomobject]@{ Name='Darktable'; Category='10. Design & Graphics'; Id='darktable.darktable'; ChocoId='darktable'; DirectUrl=''; DirectArgs=''; Publisher='darktable team' },
    [pscustomobject]@{ Name='RawTherapee'; Category='10. Design & Graphics'; Id='RawTherapee.RawTherapee'; ChocoId='rawtherapee'; DirectUrl=''; DirectArgs=''; Publisher='RawTherapee Team' },
    [pscustomobject]@{ Name='ShareX'; Category='10. Design & Graphics'; Id='ShareX.ShareX'; ChocoId='sharex'; DirectUrl=''; DirectArgs=''; Publisher='ShareX Team' },
    [pscustomobject]@{ Name='Flameshot'; Category='10. Design & Graphics'; Id='FlameShot.FlameShot'; ChocoId='flameshot'; DirectUrl=''; DirectArgs=''; Publisher='Flameshot Team' },
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
    [pscustomobject]@{ Name='ProtonVPN'; Category='11. Security & Privacy'; Id='Proton Technologies.ProtonVPN'; ChocoId='protonvpn'; DirectUrl=''; DirectArgs=''; Publisher='Proton AG' },
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
    [pscustomobject]@{ Name='pCloud Drive'; Category='12. Cloud & Storage'; Id='pCloud.pCloudDrive'; ChocoId='pcloud'; DirectUrl=''; DirectArgs=''; Publisher='pCloud AG' },
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
    [pscustomobject]@{ Name='PCSX2 PlayStation 2 Emulator'; Category='14. Virtualization'; Id='PCSX2.PCSX2'; ChocoId='pcsx2'; DirectUrl=''; DirectArgs=''; Publisher='PCSX2 Team' },
    [pscustomobject]@{ Name='RPCS3 PS3 Emulator'; Category='14. Virtualization'; Id='RPCS3.RPCS3'; ChocoId='rpcs3'; DirectUrl=''; DirectArgs=''; Publisher='RPCS3 Team' },
    [pscustomobject]@{ Name='Dolphin Emulator'; Category='14. Virtualization'; Id='DolphinEmulator.Dolphin'; ChocoId='dolphin'; DirectUrl=''; DirectArgs=''; Publisher='Dolphin Team' },
    [pscustomobject]@{ Name='PPSSPP PSP Emulator'; Category='14. Virtualization'; Id='PPSSPP.PPSSPP'; ChocoId='ppsspp'; DirectUrl=''; DirectArgs=''; Publisher='Henrik Rydgard' },
    [pscustomobject]@{ Name='RetroArch'; Category='14. Virtualization'; Id='Libretro.RetroArch'; ChocoId='retroarch'; DirectUrl=''; DirectArgs=''; Publisher='Libretro' },
    [pscustomobject]@{ Name='DOSBox'; Category='14. Virtualization'; Id='DOSBox.DOSBox'; ChocoId='dosbox'; DirectUrl=''; DirectArgs=''; Publisher='DOSBox Team' },

    # 15. Network & Database Tools (15 Apps)
    [pscustomobject]@{ Name='DBeaver Community'; Category='15. Network & Database'; Id='dbeaver.dbeaver'; ChocoId='dbeaver'; DirectUrl=''; DirectArgs=''; Publisher='DBeaver Corp' },
    [pscustomobject]@{ Name='MongoDB Compass'; Category='15. Network & Database'; Id='MongoDB.Compass.Full'; ChocoId='mongodb-compass'; DirectUrl=''; DirectArgs=''; Publisher='MongoDB Inc.' },
    [pscustomobject]@{ Name='pgAdmin 4'; Category='15. Network & Database'; Id='PostgreSQL.pgAdmin4'; ChocoId='pgadmin4'; DirectUrl=''; DirectArgs=''; Publisher='pgAdmin Team' },
    [pscustomobject]@{ Name='MySQL Workbench'; Category='15. Network & Database'; Id='Oracle.MySQLWorkbench'; ChocoId='mysql.workbench'; DirectUrl=''; DirectArgs=''; Publisher='Oracle Corporation' },
    [pscustomobject]@{ Name='HeidiSQL'; Category='15. Network & Database'; Id='AnsgarBecker.HeidiSQL'; ChocoId='heidisql'; DirectUrl=''; DirectArgs=''; Publisher='Ansgar Becker' },
    [pscustomobject]@{ Name='DB Browser for SQLite'; Category='15. Network & Database'; Id='DBBrowserForSQLite.DBBrowserForSQLite'; ChocoId='sqlitebrowser'; DirectUrl=''; DirectArgs=''; Publisher='DB Browser Team' },
    [pscustomobject]@{ Name='PuTTY'; Category='15. Network & Database'; Id='PuTTY.PuTTY'; ChocoId='putty'; DirectUrl=''; DirectArgs=''; Publisher='Simon Tatham' },
    [pscustomobject]@{ Name='WinSCP'; Category='15. Network & Database'; Id='WinSCP.WinSCP'; ChocoId='winscp'; DirectUrl=''; DirectArgs=''; Publisher='Martin Prikryl' },
    [pscustomobject]@{ Name='FileZilla Client'; Category='15. Network & Database'; Id='TimKosse.FileZilla.Client'; ChocoId='filezilla'; DirectUrl=''; DirectArgs=''; Publisher='Tim Kosse' },
    [pscustomobject]@{ Name='Nmap'; Category='15. Network & Database'; Id='Insecure.Nmap'; ChocoId='nmap'; DirectUrl=''; DirectArgs=''; Publisher='Insecure.Org' },
    [pscustomobject]@{ Name='Angry IP Scanner'; Category='15. Network & Database'; Id='AngryIPScanner.AngryIPScanner'; ChocoId='angryip'; DirectUrl=''; DirectArgs=''; Publisher='Anton Keks' },
    [pscustomobject]@{ Name='Termius'; Category='15. Network & Database'; Id='Termius.Termius'; ChocoId='termius'; DirectUrl=''; DirectArgs=''; Publisher='Termius Corporation' },
    [pscustomobject]@{ Name='MTPuTTY'; Category='15. Network & Database'; Id='TTYPlus.MTPuTTY'; ChocoId='mtputty'; DirectUrl=''; DirectArgs=''; Publisher='TTYPlus' },
    [pscustomobject]@{ Name='Redis Insight'; Category='15. Network & Database'; Id='Redis.RedisInsight'; ChocoId='redis-insight'; DirectUrl=''; DirectArgs=''; Publisher='Redis Ltd.' },
    [pscustomobject]@{ Name='Advanced IP Scanner'; Category='15. Network & Database'; Id='Famatech.AdvancedIPScanner'; ChocoId='advanced-ip-scanner'; DirectUrl=''; DirectArgs=''; Publisher='Famatech' },

    # 16. Torrent & Download Managers (10 Apps)
    [pscustomobject]@{ Name='Free Download Manager'; Category='16. Downloads & Torrent'; Id='SoftDeluxe.FreeDownloadManager'; ChocoId='freedownloadmanager'; DirectUrl=''; DirectArgs=''; Publisher='SoftDeluxe' },
    [pscustomobject]@{ Name='Internet Download Manager'; Category='16. Downloads & Torrent'; Id='TonicSolutions.InternetDownloadManager'; ChocoId='internet-download-manager'; DirectUrl=''; DirectArgs=''; Publisher='Tonic Solutions' },
    [pscustomobject]@{ Name='qBittorrent'; Category='16. Downloads & Torrent'; Id='qBittorrent.qBittorrent'; ChocoId='qbittorrent'; DirectUrl=''; DirectArgs=''; Publisher='The qBittorrent Project' },
    [pscustomobject]@{ Name='Transmission'; Category='16. Downloads & Torrent'; Id='Transmission.Transmission'; ChocoId='transmission'; DirectUrl=''; DirectArgs=''; Publisher='Transmission Project' },
    [pscustomobject]@{ Name='Deluge Torrent'; Category='16. Downloads & Torrent'; Id='Deluge.Deluge'; ChocoId='deluge'; DirectUrl=''; DirectArgs=''; Publisher='Deluge Team' },
    [pscustomobject]@{ Name='Motrix Download Manager'; Category='16. Downloads & Torrent'; Id='agalwood.Motrix'; ChocoId='motrix'; DirectUrl=''; DirectArgs=''; Publisher='Megalwood' },
    [pscustomobject]@{ Name='PicoTorrent'; Category='16. Downloads & Torrent'; Id='PicoTorrent.PicoTorrent'; ChocoId='picotorrent'; DirectUrl=''; DirectArgs=''; Publisher='PicoTorrent' },
    [pscustomobject]@{ Name='Aria2 Download Utility'; Category='16. Downloads & Torrent'; Id='aria2.aria2'; ChocoId='aria2'; DirectUrl=''; DirectArgs=''; Publisher='Tatsuhiro Tsujikawa' },
    [pscustomobject]@{ Name='yt-dlp Video Downloader'; Category='16. Downloads & Torrent'; Id='yt-dlp.yt-dlp'; ChocoId='yt-dlp'; DirectUrl=''; DirectArgs=''; Publisher='yt-dlp Project' },
    [pscustomobject]@{ Name='JDownloader 2'; Category='16. Downloads & Torrent'; Id='AppWork.JDownloader'; ChocoId='jdownloader'; DirectUrl=''; DirectArgs=''; Publisher='AppWork GmbH' }
)

$script:SoftwareCatalog = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'

$RawApps | ForEach-Object {
    $initial  = if ($_.Name.Length -gt 0) { $_.Name.Substring(0,1).ToUpper() } else { 'A' }
    $iconPath = Join-Path $script:IconDir "$($_.Id).png"
    $jpgPath  = Join-Path $script:IconDir "$($_.Id).jpg"
    $iconUrl  = $null
    if (Test-Path $iconPath) { $iconUrl = $iconPath }
    elseif (Test-Path $jpgPath) { $iconUrl = $jpgPath }

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
        Icon          = $iconUrl
    })
}

# --- 4. FULL WPF XAML INTERFACE WITH PROGRESS BAR & 27 CUSTOMIZE TOOLS ---
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
        Title="Amr | windows_utility" Height="880" Width="1420" 
        MinHeight="780" MinWidth="1220" WindowStartupLocation="CenterScreen" 
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
             <TextBlock Text="{Binding Initials}" Foreground="#A1A1AA" FontSize="20" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
             <Image Source="{Binding Icon}" Width="36" Height="36" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
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
      <Button Name="BackupRegistryBtn" Content="💾 Export Safety Registry Backup" Width="350"
