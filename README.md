# AMR Windows Utility

A Windows maintenance and utility toolkit built with Windows PowerShell 5.1 and WPF.

> **Important:** This application requests Administrator privileges and includes actions that can change Windows settings, Registry values, services, networking configuration, temporary files, and Windows Update cache. Review the available actions and understand their effects before running them. Back up important data and create a restore point where appropriate. Use at your own risk.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (included with supported Windows versions)
- Administrator account / approval for the UAC prompt
- WPF desktop environment
- Internet connection for online software installation features

## Run from the ZIP package

1. Extract the entire ZIP file to a normal folder (do not run it from inside the ZIP preview).
2. Double-click **`Run-AMR-Utility.cmd`**.
3. Approve the Windows User Account Control (UAC) prompt.
4. The launcher starts `Amr_utility.ps1` in Windows PowerShell with STA mode, which is required by the WPF interface.

## Run from Windows Terminal / PowerShell

Open PowerShell in the extracted project folder and run:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Launch-AMR.ps1
```

The launcher requests elevation and starts the application in STA mode.

To run the main script directly from an already elevated PowerShell window:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File .\Amr_utility.ps1
```

## Files

| File | Purpose |
|---|---|
| `Amr_utility.ps1` | Original main application and WPF interface, included unchanged |
| `Launch-AMR.ps1` | Requests elevation and starts the application in STA mode |
| `Run-AMR-Utility.cmd` | Convenient double-click launcher |
| `README.md` | Documentation and usage instructions |
| `LICENSE` | Copyright and usage terms |
| `.gitignore` | Common local/generated files excluded from Git |

## Important source-integrity note

The supplied `Amr_utility.ps1` is included byte-for-byte as provided by its author. This package preparation does not edit, sanitize, refactor, or otherwise change the main script. Any future source-code changes are the author's decision.

Before publishing this repository publicly, be aware that all content inside the main script—including any contact details embedded in it—will be visible to anyone who can access the repository. Review that yourself if you want to change it; this package intentionally leaves the original untouched.

## Data and logs

The application creates its working folders under:

```text
%ProgramData%\AMR-Utility\
```

This includes folders for backups, logs, exports, icons, and downloads.

## Version

Source banner: `V0.1`.
