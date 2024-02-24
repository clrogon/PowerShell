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
    [string]$LogPath = "$env:USERPROFILE\RebootLog.log",
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
    # Interval in seconds between subsequent reminder notifications. Default is 300 seconds (5 minutes).
    [int]$ReminderIntervalSeconds = 300,
    # Used in the reminder notification to inform users of the reminder frequency. Default is 30 minutes.
    [int]$ReminderIntervalMinutes = 30
)

# Load necessary assemblies for creating UI components and dialog boxes.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# Function to check the last time the computer has been rebooted
Function Check-RebootTime {
    # Retrieves system information using CIM, specifically the Win32_OperatingSystem class
    $OS = Get-CimInstance -ClassName "Win32_OperatingSystem"
    # Extracts the last boot-up time from the operating system information
    $LastBoot = $OS.LastBootUpTime
    # Calculates the number of days since the last boot-up time by subtracting it from the current date
    $Days = ((Get-Date) - $LastBoot).Days
    # Returns the calculated days since last reboot to the caller
    Return $Days
}

# Function to create a balloon notification
Function Create-BalloonNotification ($Text, $Title) {
    # Creates a new instance of a notification icon in the system tray
    $Balloon = New-Object System.Windows.Forms.NotifyIcon
    # Sets the icon to display a warning symbol
    $Balloon.BalloonTipIcon = "Warning"
    # Sets the text of the balloon notification
    $Balloon.BalloonTipText = $Text
    # Sets the title of the balloon notification
    $Balloon.BalloonTipTitle = $Title
    # Specifies the icon to use for the balloon notification; here, it's set to the system's information icon
    $Balloon.Icon = [System.Drawing.SystemIcons]::Information
    # Makes the notification icon visible in the system tray
    $Balloon.Visible = $true
    # Displays the balloon tip with the specified display duration
    $Balloon.ShowBalloonTip($BalloonTipDisplayTime)
    # Returns the balloon notification object for further actions or disposal
    Return $Balloon
}

# Function to dispose of balloon notification
Function Dispose-BalloonNotification {
    param(
        # Accepts a NotifyIcon object as input, ensuring the function can target the specific notification to be disposed.
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.NotifyIcon]$Balloon
    )
    # Ensures that the function attempts disposal only if the NotifyIcon object exists to avoid null reference errors.
    if ($Balloon -ne $null) {
        # Removes event subscriptions related to the balloon notification to prevent memory leaks.
        Unregister-Event -SourceIdentifier click_event -ErrorAction SilentlyContinue
        # Pauses execution for 2 seconds to allow any ongoing events to conclude before proceeding with disposal.
        Start-Sleep -Seconds 2
        # Sets the balloon's visibility to false as a cleanup step before disposal to ensure it disappears from the system tray.
        $Balloon.Visible = $false
        # Releases the resources used by the NotifyIcon object, effectively removing the notification from memory.
        $Balloon.Dispose()
    }
}

# Function to create a restart prompt with the option for the user to postpone the reboot
Function Create-RestartPrompt {
    # Displays a message box asking the user if they would like to reboot now with Yes and No options.
    $Result = [Microsoft.VisualBasic.Interaction]::MsgBox('Would you like to reboot your computer now?', 'YesNo,MsgBoxSetForeground,Question', 'System Maintenance')
    # If the user clicks "Yes", execute a system command to reboot immediately.
    if ($Result -ieq "Yes") {
        Shutdown /g /t 0 /f
    }
    else {
        # If the user selects "No", return true to indicate the choice to postpone.
        return $true
    }
    # If the user selects "Yes", the script returns false, indicating the reboot will proceed.
    return $false
}

# Function to enforce a system reboot
Function Enforce-Reboot {
    # Initiates a system shutdown with a reboot (/g), forces applications to close (/f), sets a timer for 600 seconds (10 minutes) (/t 600), and displays a custom message (-c) to the user.
    Shutdown /g /f /t 600 -c "You have reached the limit time for reboot delay. Please save your work and reboot, or your computer will automatically reboot in 10 minutes."
}

# Function to check if a user session is currently active
Function Check-UserSession {
    # Queries the system for current user sessions, capturing both standard output and error output.
    $SessionInfo = query user 2>&1
    $activeSessionFound = $false
    
    # Iterates through each line of the session info looking for active sessions.
    foreach ($line in $SessionInfo) {
        if ($line -match "\s+Active") {
            $activeSessionFound = $true
            break
        }
    }
    
    # Logs the presence of an active user session and returns true; otherwise, logs the absence and returns false.
    if ($activeSessionFound) {
        Add-Content -Path $LogPath -Value "$(Get-Date) - An active user session was found."
        return $true
    } else {
        Add-Content -Path $LogPath -Value "$(Get-Date) - No active user sessions found."
        return $false
    }
}

# Function to check if its Weekend
function Is-Weekend {
    # Gets the current day of the week.
    $today = (Get-Date).DayOfWeek
    # Returns true if today is Saturday or Sunday, indicating it's a weekend.
    return $today -ieq 'Saturday' -or $today -ieq 'Sunday'
}

# Main execution block
Try {
    # Log the start of the script's execution
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script started."
    
    # Check if today is a weekend to skip reboot reminders
    if (-not (Is-Weekend)) {
        # Retrieve the number of days since the last reboot
        $Days = Check-RebootTime
        # If the days exceed the limit, initiate reminder and possible reboot sequence
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
            # Calculate when to enforce a reboot based on the hours limit
            $TimeEnd = $TimeStart.AddHours($HoursLimit)
            # Prepare notification text and title
            $Text = "This computer hasn't rebooted for at least $DaysLimit days. This alert will appear every $ReminderIntervalMinutes minutes until the computer is rebooted. Please save your work."
            $Title = "Notice: Pending Reboot Needed"

            # Loop to check time and user session, displaying reminders as needed
            do {
                $TimeNow = Get-Date
                # If the time to enforce reboot is reached, proceed with the reboot
                if ($TimeNow -ge $TimeEnd) {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit reached. Enforcing reboot."
                    Enforce-Reboot
                    break
                }
                
                # During work hours, display the balloon notification reminder
                if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -lt $WorkEnd) {
                    $Balloon = Create-BalloonNotification -Text $Text -Title $Title
                    Start-Sleep -Seconds $ReminderIntervalSeconds
                    $Balloon.Dispose()
                }

                # Log each reminder and check for active user sessions
                Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent, user session status: $(Check-UserSession)"
                Start-Sleep -Seconds $ReminderIntervalSeconds
            } While ($TimeNow -lt $TimeEnd) # Continue until the end time is reached
        }
        # Log script completion
        Add-Content -Path $LogPath -Value "$(Get-Date) - Script ended."
    } else {
        # If it's a weekend, log that no reminder is needed
        Add-Content -Path $LogPath -Value "$(Get-Date) - Today is a weekend. No reminder needed."
    }
}

Catch {
    # Handle exceptions by logging any errors encountered during execution
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
    # Ensure the balloon notification object is disposed of to free resources
    if ($Balloon) {
        $Balloon.Dispose()
    }
}
