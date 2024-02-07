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
    [Parameter(Mandatory=$false)]
    [int]$DaysLimit = 7,
    [Parameter(Mandatory=$false)]
    [int]$HoursLimit = 5,
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "$env:USERPROFILE\RebootLog.log",  # Updated default path
    [Parameter(Mandatory=$false)]
    [int]$WorkStart = 8,
    [Parameter(Mandatory=$false)]
    [int]$WorkEnd = 17
)

# Load necessary assemblies for Windows Forms and VB message box
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# Function to check the last time the computer has been rebooted
Function Check-RebootTime {
    $OS = Get-WmiObject -Namespace "root\cimv2" -Class "win32_OperatingSystem"
    $LastBoot = $OS.ConvertToDateTime($OS.LastBootUpTime)
    $Days = ((Get-Date)-$LastBoot).Days
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
    $Balloon.ShowBalloonTip(0)
    Return $Balloon
}

# Function to create a restart prompt with option to postpone
Function Create-RestartPrompt {
    $Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Would you like to reboot your computer now?', 'YesNo,MsgBoxSetForeground,Question', 'System Maintenance')
    if ($Result -eq "YES") {
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

# Function to check if user session is active
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
        Add-Content -Path $LogPath -Value "$(Get-Date) - An active user session was found."
        return $true
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - No active user sessions found."
        return $false
    }
}

# Function to Check for Weekends
function Is-Weekend {
    $today = (Get-Date).DayOfWeek
    return $today -eq 'Saturday' -or $today -eq 'Sunday'
}

# Main execution block
Try {
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script started."
    
    # Check if today is a weekend
    if (-not (Is-Weekend)) {
        $Days = Check-RebootTime
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
            $TimeEnd = $TimeStart.AddHours($HoursLimit)
            $WaitSeconds = 1200
            $Text = "This computer hasn't rebooted for at least $DaysLimit days. This alert will appear every 30 minutes until the computer is rebooted. Please save your work."
            $Title = "Notice: Pending Reboot Needed"

            do {
                $TimeNow = Get-Date
                if ($TimeNow -ge $TimeEnd) {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit reached. Enforcing reboot."
                    Enforce-Reboot
                } else {
                    if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -le $WorkEnd) {
                        $Balloon = Create-BalloonNotification -Text $Text -Title $Title
                        
                        # Ensure any existing click event is unregistered before registering a new one
                        $existingEvent = Get-EventSubscriber -SourceIdentifier 'click_event' -ErrorAction SilentlyContinue
                        if ($existingEvent) {
                            Unregister-Event -SourceIdentifier 'click_event'
                        }
                        
                        Register-ObjectEvent $Balloon BalloonTipClicked -SourceIdentifier 'click_event' -Action {
                            Create-RestartPrompt
                        } | Out-Null
                        
                        Wait-Event -Timeout $WaitSeconds -SourceIdentifier click_event > $null
                        $Balloon.Dispose()
                    }
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent, user session status: $(Check-UserSession)"
                }
            } Until ($TimeNow -ge $TimeEnd -or (!(Check-UserSession)))
        }
        Add-Content -Path $LogPath -Value "$(Get-Date) - Script ended."
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - Today is a weekend. No reminder needed."
    }
} 

Catch {
    $ErrorMessage = $_.Exception.Message
    $LogDirectory = Split-Path $LogPath -Parent
    if (Test-Path $LogDirectory) {
        Add-Content -Path $LogPath -Value "$(Get-Date) - Error encountered: $ErrorMessage"
    } else {
        Write-Error "Log directory does not exist and cannot log the error: $ErrorMessage"
        New-Item -ItemType Directory -Path $LogDirectory -Force
        Add-Content -Path $LogPath -Value "$(Get-Date) - Error encountered: $ErrorMessage"
    }
} 

Finally {
    # Cleanup operations to ensure the script exits cleanly, regardless of success or failure
    if ($Balloon) {
        $Balloon.Dispose()
    }
}
