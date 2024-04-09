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
    
    # Validate the ActionName to prevent issues with file names and registry keys
    if ($ActionName -notmatch '^[\w\d-]+$') {
        Write-Error "Invalid ActionName. Only alphanumeric characters and dashes are allowed."
        return
    }

    Try {
        # Use the environment variable for the temporary directory
        $ScriptPath = "$env:TEMP\$ActionName.cmd"
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

# Base64 strings for the images
$LogoImageBase64 = "<Base64StringForLogoImage>"
$HeroImageBase64 = "<Base64StringForHeroImage>"

# Setting image variables
$LogoImagePath = "$env:TEMP\ToastLogoImage.png"
$HeroImage = "$env:TEMP\ToastHeroImage.gif"

# Save Base64 strings to files
Save-Base64StringToFile -Base64String $LogoImageBase64 -OutputPath $LogoImagePath
Save-Base64StringToFile -Base64String $HeroImageBase64 -OutputPath $HeroImage

# Check if the images already exist locally and are valid
if (-not (Test-Path $LogoImagePath) -or -not (Test-Path $HeroImage)) {
    # Images not found locally, save them
    Save-Base64StringToFile -Base64String $LogoImageBase64 -OutputPath $LogoImagePath
    Save-Base64StringToFile -Base64String $HeroImageBase64 -OutputPath $HeroImage
} else {
    # Images exist locally, check if they are outdated
    $logoLastModified = (Get-Item $LogoImagePath).LastWriteTime
    $heroLastModified = (Get-Item $HeroImage).LastWriteTime
    $currentDate = Get-Date
    $maxAge = New-TimeSpan -Days 1  # Define maximum age for images (e.g., 1 day)

    if (($currentDate - $logoLastModified) -gt $maxAge -or ($currentDate - $heroLastModified) -gt $maxAge) {
        # Images are outdated, save new versions
        Save-Base64StringToFile -Base64String $LogoImageBase64 -OutputPath $LogoImagePath
        Save-Base64StringToFile -Base64String $HeroImageBase64 -OutputPath $HeroImage
    } else {
        # Images are up to date, no action needed
        Write-Output "Images are up to date."
    }
}


#This function removes registry entries and associated scripts created during the execution of the script
function Remove-Registry {
    param(
        [string]$ActionName
    )

    $MainRegPath = "HKCU:\SOFTWARE\Classes\$ActionName"
    $ScriptPath = "C:\Windows\Temp\$ActionName.cmd"

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

# Main execution block adapted to use Show-ToastNotification
Try {
#This block is the main execution logic of the script, utilizing toast notifications for reboot reminders.
    # Log script start
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution started."

    if (-not (Get-IsWeekend)) {
        $Days = Get-RebootTime
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
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
    Remove-Registry -ActionName $RestartNow
    Remove-Registry -ActionName "DismissOrSnooze"
    Write-Warning "The balloon notification variable did not contain a valid NotifyIcon instance."
}
