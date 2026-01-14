# Reboot Reminder PowerShell Script

## Description

**RebootReminder.ps1** is an enhanced PowerShell script designed to encourage regular system reboots to maintain security and performance on Windows-based workstations. Fully compatible with **Windows 10/11** and **Microsoft Intune**, it uses modern toast notifications to remind users to reboot their system and enforces reboots after a defined grace period.

## Key Features

- ✅ **Windows 11 Compatible** - Modern toast notifications with Windows.UI.Notifications
- ✅ **Intune Proactive Remediations Support** - Detection and remediation scripts ready
- ✅ **BurntToast Module Support** - Enhanced notifications when available
- ✅ **User and SYSTEM Context** - Works in both contexts seamlessly
- ✅ **Weekend and Work Hours Awareness** - Respects off-hours and weekends
- ✅ **Compliance Reporting** - JSON-based compliance tracking and reporting
- ✅ **Grace Period Management** - Configurable grace period before forced reboots
- ✅ **Scheduled Task Integration** - Built-in functions for task scheduling
- ✅ **Enhanced Logging** - Comprehensive logging with size management
- ✅ **User Tracking** - Tracks dismissals and reminder history
- ✅ **Fallback Notifications** - Native notifications when BurntToast unavailable

## Requirements

- **Operating System**: Windows 10 (1809+) or Windows 11
- **PowerShell**: PowerShell 5.1 or PowerShell 7+
- **Optional**: BurntToast module from PowerShell Gallery (install with `Install-Module -Name BurntToast`)
- **Permissions**: Administrator rights for system-wide deployment

## Usage

### Basic Usage

```powershell
.\RebootReminder.ps1 -DaysLimit 7
```

Runs with default settings: 7-day uptime limit, 5-hour grace period.

### Custom Parameters

```powershell
.\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 8 -LogPath "C:\Logs\RebootLog.log" -WorkStart 9 -WorkEnd 18
```

Customize all parameters: 14-day limit, 8-hour grace period, custom log path, and specific work hours.

### Intune Detection Script

```powershell
.\RebootReminder.ps1 -DaysLimit 7 -CheckOnly
```

**Exit Codes:**
- `0` = System is compliant (uptime within limit)
- `1` = System is non-compliant (uptime exceeds limit)

Use this in Intune Proactive Remediations **Detection Script** field.

### Intune Remediation Script

```powershell
.\RebootReminder.ps1 -DaysLimit 7 -IntuneMode
```

Runs in Intune-compatible mode with user notifications. Use this in Intune Proactive Remediations **Remediation Script** field.

### Force Reboot

```powershell
.\RebootReminder.ps1 -DaysLimit 7 -ForceReboot
```

Forces immediate reboot after displaying final warning.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DaysLimit` | Int | 7 | Maximum days before requiring reboot (1-365) |
| `HoursLimit` | Int | 5 | Grace period in hours after reminder before forced reboot (0-48) |
| `LogPath` | String | $env:USERPROFILE\RebootLog.log or $env:TEMP\RebootLog.log | Custom log file path |
| `WorkStart` | Int | 8 | Work hour start (0-23, 24-hour format) |
| `WorkEnd` | Int | 17 | Work hour end (0-23, 24-hour format) |
| `IntuneMode` | Switch | $false | Run in Intune-compatible mode (no long-running processes) |
| `CheckOnly` | Switch | $false | Return exit code based on compliance only (for detection scripts) |
| `ForceReboot` | Switch | $false | Force reboot after grace period |
| `DismissTimeHours` | Int | 24 | Hours user can dismiss reminders (0-168) |
| `ComplianceReportPath` | String | $env:ProgramData\RebootCompliance.json | Path for compliance report JSON file |

## Deployment Methods

### Method 1: Windows Task Scheduler

#### SYSTEM Context (Recommended for Scheduled Execution)

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

# Create the scheduled task
Register-RebootReminderTask -ScriptPath $ScriptPath -TaskName "RebootReminder" -Schedule "Daily"
```

Or manually with PowerShell:

```powershell
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\Scripts\RebootReminder.ps1`" -IntuneMode"
$Trigger = New-ScheduledTaskTrigger -Daily -At 9am
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -TaskName "RebootReminder" -Description "Reboot Reminder Script" -Force
```

#### User Context (For Interactive Notifications)

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

Register-UserContextTask -ScriptPath $ScriptPath -TaskName "RebootReminderUser"
```

### Method 2: Microsoft Intune

#### Option A: Proactive Remediations (Recommended)

**Detection Script:**
```powershell
# Save as RebootReminder-Detection.ps1
& "C:\Scripts\RebootReminder.ps1" -DaysLimit 7 -CheckOnly
```

**Remediation Script:**
```powershell
# Save as RebootReminder-Remediation.ps1
& "C:\Scripts\RebootReminder.ps1" -DaysLimit 7 -IntuneMode
```

**Steps in Intune:**
1. Navigate to **Devices** > **Remediations**
2. Click **Create Script Package**
3. Fill in details:
   - **Name**: Reboot Reminder
   - **Description**: Enforce regular system reboots
   - **Detection Script**: Upload `RebootReminder-Detection.ps1`
   - **Remediation Script**: Upload `RebootReminder-Remediation.ps1`
   - **Run as**: **Logged-in user** (for notifications) or **System** (for enforcement)
   - **Frequency**: Hourly or Daily
4. Assign to device groups

#### Option B: PowerShell Script

1. Navigate to **Devices** > **Scripts**
2. Click **Add** > **PowerShell script**
3. Configure:
   - **Name**: Reboot Reminder
   - **Script Location**: Upload the script
   - **Parameters**: `-DaysLimit 7 -IntuneMode`
   - **Run script as logged-in user**: Yes
   - **Run this script using 64-bit**: Yes
4. Assign to device groups

#### Option C: Win32 App

1. Create an IntuneWin file containing the script
2. Deploy as Win32 app with:
   - **Install Command**: `powershell.exe -ExecutionPolicy Bypass -File RebootReminder.ps1 -DaysLimit 7 -IntuneMode`
   - **Detection Rule**: Custom detection script checking for log file or registry key

### Method 3: SCCM

Create a Package or Application in SCCM with the script as a program:
- **Command Line**: `powershell.exe -ExecutionPolicy Bypass -File RebootReminder.ps1 -DaysLimit 7`
- **Program Runs As**: Only when a user is logged on
- **Run Mode**: Run with administrative rights
- **Schedule**: Recurring schedule (daily or hourly)

## Notification Behavior

### Normal Reminder
- Displayed when uptime exceeds `DaysLimit`
- Shows current uptime and grace period remaining
- Three buttons: **Restart Now**, **Snooze 1 Hour**, **Dismiss**

### Final Warning
- Displayed when grace period is almost expired (1 hour or less remaining)
- Clear warning that reboot will be enforced
- Same action buttons available

### Forced Reboot
- 10-minute countdown with recurring notifications
- System forces restart after countdown
- User cannot dismiss final notifications

## Compliance Tracking

The script maintains compliance data in two locations:

1. **Per-User Tracking** (`HKCU:\SOFTWARE\RebootReminder`):
   - LastReminder: Timestamp of last notification
   - DismissCount: Number of times user dismissed
   - FirstReminder: First notification timestamp

2. **System-wide Report** (`$env:ProgramData\RebootCompliance.json`):
   - Historical compliance data
   - Useful for reporting and analysis

### View Compliance Report

```powershell
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json
$report | Format-Table -AutoSize
```

### Compliance Statistics

```powershell
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json
$report | Group-Object Compliant | Select-Object Name, Count
```

## Troubleshooting

### Script Not Showing Notifications

**Problem**: Toast notifications not appearing

**Solutions**:
1. Check if notifications are enabled in Windows Settings:
   ```
   Settings > System > Notifications & actions > Get notifications from apps and other senders
   ```
2. Ensure BurntToast is installed (optional but recommended):
   ```powershell
   Install-Module -Name BurntToast -Scope CurrentUser
   ```
3. Check script logs for errors:
   ```powershell
   Get-Content "$env:USERPROFILE\RebootLog.log" -Tail 50
   ```

### Intune Script Not Running

**Problem**: Script not executing in Intune

**Solutions**:
1. Verify script execution policy allows the script
2. Ensure the script is saved with UTF-8 encoding (BOM or no BOM)
3. Check Intune logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`
4. Test manually on a device: `powershell.exe -ExecutionPolicy Bypass -File RebootReminder.ps1 -IntuneMode`

### Registry Errors

**Problem**: Script fails to write to registry

**Solutions**:
1. Ensure running with appropriate permissions
2. Check if antivirus is blocking registry modifications
3. Verify registry path exists or can be created

### Forced Reboot Not Working

**Problem**: System not rebooting after grace period

**Solutions**:
1. Check if `shutdown.exe` is blocked by policy
2. Verify user has permissions to restart the computer
3. Check event logs for restart failures:
   ```
   Event Viewer > Windows Logs > System
   ```

## Advanced Functions

The script includes several functions for advanced management:

### Register Scheduled Task

```powershell
Register-RebootReminderTask -ScriptPath "C:\Scripts\RebootReminder.ps1" -TaskName "RebootReminder" -Schedule "Daily"
```

### Unregister Scheduled Task

```powershell
Unregister-RebootReminderTask -TaskName "RebootReminder"
```

### Register User Context Task

```powershell
Register-UserContextTask -ScriptPath "C:\Scripts\RebootReminder.ps1" -TaskName "RebootReminderUser"
```

### Get Compliance Status

```powershell
$status = Get-IntuneComplianceStatus
$status | Format-List
```

### View Reboot History

```powershell
$history = Get-RebootHistory -StartDate (Get-Date).AddDays(-30)
$history | Format-Table -AutoSize
```

## Security Considerations

- **No Arbitrary Code Execution**: All user inputs are validated
- **Registry Protection**: Uses HKCU (user context) or proper SYSTEM registry paths
- **Log Security**: Logs contain timestamps but no sensitive data
- **Privilege Management**: Works in both user and system contexts appropriately
- **No External Dependencies**: Optional BurntToast module for enhanced features

## Version History

- **6.0** - Complete rewrite for Windows 11 and Intune compatibility
  - Added Intune Proactive Remediations support
  - Added BurntToast module integration
  - Added user tracking and dismissal counting
  - Added compliance reporting (JSON)
  - Added scheduled task management functions
  - Improved error handling and logging
  - Windows 11 native notifications support

- **5.0** - Previous version with basic functionality

## Contributing

We welcome contributions! If you've identified bugs, have enhancements, or want to suggest improvements:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear documentation
4. Test thoroughly on Windows 10 and Windows 11
5. Submit a pull request

## License

This script is provided as-is for use in enterprise environments. Modify as needed for your organization's requirements.

## Author

**Concept by Cláudio Gonçalves**

## Support

For issues, questions, or feature requests, please open an issue in the repository.
