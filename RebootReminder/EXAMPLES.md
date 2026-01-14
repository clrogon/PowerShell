# RebootReminder - Examples and Use Cases

This document provides practical examples and real-world use cases for the RebootReminder script.

## Table of Contents

- [Basic Examples](#basic-examples)
- [Intune Deployment Examples](#intune-deployment-examples)
- [Scheduled Task Examples](#scheduled-task-examples)
- [Real-World Use Cases](#real-world-use-cases)
- [Advanced Scenarios](#advanced-scenarios)
- [Troubleshooting Examples](#troubleshooting-examples)

---

## Basic Examples

### Example 1: Basic Daily Reminder

Show a reminder after 7 days of uptime, with 5-hour grace period:

```powershell
.\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 5
```

**Use Case**: Standard desktop management

### Example 2: Extended Grace Period

More lenient settings for laptop users:

```powershell
.\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 8 -WorkStart 9 -WorkEnd 18
```

**Use Case**: Laptop users who may be working remotely or offline

### Example 3: Strict Security Enforcement

Aggressive settings for security-sensitive environments:

```powershell
.\RebootReminder.ps1 -DaysLimit 5 -HoursLimit 3 -WorkStart 7 -WorkEnd 20
```

**Use Case**: High-security workstations requiring frequent reboots

### Example 4: Compliance Check Only

Check compliance without showing notifications:

```powershell
.\RebootReminder.ps1 -DaysLimit 7 -CheckOnly
```

**Use Case**: Periodic compliance auditing

---

## Intune Deployment Examples

### Example 1: Standard Intune Proactive Remediations

**Detection Script** (`RebootReminder-Detection.ps1`):
```powershell
param([int]$DaysLimit = 7)

$OS = Get-CimInstance -ClassName Win32_OperatingSystem
$Uptime = (Get-Date) - $OS.LastBootUpTime

if ($Uptime.Days -ge $DaysLimit) {
    exit 1  # Non-compliant
} else {
    exit 0  # Compliant
}
```

**Remediation Script** (`RebootReminder-Remediation.ps1`):
```powershell
param([int]$DaysLimit = 7, [int]$HoursLimit = 5)

# Include notification logic from full script
# (See RebootReminder-Remediation.ps1)
```

**Intune Configuration**:
- **Detection**: Run as System
- **Remediation**: Run as Logged-in user
- **Frequency**: Hourly

### Example 2: Intune PowerShell Script

**Script**:
```powershell
& "C:\Scripts\RebootReminder.ps1" -DaysLimit 7 -HoursLimit 5 -IntuneMode
```

**Intune Configuration**:
- **Run as**: Logged-in user
- **Run schedule**: Daily at 9 AM
- **Parameters**: `-DaysLimit 7 -HoursLimit 5 -IntuneMode`

### Example 3: Intune Win32 App

**Install Command**:
```cmd
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File RebootReminder.ps1 -DaysLimit 7 -IntuneMode
```

**Detection Script**:
```powershell
$trackingPath = "HKCU:\SOFTWARE\RebootReminder"
Test-Path $trackingPath
```

---

## Scheduled Task Examples

### Example 1: Daily Check at 9 AM

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -IntuneMode"

$Trigger = New-ScheduledTaskTrigger -Daily -At 9am

$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal `
    -TaskName "RebootReminder" -Description "Daily reboot reminder" -Force
```

### Example 2: Hourly Check During Work Hours

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -IntuneMode"

# Trigger every hour from 8 AM to 5 PM
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date "8:00 AM") `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration (New-TimeSpan -Hours 9)

$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal `
    -TaskName "RebootReminder-Hourly" -Description "Hourly reboot reminder" -Force
```

### Example 3: Weekly Check on Mondays

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -IntuneMode"

$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 9am

$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal `
    -TaskName "RebootReminder-Weekly" -Description "Weekly reboot reminder" -Force
```

### Example 4: User Context Task (On Logon)

```powershell
$ScriptPath = "C:\Scripts\RebootReminder.ps1"

$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -IntuneMode"

$Trigger = New-ScheduledTaskTrigger -AtLogon

$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Highest

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal `
    -TaskName "RebootReminder-User" -Description "Reboot reminder on logon" -Force
```

---

## Real-World Use Cases

### Use Case 1: Finance Department Desktops

**Scenario**: Finance department requires strict security with regular reboots after Patch Tuesday.

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 5 -HoursLimit 4 -WorkStart 8 -WorkEnd 17
```

**Deployment**: Intune Proactive Remediations with hourly checks

**Scheduling**: Scheduled task runs 4 days after Patch Tuesday
```powershell
# Calculate Patch Tuesday (second Tuesday of month)
$patchTuesday = Get-PatchTuesdayDate
$scheduleDate = $patchTuesday.AddDays(4)

$Trigger = New-ScheduledTaskTrigger -Once -At $scheduleDate
```

### Use Case 2: Remote Sales Team Laptops

**Scenario**: Sales team members work remotely with unpredictable schedules. They may be offline for extended periods.

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 21 -HoursLimit 12 -LogPath "$env:USERPROFILE\SalesReboot.log"
```

**Deployment**: Intune PowerShell script with user context

**Scheduling**: Run on logon
```powershell
$Trigger = New-ScheduledTaskTrigger -AtLogon
```

**Additional**: Compliance report review monthly
```powershell
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json
$salesTeam = $report | Where-Object { $_.UserName -like "*sales*" }
$salesTeam | Select-Object ComputerName, UptimeDays, Compliant | Format-Table
```

### Use Case 3: Development Workstations

**Scenario**: Developers need longer uptime for builds and tests but still require compliance.

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 24 -WorkStart 9 -WorkEnd 20
```

**Deployment**: Windows Task Scheduler with weekly checks

**Scheduling**: Sunday evening at 8 PM
```powershell
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 8pm
```

**Special Handling**: Allow developers to request exemption
```powershell
# Exemption registry key
$exemptionPath = "HKCU:\SOFTWARE\RebootReminder\Exemption"
if (Test-Path $exemptionPath) {
    $exemption = Get-ItemProperty $exemptionPath
    if ($exemption.ExemptUntil -gt (Get-Date)) {
        Write-Log "User has exemption until $($exemption.ExemptUntil)"
        return
    }
}
```

### Use Case 4: Manufacturing Floor Computers

**Scenario**: Kiosk-style computers on manufacturing floor that run 24/7. Reboots should happen during maintenance windows.

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 2 -WorkStart 20 -WorkEnd 4
```

**Deployment**: Windows Task Scheduler

**Scheduling**: Every night at 2 AM
```powershell
$Trigger = New-ScheduledTaskTrigger -Daily -At 2am
```

### Use Case 5: Healthcare Workstations

**Scenario**: Healthcare workstations in patient care areas require maximum availability but must be patched for security.

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 10 -HoursLimit 6 -WorkStart 6 -WorkEnd 22
```

**Deployment**: Intune Proactive Remediations

**Additional**: Force reboot only on Sundays
```powershell
if ((Get-Date).DayOfWeek -ne [DayOfWeek]::Sunday) {
    Write-Log "Forced reboot only on Sundays. Skipping."
    return
}

Invoke-GracefulReboot -WarningMinutes 15
```

---

## Advanced Scenarios

### Scenario 1: Conditional Deployment Based on Device Type

Deploy different settings based on device type:

```powershell
# Check device type
$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

if ($computerSystem.PCSystemType -eq 2) { # Laptop
    # Laptop configuration
    .\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 8
} elseif ($computerSystem.PCSystemType -eq 1) { # Desktop
    # Desktop configuration
    .\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 5
} else {
    # Default configuration
    .\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 5
}
```

### Scenario 2: Department-Specific Policies

Different departments have different requirements:

```powershell
# Get department from AD
$computer = Get-ADComputer -Identity $env:COMPUTERNAME -Properties Department
$department = $computer.Department

switch ($department) {
    "Finance" {
        .\RebootReminder.ps1 -DaysLimit 5 -HoursLimit 4
    }
    "Development" {
        .\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 24
    }
    "Sales" {
        .\RebootReminder.ps1 -DaysLimit 21 -HoursLimit 12
    }
    Default {
        .\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 5
    }
}
```

### Scenario 3: Help Desk Integration

Create help desk tickets when users dismiss too many times:

```powershell
$tracking = Get-RebootTrackingData

if ($tracking.DismissCount -ge 3) {
    $ticketData = @{
        Subject = "Reboot Reminder Dismissed Multiple Times - $env:COMPUTERNAME"
        Description = "User $env:USERNAME has dismissed reboot reminder $($tracking.DismissCount) times. System uptime exceeds threshold."
        Priority = "Medium"
        AssignedTo = "IT Support"
    }

    # Call help desk API
    Invoke-RestMethod -Uri "https://helpdesk/api/tickets" -Method Post -Body ($ticketData | ConvertTo-Json)
}
```

### Scenario 4: Email Reporting

Send daily compliance report via email:

```powershell
# Get compliance data
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json
$nonCompliant = $report | Where-Object { -not $_.Compliant }

if ($nonCompliant.Count -gt 0) {
    $body = @"
    Non-Compliant Devices Report - $(Get-Date -Format "yyyy-MM-dd")

    Total Non-Compliant: $($nonCompliant.Count)

    $(-join ($nonCompliant | Select-Object ComputerName, UptimeDays, LastReboot | ConvertTo-Html))

    Please investigate and address these devices.
    "@

    Send-MailMessage -To "it-support@company.com" `
        -From "reboot-reminder@company.com" `
        -Subject "Non-Compliant Devices Report" `
        -Body $body `
        -SmtpServer "smtp.company.com"
}
```

### Scenario 5: Database Logging

Log compliance data to SQL database:

```powershell
function Log-ToDatabase {
    param(
        [PSCustomObject]$ComplianceData
    )

    $connectionString = "Server=sqlserver.company.com;Database=RebootCompliance;Integrated Security=True"

    $query = @"
    INSERT INTO ComplianceLog (ComputerName, UserName, UptimeDays, Compliant, Timestamp)
    VALUES ('$($ComplianceData.ComputerName)', '$($ComplianceData.UserName)', $($ComplianceData.UptimeDays), '$($ComplianceData.Compliant)', '$($ComplianceData.Timestamp)')
    "@

    Invoke-Sqlcmd -ConnectionString $connectionString -Query $query
}

$compliance = Get-IntuneComplianceStatus
Log-ToDatabase -ComplianceData $compliance
```

---

## Troubleshooting Examples

### Example 1: Debugging Notification Issues

Check why notifications aren't appearing:

```powershell
# Check if BurntToast is installed
Get-Module -ListAvailable -Name BurntToast

# Check Windows notification settings
Get-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -ErrorAction SilentlyContinue

# Test notification manually
Show-Windows11Toast -Title "Test" -Message "This is a test notification"

# Check script logs
Get-Content "$env:USERPROFILE\RebootLog.log" -Tail 50
```

### Example 2: Verifying Scheduled Task Execution

Check if scheduled task ran successfully:

```powershell
# Get task history
Get-ScheduledTaskInfo -TaskName "RebootReminder"

# Get task events
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -FilterXPath "*[System[(EventID=102)]] and *[Data[@Name='TaskName']='RebootReminder']]" -MaxEvents 10

# Check last run result
Get-ScheduledTask -TaskName "RebootReminder" | Select-Object State, LastRunTime, LastTaskResult
```

### Example 3: Intune Remediation Debugging

Debug Intune remediation script:

```powershell
# Add verbose logging
$VerbosePreference = "Continue"
Write-Verbose "Starting remediation script"

# Enable transcript logging
Start-Transcript -Path "$env:TEMP\RebootRemediation-Debug.log"

# Script content here...

Stop-Transcript
```

### Example 4: Checking Compliance Status

Check compliance status across devices:

```powershell
# Load compliance report
$report = Get-Content "C:\ProgramData\RebootCompliance.json" | ConvertFrom-Json

# Summary statistics
$summary = $report | Group-Object Compliant
Write-Host "Compliant: $($summary.Where({$_.Name -eq 'True'}).Count)"
Write-Host "Non-Compliant: $($summary.Where({$_.Name -eq 'False'}).Count)"

# Find devices needing attention
$attentionNeeded = $report | Where-Object { -not $_.Compliant -and $_.UptimeDays -gt 14 }
$attentionNeeded | Format-Table ComputerName, UptimeDays, LastReboot -AutoSize

# Check specific device
$deviceStatus = $report | Where-Object { $_.ComputerName -eq $env:COMPUTERNAME }
$deviceStatus
```

---

## Complete Deployment Script

Here's a complete script that sets up RebootReminder with optimal settings:

```powershell
<#
.SYNOPSIS
    Complete RebootReminder Deployment Script
.DESCRIPTION
    Deploys RebootReminder script with scheduled tasks and monitoring
#>

# Configuration
$DaysLimit = 7
$HoursLimit = 5
$WorkStart = 8
$WorkEnd = 17
$ScriptPath = "$env:ProgramFiles\RebootReminder\RebootReminder.ps1"

# Step 1: Create directory
if (-not (Test-Path (Split-Path $ScriptPath -Parent))) {
    New-Item -Path (Split-Path $ScriptPath -Parent) -ItemType Directory -Force
}

# Step 2: Copy script
Copy-Item -Path ".\RebootReminder.ps1" -Destination $ScriptPath -Force

# Step 3: Register scheduled task
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -IntuneMode -DaysLimit $DaysLimit -HoursLimit $HoursLimit -WorkStart $WorkStart -WorkEnd $WorkEnd"

$Trigger = New-ScheduledTaskTrigger -Daily -At 9am

$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
    -LogonType ServiceAccount -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal `
    -Settings $Settings -TaskName "RebootReminder" -Description "Daily reboot reminder" -Force

# Step 4: Verify deployment
$task = Get-ScheduledTask -TaskName "RebootReminder"
if ($task.State -eq "Ready") {
    Write-Host "Deployment successful!"
    Write-Host "Scheduled task created: $($task.TaskName)"
    Write-Host "Script location: $ScriptPath"
    Write-Host "Next run: $($task.Triggers.StartBoundary)"
} else {
    Write-Error "Deployment failed. Task state: $($task.State)"
}
```

---

**For more information**, see:
- [README.md](README.md) - Complete documentation
- [QUICKSTART.md](QUICKSTART.md) - Quick deployment guide
- [INTUNE_DEPLOYMENT.md](INTUNE_DEPLOYMENT.md) - Intune deployment guide
- [WHATSNEW.md](WHATSNEW.md) - What's new in v6.0
