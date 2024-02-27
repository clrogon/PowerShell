<#
.Synopsis
   A PowerShell script designed to prompt users for a system reboot if their computer has not been rebooted within a specified number of days.

.Description
   Utilizes balloon notifications to gently remind users to reboot their computer after it has been on for a specified number of days without a restart. The script incorporates checks to avoid reminding users on weekends and enforces a system reboot if the computer is not rebooted within a certain timeframe after the reminder, ensuring system updates and maintenance routines are applied.

.Example
   .\RebootReminder.ps1 -DaysLimit 7
   Executes the script with default settings, setting the reminder for 7 days since the last reboot with a 5-hour window before a forced reboot, and logs events to the user's profile directory.

.Example
   .\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 4 -LogPath "C:\logs\RebootLog.log" -WorkStart 9 -WorkEnd 18
   Specifies a 7-day limit before reminders start, a 4-hour window for forced reboots after the reminder, a custom log path, and active reminder hours between 9 AM and 6 PM.

.Inputs
   -DaysLimit  Specifies the number of days to check since the last reboot before sending a reminder.
   -HoursLimit  Defines the number of hours to wait after the first reminder before enforcing a reboot (default is 5 hours).
   -LogPath     Custom path for logging script activities (default is $env:USERPROFILE\RebootLog.log).
   -WorkStart   Start hour in 24-hour format for when reminders can begin being sent.
   -WorkEnd     End hour in 24-hour format for when reminders should stop being sent.

.Outputs
   None. The script interacts directly with the user through notifications and potentially enforces a system reboot.

.Notes
   Designed for deployment via Windows Task Scheduler for daily execution. Incorporates checks to skip reminders on weekends, robust error handling to log issues to a specified path, and ensures clean resource management for optimal script performance.
   Version: 3.2
   Author: Concept by Cláudio Gonçalves
   Last Updated: 07/02/2024
#>
param (
# Defines the threshold in days to trigger a reboot reminder. Default is 7 days.
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,365)]
    [int]$DaysLimit = 7,
# Defines the grace period in hours before a forced reboot after the reminder. Default is 5 hours.
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,24)]
    [int]$HoursLimit = 5,
# Sets the path for the log file where script activities are recorded. Default is RebootLog.log in the user's profile directory.
    [Parameter(Mandatory=$false)]
    [string]$LogPath = $(if (Test-Path "$env:USERPROFILE\RebootLog.log") { "$env:USERPROFILE\RebootLog.log" } else { "$env:TEMP\RebootLog.log" }),
# Specifies the start of the workday for reminder display. Default is 8 AM.
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,23)]
    [int]$WorkStart = 8,
# Specifies the end of the workday for reminder display. Default is 5 PM (17 in 24-hour format).
    [Parameter(Mandatory=$false)]
    [ValidateRange(0,23)]
    [int]$WorkEnd = 17,
# Duration in milliseconds for displaying the balloon tip notification. Default is 10000 ms (10 seconds).
    [int]$BalloonTipDisplayTime = 10000,
# Interval in seconds between subsequent reminder notifications. Default is 1800 seconds (30 minutes).
    [int]$ReminderIntervalSeconds = 1800,
# Used in the reminder notification to inform users of the reminder frequency. Default is 30 minutes.
    [int]$ReminderIntervalMinutes = 30
)

# Load necessary assemblies for creating UI components and dialog boxes.
Try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName Microsoft.VisualBasic
}

Catch {
    $ErrorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$(Get-Date) - Failed to load necessary assemblies for UI components. Check System.Windows.Forms and Microsoft.VisualBasic availability."
    Add-Content -Path $LogPath -Value $LogMessage
    Write-Error $LogMessage
    Exit
}

if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType File -Force | Out-Null
}

# Before logging, check the size of the log file and archive if necessary
$LogFileSizeLimit = 10MB
$LogFile = Get-Item $LogPath
if ($LogFile.Length -gt $LogFileSizeLimit) {
    $ArchivePath = "$LogPath.old"
    Move-Item $LogPath $ArchivePath -Force
}

# Function to check the last time the computer has been rebooted
Function Check-RebootTime {
    $OS = Get-CimInstance -ClassName "Win32_OperatingSystem"
    $LastBoot = $OS.LastBootUpTime
    $Days = ((Get-Date) - $LastBoot).Days
    Return $Days
}

# Function to create a balloon notification
Function Create-BalloonNotification ($Text, $Title) {
    $Balloon = New-Object System.Windows.Forms.NotifyIcon
    $Balloon.BalloonTipIcon = "Warning"
    $Balloon.BalloonTipText = $Text
    $Balloon.BalloonTipTitle = $Title
    $Balloon.Icon = [System.Drawing.SystemIcons]::Information
    $Balloon.Visible = $true
    $Balloon.ShowBalloonTip($BalloonTipDisplayTime)
    Return $Balloon
}

# Function to dispose of balloon notification
Function Dispose-BalloonNotification {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.NotifyIcon]$Balloon
    )
    if ($Balloon -ne $null) {
        Start-Sleep -Seconds 2
        $Balloon.Visible = $false
        $Balloon.Dispose()
    }
}

# Function to create a restart prompt with the option for the user to postpone the reboot
Function Create-RestartPrompt {
    $Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Would you like to reboot your computer now?', 'YesNo,MsgBoxSetForeground,Question', 'System Maintenance')
    if ($Result -ieq "Yes") {
        Shutdown /g /t 0 /f
    }
    else {
        return $true
    }
    return $false
}

# Function to enforce a system reboot
Function Enforce-Reboot {
    Shutdown /g /f /t 600 -c "You have reached the limit time for reboot delay. Please save your work and reboot, or your computer will automatically reboot in 10 minutes."
}

# Function to check if a user session is currently active
Function Check-UserSession {
    $SessionInfo = query user 2>&1
    $activeSessionFound = $false
    
    foreach ($line in $SessionInfo) {
        if ($line -match "\s+Active") {
            $activeSessionFound = $true
            break
        }
    }
    
    if ($activeSessionFound) {
        Add-Content -Path $LogPath -Value "$(Get-Date) - Active user session detected."
        return $true
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - No active user sessions found."
        return $false
    }
}

# Function to check if its Weekend
function Is-Weekend {
    $today = (Get-Date).DayOfWeek
    return $today -ieq 'Saturday' -or $today -ieq 'Sunday'
}

# Main execution block
Try {
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution started."
    
    if (-not (Is-Weekend)) {
        $Days = Check-RebootTime
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
            $TimeEnd = $TimeStart.AddHours($HoursLimit)
            
            do {
                $TimeNow = Get-Date
                $timeRemaining = $TimeEnd - $TimeNow

                # Extract hours and minutes from the time remaining
                $hoursRemaining = [Math]::Floor($timeRemaining.TotalHours)
                $minutesRemaining = $timeRemaining.Minutes
                $Text = "This computer hasn't rebooted for at least $DaysLimit days. You have a grace period of $hoursRemaining hours and $minutesRemaining minutes. This alert will appear every $ReminderIntervalMinutes minutes until the computer is rebooted. Please save your work."

                if ($TimeNow -ge $TimeEnd) {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit for reboot reached. Enforcing reboot now."
                    Enforce-Reboot
                    break
                }
                
                if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -lt $WorkEnd) {
                    $Balloon = Create-BalloonNotification -Text $Text -Title "Notice: Pending Reboot Needed"
                    Start-Sleep -Seconds $ReminderIntervalSeconds
                    Dispose-BalloonNotification -Balloon $Balloon
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent: System has not been rebooted for $Days days. Reminder will continue every $ReminderIntervalMinutes minutes until reboot."
                } 
                else {
                    # Log attempt outside of work hours
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder attempt outside work hours ($WorkStart to $WorkEnd) was skipped."
                }

                Start-Sleep -Seconds $ReminderIntervalSeconds
            } While ($TimeNow -lt $TimeEnd)
        }
        Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution completed."
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - No reminder sent: Today is a weekend."
        Exit
    }
}

Catch {
    $ErrorMessage = $_.Exception.Message
    $ErrorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ErrorCode = $_.Exception.HResult
    $ErrorStackTrace = $_.Exception.StackTrace
    $LogMessage = "$(Get-Date) - Error encountered: $ErrorMessage (Code: $ErrorCode). StackTrace: $ErrorStackTrace"
    Add-Content -Path $LogPath -Value $LogMessage
}

Finally {
    if ($Balloon -is [System.Windows.Forms.NotifyIcon]) {
        $Balloon.Dispose()
    } else {
        Write-Warning "The balloon notification variable did not contain a valid NotifyIcon instance."
    }
}
