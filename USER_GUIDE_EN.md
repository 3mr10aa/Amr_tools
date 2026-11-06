AMR Utility — User Guide

User Documentation — Amr_tools Repository

1. About AMR Utility

AMR Utility is a Windows helper application that brings together several tools in one interface, including system information, software management, Windows customization, cleanup, optimization, backup and export, system and network diagnostics, and shortcuts to built-in Windows utilities.

«Important: Some actions change Windows settings or delete files. Read each option and its confirmation message before proceeding. Do not apply a setting unless you understand its effect.»

2. System Requirements

- Windows 10 or Windows 11.
- Windows PowerShell 5.1.
- An internet connection when launching the application to download its application script, and when using features that require online access or download software.
- A Windows account that can approve an Administrator permission prompt when required.

A User Account Control (UAC) prompt may appear because some Windows management operations require elevated permissions. Approve it only if you initiated the launch and trust the source.

3. Launching the Application

1. Open Windows PowerShell.
2. Copy and paste the following command exactly, then press Enter:

irm https://tinyurl.com/Amr-t00l | iex

3. Wait while the launcher downloads the application script and checks its PowerShell syntax.
4. If a UAC prompt appears, review it and approve it only if you intended to launch AMR Utility.
5. Wait for the application window to appear. Do not close PowerShell while the launch command is still running.

Security note: This command downloads and executes a PowerShell script from the project repository. Run it only if you trust the source. You can review the project files here:

https://github.com/3mr10aa/Amr_tools

4. Application Sections

Overview

Displays information about the computer and Windows, including processor, memory, graphics, disks, network, and selected security and system status details.

Use Refresh to update the displayed information.

Software

Allows you to search for applications and manage installation, updates, and repairs.

- Search: Find an application by name or identifier.
- Show Installed: Display applications detected as installed.
- Smart Install: Install selected applications using the available automated method.
- Interactive Install: Start an interactive installation when manual steps may be required.
- Update: Attempt to update selected applications.
- Repair: Attempt to repair applications for which a repair method is available.
- Clear Selection: Clear the current selection.

Monitor the progress bar and status messages. Available actions may vary by application and by the package manager installed on the computer.

Customize

Contains options for changing Windows settings, including appearance, taskbar, File Explorer, privacy, and selected system behaviors.

1. Read each option carefully.
2. Select only the settings you want.
3. Review the selection count.
4. Use Apply Tweaks for the left panel selections, or Apply Selected Tweaks for the Basic Tweaks panel selections.
5. Use the cancel buttons to clear selections before applying them.

The Basic Tweaks panel includes presets such as:

- Essential
- Minimal
- Medium
- Advanced

Presets select groups of options for review. Inspect the selected options before applying them.

Some changes may require signing out or restarting Windows.

Restore Defaults can restore only original values that the application successfully captured through its restore mechanism. It is not a universal undo button for every action.

Cleanup

1. Select Scan Now to scan the available cleanup categories.
2. Review the scan results, categories, and estimated file sizes.
3. Select only the categories you intend to clean.
4. Select Clean Selected, then read the confirmation dialog before approving.

«Warning: Cleanup may permanently remove selected files. Do not proceed unless you understand the selected categories. Do not skip the scan. Use drive and Windows component analysis tools carefully.»

Optimize

Provides maintenance and optimization tools grouped by category. Find the required tool and read its name and description before running it.

Not every option is appropriate for every computer.

Security

Groups tools related to protection status, firewall, privacy, and Windows security settings.

Use this section for checks or to open related Windows tools. Do not disable protection or change a security setting unless you understand the consequences.

System

Provides system, diagnostic, maintenance, recovery, and reporting tools. Some entries open native Windows utilities and may require Administrator permissions.

Network

Contains network diagnostics and management tools for DNS, IP, connections, and reset operations.

Before resetting network settings, make sure you know which connection settings may need to be entered again.

Backup

Provides export actions for selected system information and settings, such as application lists, services, drivers, network details, and selected security configuration. It also includes an option to create a System Restore Point.

- Choose the required action.
- Wait for the completion message.
- Keep the resulting files in a safe location.

An export does not necessarily mean every item can be restored automatically. Keep separate backups of important personal files. A System Restore Point is not a substitute for backing up personal files.

Utilities

Provides shortcuts to common Windows tools, including:

- Task Manager
- Device Manager
- Registry Editor
- Services
- Event Viewer
- Disk Management
- Control Panel

5. Data and Log Location

The application uses the following data directory:

C:\ProgramData\AMR-Utility

It may contain folders such as:

Folder| Purpose
"Backups"| Backup and export files
"Logs"| Application logs
"Exports"| Exported data
"Icons"| Interface icons
"Downloads"| Files downloaded by application features

Contents may vary depending on the features you use. Do not delete these files if you still need their logs or backups.

6. Troubleshooting

The Application Window Does Not Open

- Check your internet connection.
- Make sure you are using Windows PowerShell 5.1.
- Try again later if GitHub is temporarily unavailable.
- If it exists, check the launcher log at:

%TEMP%\Amr_Utility_Launcher.log

A Permissions Prompt Appears

Some operations require Administrator permissions. Approve UAC only if you initiated the launch and trust the source.

An Application Is Missing or Installation Fails

- Check the spelling of the application name.
- Check your internet connection.
- Make sure the required package manager or installation source is available.
- Not every application supports the same installation, update, or repair operations.

A Cleanup or Settings Operation Fails

- Read the error message and application log.
- Do not repeatedly retry without understanding the failure.
- Leave sensitive settings unchanged until the cause is understood.

Finding the Launcher Log

1. Press "Win + R".
2. Enter "%TEMP%" and press Enter.
3. Look for "Amr_Utility_Launcher.log".

7. Safe-Use Recommendations

- Review the script source before running it, especially when using a command that downloads and executes code directly.
- Do not run the utility on a work-managed computer without the administrator's permission.
- Back up important files before making system changes.
- Read confirmation dialogs; do not approve them automatically.
- Do not manually delete Windows files based on guesswork.
- Avoid applying multiple advanced changes at once if you do not understand their effects.
- Restart Windows when the application asks you to or when a change requires it.

8. Project

- Project repository: https://github.com/3mr10aa/Amr_tools
- Launch command:

irm https://tinyurl.com/Amr-t00l | iex

Developer: Amr Ahmed

---

This guide describes general use of the current version. Option names and details may change as the project is updated.