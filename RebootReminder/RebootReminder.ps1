<#
.Synopsis
   A script to remind the user to reboot their system.
.DESCRIPTION
   This script sends a Balloon Notification to the user to remind them to reboot the computer if it has not been rebooted for a specified number of days. 
   If the computer isn't rebooted within a specified timeframe, it will enforce a system reboot.
.EXAMPLE
   ./RebootReminder.ps1 -DaysLimit 7
   This example will run the script with the default values for HoursLimit (5 hours), LogPath (C:\temp\RebootLog.log), WorkStart (8 AM), and WorkEnd (5 PM).
   
   ./RebootReminder.ps1 -DaysLimit 7 -HoursLimit 4 -LogPath "C:\logs\RebootLog.log" -WorkStart 9 -WorkEnd 18
   This example will run the script with custom values. The script will enforce a reboot if the computer hasn't been rebooted within 4 hours. It will log the events to C:\logs\RebootLog.log. The script will only send notifications between 9 AM and 6 PM.
.INPUTS
   Integer. The number of days to check for the last reboot.
   Integer. The number of hours before enforcing a reboot (default is 5 hours).
   String. The path for the log file (default is C:\temp\RebootLog.log).
   Integer. The start of the workday in 24-hour format (default is 8).
   Integer. The end of the workday in 24-hour format (default is 17).
.OUTPUTS
   None. The script enforces a system reboot or sends a visual notification to the user.
.NOTES
   This script is intended to be run using the Windows Task Scheduler. Schedule this script to run once per day to check for the last reboot time.
.AUTHOR
   Concept by Cláudio Gonçalves
#>

param (
    [Parameter(Mandatory=$true)]
    [int]$DaysLimit,
    [Parameter(Mandatory=$false)]
    [int]$HoursLimit = 5,
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\temp\RebootLog.log",
    [Parameter(Mandatory=$false)]
    [int]$WorkStart = 8,
    [Parameter(Mandatory=$false)]
    [int]$WorkEnd = 17
)

# Load necessary assemblies for Windows Forms and VB message box
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$Global:TimeEnd = $null

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
    $Balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
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
        $Global:TimeEnd = $Global:TimeEnd.AddHours(2)
    }
}

# Function to enforce a system reboot
Function Enforce-Reboot {
    Shutdown /g /f /t 600 -c "You have reached the limit time for reboot delay. Please save your work and reboot, or your computer will automatically reboot in 10 minutes."
}

# Function to check if user session is active
Function Check-UserSession {
    $Session = query user /server:$env:computername 2>&1 | where {$_ -notmatch "^(>|No User exists for *)" } 
    return $Session
}

# Main execution block
Try {
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script started."
    $Days = Check-RebootTime
    if ($Days -ge $DaysLimit) {
        $TimeStart = Get-Date
        $Global:TimeEnd = $TimeStart.AddHours($HoursLimit)
        $WaitSeconds = 1200
        $Text = "This computer hasn't rebooted for at least $DaysLimit days. This alert will appear every 30 minutes until the computer is rebooted. Please save your work."
        $Title ="Notice: Pending Reboot Needed"
        do {
            $TimeNow = Get-Date
            if ($TimeNow -ge $Global:TimeEnd) {
                Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit reached. Enforcing reboot."
                Enforce-Reboot
            }
            else {
                if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -le $WorkEnd) {
                    $Balloon = Create-BalloonNotification -Text $Text -Title $Title
                    if (Get-EventSubscriber -SourceIdentifier 'click_event' -ErrorAction SilentlyContinue) {
                        Unregister-Event -SourceIdentifier 'click_event' -ErrorAction SilentlyContinue
                    }
                    Register-ObjectEvent $Balloon BalloonTipClicked -SourceIdentifier click_event -Action { Create-RestartPrompt } | Out-Null
                    Wait-Event -Timeout $WaitSeconds -SourceIdentifier click_event > $null
                    $Balloon.Dispose()
                }
                Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent, last reboot time: $($LastBoot), user session status: $(Check-UserSession)"
            }
        }
        Until (($TimeNow -ge $Global:TimeEnd) -or (!(Check-UserSession)))
    }
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script ended."
}
Catch {
    $ErrorMessage = "An error occurred: $_"
    Write-Error $ErrorMessage
    Add-Content -Path $LogPath -Value "$(Get-Date) - $ErrorMessage"
}
