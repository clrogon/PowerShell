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

# Load necessary assemblies for the Show-ToastNotification function
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

#Check if the Log file exist
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

# Function definitions for Set-Action, Show-ToastNotification, and Cleanup-Registry
function Set-Action {
    param(
        [string]$ActionName,
        [string]$ScriptContent
    )
    
    Try {
        $ScriptPath = "C:\Windows\Temp\$ActionName.cmd"
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
        $ErrorMessage = $_.Exception.Message
        Add-Content -Path $LogPath -Value "$(Get-Date) - Error encountered during [Operation]: $ErrorMessage"
    }
}

function Show-ToastNotification {
    param(
    [Parameter(Mandatory=$false)]
    [string]$Icon = "DefaultIconPath",
    [Parameter(Mandatory=$false)]
    [string]$Hero = "DefaultHeroImagePath",
    [Parameter(Mandatory=$false)]
    [string]$Title = "Default Title",
    [Parameter(Mandatory=$false)]
    [string]$Text1 = "Default text 1",
    [Parameter(Mandatory=$false)]
    [string]$Text2 = "Default text 2"
    )

    $ToastImageAndText04 = [Windows.UI.Notifications.ToastTemplateType, Windows.UI.Notifications, ContentType = WindowsRuntime]::ToastImageAndText04
    $ToastImageAndText04XML = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]::GetTemplateContent($ToastImageAndText04)

    # Customize notification content
    $ToastImageAndText04XML.SelectSingleNode('//text[@id="1"]').InnerText = $Title
    $ToastImageAndText04XML.SelectSingleNode('//text[@id="2"]').InnerText = $Text1
    $ToastImageAndText04XML.SelectSingleNode('//text[@id="3"]').InnerText = $Text2
    $ToastImageAndText04XML.SelectSingleNode('//image[@id="1"]').SetAttribute('src', $Icon)
    $ToastImageAndText04XML.SelectSingleNode('//image[@id="1"]').SetAttribute('hint-crop', 'none')
    $ToastImageAndText04XML.SelectSingleNode('//image[@id="1"]').SetAttribute('placement', 'appLogoOverride')

    # Add actions and buttons
    $Actions = $ToastImageAndText04XML.SelectSingleNode('//toast').AppendChild($ToastImageAndText04XML.CreateElement("actions"))

    # "Restart now" and "Dismiss" button setup
    $RestartButton = $ToastImageAndText04XML.CreateElement("action")
    $RestartButton.SetAttribute('content', 'Restart now')
    $RestartButton.SetAttribute('activationType', 'protocol')
    $RestartButton.SetAttribute('arguments', 'RestartNow:')
    $DismissButton = $ToastImageAndText04XML.CreateElement("action")
    $DismissButton.SetAttribute('content', 'Dismiss')
    $DismissButton.SetAttribute('activationType', 'system')
    $DismissButton.SetAttribute('arguments', 'dismiss')

    # Append buttons
    $Actions.AppendChild($RestartButton) | Out-Null
    $Actions.AppendChild($DismissButton) | Out-Null

    # Hero image setup
    $HeroImage = $ToastImageAndText04XML.CreateElement("image")
    $HeroImage.SetAttribute('placement', 'hero')
    $HeroImage.SetAttribute('src', $Hero)
    $ToastImageAndText04XML.SelectSingleNode('//binding').AppendChild($HeroImage) | Out-Null

    # Switch to ToastGeneric template for hero image
    $ToastImageAndText04XML.SelectSingleNode('//binding').SetAttribute('template', 'ToastGeneric')

    # App ID retrieval for toast notifier
    $AppId = (Get-StartApps | Where-Object { $_.Name -eq "Windows PowerShell" } | Select-Object -First 1).AppID

    # Set up the "RestartNow" action
    $RestartScriptContent = "Shutdown /g /t 300 /f"
    Set-Action -ActionName "RestartNow" -ScriptContent $RestartScriptContent

    # Show the notification
    $ToastNotification = [Windows.UI.Notifications.ToastNotification]::new($ToastImageAndText04XML)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($ToastNotification)
}

function Cleanup-Registry {
    param(
        [string]$ActionName
    )

    $MainRegPath = "HKCU:\SOFTWARE\Classes\$ActionName"
    $ScriptPath = "C:\Windows\Temp\$ActionName.cmd"

    # Remove the registry entries and script
    Remove-Item -Path $MainRegPath -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
}

# Helper functions from Reboot Reminder script
Function Check-RebootTime {
    $OS = Get-CimInstance -ClassName "Win32_OperatingSystem"
    $LastBoot = $OS.LastBootUpTime
    $Days = ((Get-Date) - $LastBoot).Days
    Return $Days
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

# Main execution block adapted to use Show-ToastNotification
Try {
    # Log script start
    Add-Content -Path $LogPath -Value "$(Get-Date) - Script execution started."

    if (-not (Is-Weekend)) {
        $Days = Check-RebootTime
        if ($Days -ge $DaysLimit) {
            $TimeStart = Get-Date
            $TimeEnd = $TimeStart.AddHours($HoursLimit)

            while ($TimeNow -lt $TimeEnd) {
                $TimeNow = Get-Date

                # Check if the current time exceeds the end time and enforce reboot
                if ($TimeNow -ge $TimeEnd) {
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Time limit for reboot reached. Enforcing reboot now."
                    Enforce-Reboot
                    break # Exit the loop after enforcing reboot
                }

                # Extract hours and minutes from the time remaining
                $timeRemaining = $TimeEnd - $TimeNow
                $hoursRemaining = [Math]::Floor($timeRemaining.TotalHours)
                $minutesRemaining = $timeRemaining.Minutes

                # Prepare notification parameters
                $Icon = "C:\TSTFolder\logo.png"
                $Hero = "C:\TSTFolder\reboot.gif"
                $Title = "Notice: Pending Reboot Needed"
                $Text1 = "This computer hasn't rebooted for at least $DaysLimit days."
                $Text2 = "Please save your work and restart now or dismiss this reminder."

                if ($TimeNow.Hour -ge $WorkStart -and $TimeNow.Hour -lt $WorkEnd) {
                    $loopStartTime = Get-Date
                    Add-Content -Path $LogPath -Value "$(Get-Date) - Reminder sent: System has not been rebooted for $Days days. Reminder will continue every $ReminderIntervalMinutes minutes until reboot."
                    Show-ToastNotification -Icon $Icon -Hero $Hero -Title $Title -Text1 $Text1 -Text2 $Text2
                    
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
    # Error handling remains largely the same
    $ErrorMessage = $_.Exception.Message
    $ErrorTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ErrorCode = $_.Exception.HResult
    $ErrorStackTrace = $_.Exception.StackTrace
    $LogMessage = "$(Get-Date) - Error encountered: $ErrorMessage (Code: $ErrorCode). StackTrace: $ErrorStackTrace"
    Add-Content -Path $LogPath -Value $LogMessage
}

Finally {
    # Clean up any resources if necessary
    Add-Content -Path $LogPath -Value "$(Get-Date) - Clean up resources."
    #Cleanup-Registry
    # Cleanup-Registry could be called here based on specific conditions or user actions
    Write-Warning "The balloon notification variable did not contain a valid NotifyIcon instance."
}
