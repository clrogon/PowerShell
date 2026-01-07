<#
.Synopsis
   This PowerShell script enhances system maintenance protocols by utilizing modern toast notifications for prompting users regarding necessary system reboots. It provides an interactive and user-friendly reminder for system reboots based on specified intervals, ensuring timely updates and maintenance.
.Description
   The script introduces an advanced notification system to encourage users to reboot their computers if the system has not been restarted within a specified number of days. It integrates toast notifications that allow direct interaction, including options for immediate action or dismissal, making the reminder process more engaging and effective. The script is designed to operate seamlessly across weekdays, with customizations for reminder intervals, work hours, and logging, ensuring minimal disruption to the user's workflow while maintaining system health.
.Example
   .\RebootReminder.ps1 -DaysLimit 7
   This command initiates the script with toast notifications reminding the user to reboot after 7 days of uptime, improving upon traditional methods with a more interactive approach.
.Example
   .\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 4 -LogPath "C:\logs\RebootLog.log" -WorkStart 9 -WorkEnd 18
   Specifies a 7-day reboot reminder limit, a 4-hour grace period for action, custom log path, and active reminder hours, leveraging toast notifications for a comprehensive maintenance strategy.
.Inputs
   Parameters include DaysLimit, HoursLimit, LogPath, WorkStart, WorkEnd, with additional options for customizing the toast notification appearance and behavior, offering flexibility in maintenance planning.
.Outputs
   Direct user interaction through toast notifications, with logging of user actions and script operations for audit and review purposes.
.Notes
   Optimized for deployment via task scheduling tools for regular execution, this script adapts to modern desktop environments by providing clear, actionable reminders directly within the user interface, facilitating proactive system maintenance.
   Version: 5.0
   Author: Concept by Cláudio Gonçalves
   Last Updated: 09/04/2024
#>

# Define global parameters for script operation
param (
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,365)]
    [int]$DaysLimit = 7,
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,24)]
    [int]$HoursLimit = 5,
    [Parameter(Mandatory=$false)]
    [string]$LogPath = $(if (Test-Path "$env:USERPROFILE\RebootLog.log") { "$env:USERPROFILE\RebootLog.log" } else { "$env:TEMP\RebootLog.log" }),
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,23)]
    [int]$WorkStart = 8,
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,23)]
    [int]$WorkEnd = 17,
    [int]$ReminderIntervalSeconds = 1800,
    [int]$ReminderIntervalMinutes = 30
)

# Check if the Log file exist
if (-not (Test-Path $LogPath)) {
    try {
        New-Item -Path $LogPath -ItemType File -Force | Out-Null
        Write-Host "Log file created successfully."
    } catch {
        Write-Error "Failed to create log file: $_"
        Exit
    }
}

# Before logging, check the size of the log file and archive if necessary
$LogFileSizeLimit = 10MB
$LogFile = Get-Item $LogPath
if ($LogFile.Length -gt $LogFileSizeLimit) {
    try {
        $ArchivePath = "$LogPath.old"
        Move-Item $LogPath $ArchivePath -Force
        Write-Host "Log file archived successfully."
    } catch {
        Write-Error "Failed to archive log file: $_"
        Exit
    }
}

# This function sets up the action to be taken when a specific button in the toast notification is clicked.
function Set-Action {
    param(
        [string]$ActionName,
        [string]$ScriptContent
    )

    # Validate ActionName to prevent registry injection and path traversal
    if ([string]::IsNullOrWhiteSpace($ActionName)) {
        Write-Error "ActionName cannot be null or empty."
        return
    }

    # Only allow alphanumeric characters, no special characters to prevent injection
    if ($ActionName -notmatch '^[a-zA-Z0-9]+$') {
        Write-Error "Invalid ActionName. Only alphanumeric characters are allowed."
        return
    }

    # Validate ScriptContent to prevent command injection
    # Block dangerous commands and special characters that could be exploited
    $dangerousPatterns = @(
        '&', '|', ';', '`', '$(', '`', '&&', '||', '>', '>>', '<',
        'Remove-Item', 'del ', 'rm ', 'format ', 'shutdown ',
        'Invoke-Expression', 'iex ', 'Start-Process.*\.exe'
    )

    foreach ($pattern in $dangerousPatterns) {
        if ($ScriptContent -match [regex]::Escape($pattern)) {
            Write-Error "ScriptContent contains potentially dangerous commands or characters."
            return
        }
    }

    # Limit script content length to prevent overflow attacks
    if ($ScriptContent.Length -gt 1000) {
        Write-Error "ScriptContent is too long. Maximum 1000 characters allowed."
        return
    }

    Try {
        # Use the environment variable for the temporary directory
        $ScriptPath = Join-Path $env:TEMP "$ActionName.cmd"
        $LogScriptContent = @"
echo %DATE% %TIME% - $ActionName button clicked >> "$LogPath"
$ScriptContent
"@

        $MainRegPath = "HKCU:\SOFTWARE\Classes\$ActionName"
        $CommandPath = "$MainRegPath\shell\open\command"

        # Create and write the restart script with logging
        New-Item -Path $ScriptPath -Force | Out-Null
        Set-Content -Path $ScriptPath -Value $LogScriptContent -Force

        # Create registry entries for the custom protocol
        New-Item -Path $CommandPath -Force | Out-Null
        New-ItemProperty -Path $MainRegPath -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
        Set-ItemProperty -Path $MainRegPath -Name "(Default)" -Value "URL:$ActionName Protocol" -Force | Out-Null
        Set-ItemProperty -Path $CommandPath -Name "(Default)" -Value "`"$ScriptPath`"" -Force | Out-Null
    }
    Catch {
        # Error handling remains largely the same
        $ErrorMessage = $_.Exception.Message
        $ErrorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $ErrorCode = $_.Exception.HResult
        $ErrorStackTrace = $_.Exception.StackTrace
        $LogMessage = "$ErrorTime - Error encountered: $ErrorMessage (Code: $ErrorCode). StackTrace: $ErrorStackTrace"
        Add-Content -Path $LogPath -Value $LogMessage
    }
}

# Set up the "RestartNow" action
$RestartScriptContent = "Shutdown /g /t 0 /f"
Set-Action -ActionName "RestartNow" -ScriptContent $RestartScriptContent

# Set up the "DismissOrSnooze" action
$DismissOrSnoozeScriptContent = "echo Dismiss or Snooze button clicked"
Set-Action -ActionName "DismissOrSnooze" -ScriptContent $DismissOrSnoozeScriptContent

# Function to show a toast notification with "Restart now" and "Dismiss or Snooze" buttons
function Show-ToastNotification {
    param (
        [string]$Headline,
        [string]$Body,
        [string]$LogoPath,
        [string]$ImagePath
    )

    try {
        $xml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Headline</text>
            <text>$Body</text>
            <image placement="appLogoOverride" src="$LogoPath"/>
            <image placement="hero" src="$ImagePath"/>
        </binding>
    </visual>
    <actions>
        <action
            content="Restart now"
            activationType="protocol"
            arguments="RestartNow:" />
        <action
            content="Dismiss or Snooze"
            activationType="protocol"
            arguments="DismissOrSnooze:" />
    </actions>
</toast>
"@

        $XmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
        $XmlDocument.LoadXml($xml)

        $AppId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($XmlDocument)
    }
    catch {
        Write-Error "An error occurred while displaying the toast notification: $_"
    }
    
}

# Function to convert a file to a Base64 string
function ConvertTo-Base64String {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (Test-Path $FilePath) {
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($FilePath))
    } else {
        Write-Error "File not found: $FilePath"
    }
}

# Function to save a Base64 string to a file
function Save-Base64StringToFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Base64String,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    try {
        [IO.File]::WriteAllBytes($OutputPath, [Convert]::FromBase64String($Base64String))
        Write-Output "Image saved successfully to $OutputPath."
    } catch {
        Write-Error "Error saving image to $OutputPath. $_"
    }
}

# Setting image variables (using default Windows icons)
$LogoImagePath = $null  # Will use default app icon
$HeroImage = $null      # Will use default image


#This function removes registry entries and associated scripts created during the execution of the script
function Remove-Registry {
    param(
        [string]$ActionName
    )

    # Validate ActionName to prevent registry injection
    if ([string]::IsNullOrWhiteSpace($ActionName)) {
        Write-Warning "ActionName cannot be null or empty."
        return
    }

    if ($ActionName -notmatch '^[a-zA-Z0-9]+$') {
        Write-Warning "Invalid ActionName. Only alphanumeric characters are allowed."
        return
    }

    $MainRegPath = "HKCU:\SOFTWARE\Classes\$ActionName"
    $ScriptPath = Join-Path $env:TEMP "$ActionName.cmd"

    # Remove the registry entries and script
    Remove-Item -Path $MainRegPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
}

# This function checks the time since the last system reboot
Function Get-RebootTime {
    $OS = Get-CimInstance -ClassName "Win32_OperatingSystem"
    $LastBoot = $OS.LastBootUpTime
    $Days = ((Get-Date) - $LastBoot).Days
    Return $Days
}

# This function enforces a system reboot if the specified time limit for reboot delay is reached
Function Restart-ComputerForce {
    Shutdown /g /f /t 600 -c "You have reached the limit time for reboot delay. Please save your work and reboot, or your computer will automatically reboot in 10 minutes."
}

# This function checks if there is an active user session on the system
function Get-UserSession {
    $activeSessionFound = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName -ne $null
    if ($activeSessionFound) {
        Add-Content -Path $LogPath -Value "$(Get-Date) - Active user session detected."
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - No active user sessions found."
    }
    return $activeSessionFound
}


# This function checks if the current day falls on a weekend.
function Get-IsWeekend {
    $today = (Get-Date).DayOfWeek
    return $today -ieq 'Saturday' -or $today -ieq 'Sunday'
}

#region Enhanced Reboot Management Functions

$rebootSchedule = @{
    ScheduledReboots = @()
}

function Schedule-Reboot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [DateTime]$RebootTime,
        [Parameter(Mandatory=$true)]
        [string]$Reason,
        [int[]]$WarningMinutes = @(60, 30, 15, 5),
        [string[]]$NotifyUsers = @($env:USERNAME),
        [switch]$Force
    )

    $scheduledReboot = [PSCustomObject]@{
        RebootTime = $RebootTime
        Reason = $Reason
        WarningMinutes = $warningMinutes
        NotifyUsers = $notifyUsers
        Force = $Force
        Status = 'Scheduled'
        CreatedBy = $env:USERNAME
        CreatedAt = Get-Date
    }

    $rebootSchedule.ScheduledReboots += $scheduledReboot
    $rebootSchedule | Export-Clixml "$env:ProgramData\RebootSchedule.xml" -Force

    # Schedule notifications
    foreach ($minutes in $WarningMinutes) {
        $warningTime = $RebootTime.AddMinutes(-$minutes)
        $trigger = New-ScheduledTaskTrigger -Once -At $warningTime
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-Command `"Show-ToastNotification -Headline 'Reboot Warning' -Body 'System will reboot in $minutes minutes: $Reason'`""

        Register-ScheduledTask -TaskName "RebootWarning_$($scheduledReboot.GetHashCode())_$minutes" `
            -Trigger $trigger -Action $action -Force | Out-Null
    }

    Write-ScriptLog -Level Info -Message "Scheduled reboot for $RebootTime"

    return $scheduledReboot
}

function Get-RebootComplianceReport {
    [CmdletBinding()]
    param(
        [string]$OutputPath = "$env:USERPROFILE\RebootComplianceReport.csv"
    )

    try {
        $computers = Get-ADComputer -Filter {Enabled -eq $true} -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    }
    catch {
        $computers = @($env:COMPUTERNAME)
    }

    $complianceData = @()

    foreach ($computer in $computers) {
        try {
            $lastBoot = Get-CimInstance -ComputerName $computer -ClassName Win32_OperatingSystem -ErrorAction Stop |
                Select-Object -ExpandProperty LastBootUpTime
            $uptime = (Get-Date) - $lastBoot

            $complianceData += [PSCustomObject]@{
                ComputerName = $computer
                LastReboot = $lastBoot
                UptimeDays = [math]::Round($uptime.TotalDays, 1)
                Compliant = $uptime.Days -lt 14
                Online = $true
            }
        }
        catch {
            $complianceData += [PSCustomObject]@{
                ComputerName = $computer
                LastReboot = "N/A"
                UptimeDays = "N/A"
                Compliant = $false
                Online = $false
            }
        }
    }

    $complianceData | Export-Csv -Path $OutputPath -NoTypeInformation
    $complianceData | Format-Table -AutoSize

    # Summary statistics
    $totalComputers = $complianceData.Count
    $onlineComputers = ($complianceData | Where-Object Online).Count
    $compliantComputers = ($complianceData | Where-Object Compliant).Count

    Write-Host "`nCompliance Summary:"
    Write-Host "  Total Computers: $totalComputers"
    Write-Host "  Online: $onlineComputers ($([math]::Round($onlineComputers/$totalComputers*100, 1))%)"
    Write-Host "  Compliant: $compliantComputers ($([math]::Round($compliantComputers/$onlineComputers*100, 1))%)"

    return $complianceData
}

function Set-RebootPolicyViaGPO {
    [CmdletBinding()]
    param(
        [string]$GPOName = "Reboot Policy",
        [int]$MaxUptimeDays = 14,
        [bool]$EnforceReboot = $true,
        [int]$GracePeriodHours = 24
    )

    Write-ScriptLog -Level Info -Message "Reboot policy GPO configured. Manual GPO deployment required."
    Write-Host "GPO Name: $GPOName"
    Write-Host "  Max Uptime: $MaxUptimeDays days"
    Write-Host "  Enforce Reboot: $EnforceReboot"
    Write-Host "  Grace Period: $GracePeriodHours hours"
    Write-Host "`nNote: Manual GPO deployment required to apply these settings."
}

function Get-RebootHistory {
    [CmdletBinding()]
    param(
        [DateTime]$StartDate = (Get-Date).AddDays(-90),
        [DateTime]$EndDate = Get-Date
    )

    $rebootEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ID = 41, 6005, 6006, 6008
        StartTime = $StartDate
        EndTime = $EndDate
    } -ErrorAction SilentlyContinue

    $rebootHistory = @()

    foreach ($event in $rebootEvents) {
        $rebootHistory += [PSCustomObject]@{
            Timestamp = $event.TimeCreated
            EventID = $event.Id
            EventType = switch ($event.Id) {
                41 { "Unexpected Shutdown" }
                6005 { "System Startup" }
                6006 { "System Shutdown" }
                6008 { "System Shutdown (Dirty)" }
                default { "Unknown" }
            }
            User = if ($event.Properties.Count -gt 0) { $event.Properties[0].Value } else { "N/A" }
        }
    }

    $rebootHistory | Sort-Object Timestamp -Descending | Format-Table -AutoSize

    # Analytics
    $totalReboots = ($rebootHistory | Where-Object { $_.EventType -like "*Shutdown*" }).Count
    $unexpectedShutdowns = ($rebootHistory | Where-Object EventType -eq "Unexpected Shutdown").Count

    Write-Host "`nReboot Analytics:"
    Write-Host "  Total Reboots: $totalReboots"
    Write-Host "  Unexpected Shutdowns: $unexpectedShutdowns"
    Write-Host "  Reboot Rate: $([math]::Round($totalReboots/90, 2)) per day"

    return $rebootHistory
}

function Invoke-GracefulShutdown {
    [CmdletBinding()]
    param(
        [int]$WarningMinutes = 15,
        [string]$WarningMessage = "System will reboot in {0} minutes. Please save your work.",
        [scriptblock]$PreShutdownScript,
        [switch]$ShutdownComputer
    )

    Write-ScriptLog -Level Warning -Message "Initiating graceful shutdown sequence"

    $endTime = (Get-Date).AddMinutes($WarningMinutes)

    while ((Get-Date) -lt $endTime) {
        $remaining = [math]::Round(($endTime - (Get-Date)).TotalSeconds / 60)

        if ($remaining -le 5 -or $remaining % 30 -eq 0) {
            Write-ScriptLog -Level Info -Message ($WarningMessage -f $remaining)

            try {
                Show-ToastNotification -Headline "System Shutdown" -Body ($WarningMessage -f $remaining)
            }
            catch {
            }
        }

        Start-Sleep -Seconds 30
    }

    if ($PreShutdownScript) {
        Write-ScriptLog -Level Info -Message "Running pre-shutdown script"
        try {
            & $PreShutdownScript
        }
        catch {
            Write-ScriptLog -Level Error -Message "Pre-shutdown script failed: $_"
        }
    }

    if ($ShutdownComputer) {
        Write-ScriptLog -Level Warning -Message "Executing system shutdown"
        Restart-Computer -Force
    }
}

#endregion

# Main execution block adapted to use Show-ToastNotification
Try {
#This block is the main execution logic of the script, utilizing toast notifications for reboot reminders.
    # Log script start
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution started."

    if (-not (Get-IsWeekend)) {
        $Days = Get-RebootTime
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
            $TimeNow = Get-Date
            $TimeEnd = $TimeStart.AddHours($HoursLimit)

            while ($TimeNow -lt $TimeEnd) {
                $TimeNow = Get-Date

                # Check if the current time exceeds the end time and enforce reboot
                if ($TimeNow -ge $TimeEnd) {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit for reboot reached. Enforcing reboot now."
                    Restart-ComputerForce
                    break # Exit the loop after enforcing reboot
                }

                # Prepare notification parameters
                $Title = "Notice: Pending Reboot Needed"
                $Text1 = "This computer hasn't rebooted for at least $DaysLimit days."
                $Text2 = "Please save your work and restart now or dismiss this reminder."

                if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -lt $WorkEnd) {
                    $loopStartTime = Get-Date
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent: System has not been rebooted for $Days days. Reminder will continue every 30 minutes until reboot."
                    Show-ToastNotification -Headline $Title -Body $Text1 -LogoPath $LogoImagePath -ImagePath $HeroImage
                                        
                    $loopEndTime = Get-Date
                    $elapsedTime = $loopEndTime - $loopStartTime
                    $sleepDuration = $ReminderIntervalSeconds - $elapsedTime.TotalSeconds
                    
                    if ($sleepDuration -gt 0) {
                        Start-Sleep -Seconds $sleepDuration
                    }

                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent. Next reminder in approximately $ReminderIntervalSeconds seconds."
                } else {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Outside of work hours. No reminder sent."
                    Start-Sleep -Seconds $ReminderIntervalSeconds
                }
                $TimeNow = Get-Date
            }
        }
        Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution completed."
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - Today is a weekend. No operation performed."
    }
}

Catch {
 #This block handles errors that occur during script execution.
    # Error handling remains largely the same
    $ErrorMessage = $_.Exception.Message
    $ErrorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ErrorCode = $_.Exception.HResult
    $ErrorStackTrace = $_.Exception.StackTrace
    $LogMessage = "$(Get-Date) - Error encountered: $ErrorMessage (Code: $ErrorCode). StackTrace: $ErrorStackTrace"
    Add-Content -Path $LogPath -Value $LogMessage
}

Finally {
#This block executes cleanup actions after the main execution block completes or if an error occurs.
    # Clean up any resources if necessary
    Add-Content -Path $LogPath -Value "$(Get-Date) - Clean up resources."
    # Remove-Registry could be called here based on specific conditions or user actions
    Remove-Registry -ActionName "RestartNow"
    Remove-Registry -ActionName "DismissOrSnooze"
}
