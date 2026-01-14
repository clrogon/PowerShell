# Intune Deployment Guide - Reboot Reminder

This guide provides step-by-step instructions for deploying the Reboot Reminder script via Microsoft Intune.

## Prerequisites

- **Intune Administrator** or higher permissions
- **Test Group**: Create a test device group before deploying to production
- **Windows 10/11 Devices**: Target devices must be managed by Intune

## Deployment Options

### Option 1: Proactive Remediations (Recommended)

Best for ongoing compliance monitoring and automatic remediation.

#### Step 1: Prepare Scripts

Create two script files:

**RebootReminder-Detection.ps1**
```powershell
# Copy from RebootReminder-Detection.ps1
# Modify $DaysLimit if needed (default: 7)
```

**RebootReminder-Remediation.ps1**
```powershell
# Copy from RebootReminder-Remediation.ps1
# Modify $DaysLimit and $HoursLimit if needed
```

#### Step 2: Create Detection Script Package

1. Navigate to **Microsoft Endpoint Manager Admin Center**
2. Go to **Devices** > **Remediations**
3. Click **Create Script Package**
4. Fill in the **Basics** tab:
   - **Name**: `Reboot Reminder Detection`
   - **Description**: `Checks if system uptime exceeds 7 days`
   - **Publisher**: `Your Organization`
   - **Version**: `1.0.0`
5. Click **Next**

#### Step 3: Configure Detection Script

In the **Settings** tab:

**Detection Script File**: Upload `RebootReminder-Detection.ps1`

**Script Details**:
- **Run this script using 64-bit**: `Yes`
- **Run this script as**: Choose based on your needs:
  - `System` (Recommended): More reliable for checking uptime
  - `Logged-in user`: Required if you want user-specific checks

Click **Next**

#### Step 4: Skip Remediation (For Detection Only)

Click **Next** to skip remediation for now.

#### Step 5: Assign and Review

**Assignments**:
- Click **Add group** under **Include**
- Select your **Test Group** first
- Click **Next**

**Review + Create**:
- Review all settings
- Click **Create**

#### Step 6: Create Remediation Script Package

Repeat steps 2-5 for the remediation script:

**Remediation Script File**: Upload `RebootReminder-Remediation.ps1`

**Script Details**:
- **Run this script using 64-bit**: `Yes`
- **Run this script as**: **Logged-in user** (Required for toast notifications)

**Schedule Settings**:
- **Frequency**: `Hourly` or `Daily` (Hourly recommended)
- **Occurrences per frequency**: `1`

**Assignments**: Assign to test group first

#### Step 7: Monitor and Test

1. After deployment, check device status in the remediation report
2. Monitor logs on test devices:
   ```
   Get-Content "$env:TEMP\RebootReminder-Intune.log" -Tail 50
   ```
3. Verify toast notifications appear on test devices
4. Confirm that reboot enforcement works as expected

#### Step 8: Deploy to Production

Once testing is successful:

1. Edit both remediation packages
2. Add production groups to **Include**
3. Optionally remove test groups from **Include**
4. Save and monitor deployment

---

### Option 2: PowerShell Script

Simple deployment method for one-time or scheduled execution.

#### Step 1: Prepare Script

**RebootReminder-Intune.ps1**
```powershell
# Copy from RebootReminder.ps1
# Modify parameters as needed
# Ensure -IntuneMode is included in your parameters
```

#### Step 2: Create Script in Intune

1. Navigate to **Devices** > **Scripts**
2. Click **Add** > **PowerShell script**
3. Fill in the **Basics**:
   - **Name**: `Reboot Reminder`
   - **Description**: `Enforce regular system reboots for security and performance`
4. Click **Next**

#### Step 3: Configure Script Settings

**Script Location**: Upload `RebootReminder.ps1`

**Script Parameters**:
```
-DaysLimit 7 -HoursLimit 5 -IntuneMode
```

**Run this script as**: `Logged-on user` (for notifications)

**Execution options**:
- **Run this script using 64-bit**: `Yes`
- **Run script in elevated context**: `Yes`

Click **Next**

#### Step 4: Assign

1. **Assignments**: Click **Add group** > **Include** > select your groups
2. **Run schedule**: Configure as needed:
   - `Once` (for immediate execution)
   - `Daily` (for recurring execution)
   - `Hourly` (for frequent checks)
3. Click **Next**

#### Step 5: Review and Create

Review settings and click **Create**

---

### Option 3: Win32 App Deployment

Best for package management and reporting.

#### Step 1: Create IntuneWin File

Use **Win32 Content Prep Tool** to package the script:

```cmd
IntuneWinAppUtil.exe -c "C:\Scripts\RebootReminder" -s "RebootReminder.ps1" -o "C:\IntunePackages" -q
```

#### Step 2: Create Win32 App

1. Navigate to **Apps** > **All apps**
2. Click **Add** > **Windows app (Win32)**
3. Fill in **App information**:
   - **Name**: `Reboot Reminder`
   - **Publisher**: `Your Organization`
   - **Version**: `1.0.0`
   - **Category**: `System Management`
   - **Description**: `Enforces regular system reboots`

#### Step 3: Configure Program Commands

**Install Command**:
```cmd
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File RebootReminder.ps1 -DaysLimit 7 -IntuneMode
```

**Uninstall Command**:
```cmd
powershell.exe -Command "Remove-ScheduledTask -TaskName 'RebootReminder*' -ErrorAction SilentlyContinue"
```

**Install behavior**: `System` (for enforcement) or `User` (for notifications)

**Device restart behavior**: `No specific action`

**Max runtime (minutes)**: `60`

#### Step 4: Configure Requirements

**Operating system architecture**: `64-bit`
**Minimum operating system**: `Windows 10 1809` or `Windows 10 2004` (for best experience)
**Disk space required**: `1 MB`

#### Step 5: Configure Detection Rules

**Rule type**: `Use a custom detection script`

**Script file**: Upload `RebootReminder-Detection.ps1`

**Run script as 32-bit process**: `No`

#### Step 6: Assign and Deploy

Follow standard Win32 app assignment process.

---

## Configuration Parameters

### Recommended Parameters for Different Scenarios

#### Conservative (Laptops)
```powershell
-DaysLimit 14 -HoursLimit 8
```

#### Standard (Desktops)
```powershell
-DaysLimit 7 -HoursLimit 5
```

#### Aggressive (Security-Focused)
```powershell
-DaysLimit 5 -HoursLimit 4
```

#### After Patch Tuesday
```powershell
-DaysLimit 3 -HoursLimit 2 -ForceReboot
```

## Monitoring and Reporting

### View Remediation Status

1. Go to **Devices** > **Remediations**
2. Select the remediation package
3. Click **Device status** to see:
   - Total devices
   - Compliant devices
   - Non-compliant devices
   - Error devices

### View Logs on Devices

```powershell
# Main script log
Get-Content "$env:USERPROFILE\RebootLog.log" -Tail 50

# Intune remediation log
Get-Content "$env:TEMP\RebootReminder-Intune.log" -Tail 50

# Intune Management Extension log
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Tail 100
```

### View Compliance Report

```powershell
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json
$report | Select-Object ComputerName, Compliant, UptimeDays, Timestamp | Format-Table -AutoSize

# Compliance percentage
$compliant = ($report | Where-Object Compliant).Count
$total = $report.Count
Write-Host "Compliance: $([math]::Round($compliant/$total*100, 1))%"
```

## Troubleshooting

### Remediation Not Running

**Symptoms**: Devices remain non-compliant despite script deployment

**Solutions**:
1. Verify Intune Management Extension is running:
   ```powershell
   Get-Process -Name IntuneManagementExtension -ErrorAction SilentlyContinue
   ```
2. Check device is enrolled in Intune
3. Verify script is assigned to device group
4. Check for script errors in Intune portal

### Notifications Not Appearing

**Symptoms**: Script runs but users don't see notifications

**Solutions**:
1. Ensure script runs as **logged-in user** for notifications
2. Check Windows notification settings:
   ```
   Settings > System > Notifications & actions
   ```
3. Verify notifications are enabled for PowerShell:
   ```powershell
   Get-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.PowerShell"
   ```

### Forced Reboot Not Working

**Symptoms**: Grace period expires but system doesn't reboot

**Solutions**:
1. Check if shutdown.exe is blocked by policy
2. Verify user has reboot permissions
3. Check event logs for shutdown failures:
   ```powershell
   Get-WinEvent -LogName System -FilterXPath "*[System[(EventID=1074)]]" -MaxEvents 10
   ```

### Script Execution Failures

**Symptoms**: Script fails to execute

**Solutions**:
1. Check script encoding (UTF-8 BOM recommended)
2. Verify PowerShell execution policy:
   ```powershell
   Get-ExecutionPolicy -List
   ```
3. Test manually on device:
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File RebootReminder.ps1 -IntuneMode
   ```

## Best Practices

1. **Deploy Gradually**: Always test on a small group first
2. **Monitor Closely**: Check logs and compliance reports during initial rollout
3. **Communicate**: Inform users about reboot requirements and process
4. **Schedule Smartly**: Avoid deploying immediately before Patch Tuesday
5. **Adjust Parameters**: Customize based on your organization's needs
6. **Document**: Keep records of configuration changes and their impact
7. **Regular Review**: Periodically review compliance and adjust as needed

## Security Considerations

1. **Principle of Least Privilege**: Run as logged-in user for notifications, system for enforcement
2. **Audit Logs**: Regularly review compliance and audit logs
3. **Script Security**: Sign scripts before production deployment
4. **Testing**: Thoroughly test in non-production environments

## Advanced Customization

### Custom Notification Messages

Modify the script to include organization-specific messages:

```powershell
$message = "Attention $env:USERNAME - Your ACME Corp system requires reboot for security compliance."
```

### Integration with Other Tools

Integrate with help desk ticketing system:

```powershell
# After multiple dismissals, create ticket
if ($dismissCount -ge 3) {
    Invoke-RestMethod -Uri "https://helpdesk/api/ticket" -Method Post -Body $ticketData
}
```

### Conditional Deployment

Deploy only to specific device types:

```powershell
# Check for laptop vs desktop
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
if ($computerSystem.PCSystemType -eq 2) { # Laptop
    # Use longer grace period
    $DaysLimit = 14
} else { # Desktop
    # Use standard grace period
    $DaysLimit = 7
}
```

## Additional Resources

- [Intune Documentation](https://docs.microsoft.com/mem/intune/)
- [Intune Proactive Remediations](https://docs.microsoft.com/mem/intune/fundamentals/remediations)
- [Windows Toast Notifications](https://docs.microsoft.com/windows/uwp/design/shell/tiles-and-notifications/adaptive-interactive-toasts)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs on affected devices
3. Consult the main README.md
4. Open an issue in the repository

---

**Last Updated**: 2025
**Version**: 1.0
