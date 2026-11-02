AMR Windows Utility
A Windows utility built with PowerShell and WPF to help users browse, search, and manage supported software installation tasks through a graphical interface.
Features

Graphical User Interface: A WPF-based interface for easier navigation.
Software Search: Search the available software list.
Software Icons: Displays available application icons in the interface.
Automatic Icon Setup: Downloads and caches the icon pack when needed.
Local Icon Cache: Stores icons under %ProgramData%\AMR-Utility\Icons to avoid downloading them again when they are already available.
Launcher Scripts: Includes convenient scripts for starting the application.

Repository Contents



File or Folder
Description




Amr_utility.ps1
Main PowerShell application and WPF interface.


icons.zip
Compressed application icon pack used by the automatic icon setup.


Icons/
Repository copy of the application icons, useful for reference or manual access.


Launch-AMR.ps1
Launches the main application in an elevated PowerShell process.


Run-AMR-Utility.cmd
Convenient Windows launcher for starting the utility.


README.md
Project documentation and instructions.


LICENSE
Project license.



Requirements

Windows
Windows PowerShell
Administrator permission when required by the application's operations
Internet access for downloading the icon pack when it is not already cached

How to Run

Download or clone this repository.
Keep the launcher files and Amr_utility.ps1 together in the same folder.
Double-click Run-AMR-Utility.cmd.
Approve the Windows UAC prompt if it appears.
The application will launch.

Alternatively, run Launch-AMR.ps1 from PowerShell.
Icon Setup
The application checks the local icon cache at:
%ProgramData%\AMR-Utility\Icons
If the required icons are missing, the application attempts to download the configured icon archive, extract the images, and cache them locally.
Once the icons have been cached, the application can reuse them on subsequent launches without downloading the archive again, provided the required icons remain available.
An internet connection is needed for the initial download when the required icons are not already cached.
Troubleshooting
The application does not start

Make sure Windows PowerShell is available.
Confirm that Amr_utility.ps1 is in the same folder as Launch-AMR.ps1.
Try launching the utility using Run-AMR-Utility.cmd.
Check whether Windows or your security software is blocking PowerShell scripts.

Icons are missing

Check your internet connection if the icon pack has not been downloaded before.
Confirm that the application can access %ProgramData%\AMR-Utility\Icons.
Restart the application after resolving any download or file-access issues.

Administrator permission is requested
The launcher starts the application with elevated permissions. Approve the UAC prompt only if you trust the source of the script.
Notes

Keep the launcher files and main script together.
Do not rename Amr_utility.ps1 unless you also update the launcher.
The icon archive URL is configured in the main script. If the archive location changes, update that setting accordingly.
Software installation behavior depends on the implementation and configuration of the main script.

License
See the LICENSE file for license details.
