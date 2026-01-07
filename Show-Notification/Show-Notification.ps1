#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)

$notificationTemplates = @{
    Maintenance = @{
        Title = "System Maintenance Scheduled"
        Body = "Maintenance will begin at {0} and last approximately {1}. Please save your work."
        Buttons = @{ "Acknowledge" = "MaintenanceAck:"; "RemindMe" = "MaintenanceRemind:" }
        Icon = "Info"
    }
    SecurityAlert = @{
        Title = "Security Alert"
        Body = "Suspicious activity detected. Please contact IT Security at {0}."
        Buttons = @{ "Dismiss" = "SecurityDismiss:"; "ContactIT" = "SecurityContact:" }
        Icon = "Warning"
    }
    SoftwareUpdate = @{
        Title = "Software Update Available"
        Body = "{0} version {1} is ready to install. Click to install now."
        Buttons = @{ "InstallNow" = "UpdateInstall:"; "ScheduleLater" = "UpdateLater:" }
        Icon = "Info"
    }
    RebootRequired = @{
        Title = "System Restart Required"
        Body = "Your computer needs to restart to complete updates. Please save your work."
        Buttons = @{ "RestartNow" = "RestartNow:"; "Dismiss" = "RebootDismiss:" }
        Icon = "Warning"
    }
    Information = @{
        Title = "Information"
        Body = "{0}"
        Buttons = @{ "OK" = "InfoOK:" }
        Icon = "Info"
    }
}

$notificationQueue = @()

function Show-Notification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ToastTitle,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ToastText,

        [ValidateSet('ToastImageAndText01', 'ToastImageAndText02', 'ToastImageAndText03', 'ToastImageAndText04')]
        [string]$TemplateType = 'ToastImageAndText04', # Default to a template that supports buttons

        [ValidateRange(0.1, 60)]
        [double]$ExpirationTime = 1,

        [string]$AppLogo, # Path to the app logo image

        [switch]$Silent,

        [hashtable]$Buttons # New parameter for buttons as a hashtable
    )

    begin {
        if (-not ([System.Management.Automation.PSTypeName]'Windows.UI.Notifications.ToastNotificationManager').Type) {
            throw 'This function requires the Windows 10 SDK or later.'
        }

        # Retrieve the specified template type for the toast notification
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::$TemplateType)
        $xml = [xml]$template.GetXml()

        # Function to sanitize input to prevent XML injection
        function Sanitize-XmlInput {
            param([string]$InputString)

            if ([string]::IsNullOrEmpty($InputString)) {
                return $InputString
            }

            # Replace XML special characters with their entities
            $sanitized = $InputString -replace '&', '&amp;'
            $sanitized = $sanitized -replace '<', '&lt;'
            $sanitized = $sanitized -replace '>', '&gt;'
            $sanitized = $sanitized -replace '"', '&quot;'
            $sanitized = $sanitized -replace "'", '&apos;'

            return $sanitized
        }

        # Function to validate and sanitize file paths
        function Test-ValidImagePath {
            param([string]$Path)

            if ([string]::IsNullOrWhiteSpace($Path)) {
                return $false
            }

            # Check for path traversal
            if ($Path -match '\.\.') {
                throw "Path contains directory traversal sequences: $Path"
            }

            # Validate the path
            if (-not (Test-Path -Path $Path -PathType Leaf -ErrorAction SilentlyContinue)) {
                throw "The specified image file does not exist: $Path"
            }

            # Check for valid image extensions
            $validExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico')
            $extension = [System.IO.Path]::GetExtension($Path).ToLower()

            if ($extension -notin $validExtensions) {
                throw "Invalid image file extension: $extension"
            }

            return $true
        }
    }

    process {
        try {
            # Sanitize input strings to prevent XML injection
            $safeTitle = Sanitize-XmlInput -InputString $ToastTitle
            $safeText = Sanitize-XmlInput -InputString $ToastText

            # Validate AppLogo if provided
            if ($AppLogo) {
                Test-ValidImagePath -Path $AppLogo | Out-Null
            }

            # Validate Buttons parameter type and sanitize values
            if ($Buttons -and $Buttons.GetType() -ne [hashtable]) {
                throw "The Buttons parameter must be a hashtable."
            }

            # Insert title and text into the XML
            $textElements = $xml.GetElementsByTagName("text")
            $textElements[0].AppendChild($xml.CreateTextNode($safeTitle)) > $null
            if ($textElements.Count -gt 1) {
                $textElements[1].AppendChild($xml.CreateTextNode($safeText)) > $null
            }

            # If an AppLogo is provided, incorporate it into the notification
            if ($AppLogo) {
                $imageElements = $xml.GetElementsByTagName("image")
                if ($imageElements.Count -gt 0) {
                    # Sanitize path for XML attribute
                    $safeAppLogo = Sanitize-XmlInput -InputString $AppLogo
                    $imageElements[0].SetAttribute("src", $safeAppLogo)
                }
            }

            if ($Buttons) {
                # Adding actions (buttons) to the toast notification
                $actions = $xml.CreateElement("actions")

                # Create an input field for responses (useful for interactive notifications)
                $input = $xml.CreateElement("input")
                $input.SetAttribute("id", "userResponse")
                $input.SetAttribute("type", "text")
                $input.SetAttribute("placeHolderContent", "Type a response")
                $actions.AppendChild($input) > $null

                # Iterate over provided buttons and add them to the notification
                foreach ($buttonText in $Buttons.Keys) {
                    $button = $xml.CreateElement("action")
                    # Sanitize button text and arguments
                    $safeButtonText = Sanitize-XmlInput -InputString $buttonText
                    $safeButtonArgs = Sanitize-XmlInput -InputString $Buttons[$buttonText]

                    $button.SetAttribute("content", $safeButtonText)
                    $button.SetAttribute("arguments", $safeButtonArgs)
                    $button.SetAttribute("activationType", "foreground")
                    $actions.AppendChild($button) > $null
                }

                # Append the actions to the main toast XML
                $xml.toast.AppendChild($actions) > $null
            }

            # Prepare the XML for the toast notification
            $serializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
            $serializedXml.LoadXml($xml.OuterXml)

            # Create and show the toast notification
            $toast = [Windows.UI.Notifications.ToastNotification]::new($serializedXml)
            $toast.Tag = "PowerShell"
            $toast.Group = "PowerShell"
            $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($ExpirationTime)
            $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
            $notifier.Show($toast)
        }
        catch [System.Exception] {
            $errorMessage = $_.Exception.Message
            if (-not $Silent) {
                Write-Error "Failed to show notification due to an error: $errorMessage"
            }
        }
    }
}

function Show-TemplatedNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Maintenance', 'SecurityAlert', 'SoftwareUpdate', 'RebootRequired', 'Information')]
        [string]$Template,
        [Parameter(Mandatory=$true)]
        [hashtable]$Variables,
        [string]$AppLogo
    )

    $templateData = $notificationTemplates[$Template]

    if (-not $templateData) {
        Write-Error "Template '$Template' not found"
        return
    }

    $body = $templateData.Body -f $Variables.Values

    $params = @{
        ToastTitle = $templateData.Title
        ToastText = $body
        Buttons = $templateData.Buttons
    }

    if ($AppLogo) {
        $params.AppLogo = $AppLogo
    }

    Write-ScriptLog -Level Info -Message "Sending templated notification: $Template"

    Show-Notification @params
}

function Queue-Notification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$NotificationParams,
        [DateTime]$ScheduledTime,
        [string]$QueueID = [Guid]::NewGuid().ToString()
    )

    $queuedItem = [PSCustomObject]@{
        QueueID = $QueueID
        Params = $NotificationParams
        ScheduledTime = $ScheduledTime
        Status = 'Queued'
        Attempts = 0
        CreatedAt = Get-Date
    }

    $notificationQueue += $queuedItem
    $notificationQueue | Export-Clixml "$env:TEMP\NotificationQueue.xml" -Force

    Write-ScriptLog -Level Info -Message "Queued notification $QueueID for $ScheduledTime"

    return $QueueID
}

function Process-NotificationQueue {
    [CmdletBinding()]
    param(
        [int]$ProcessingIntervalSeconds = 60,
        [switch]$Once
    )

    Write-ScriptLog -Level Info -Message "Starting notification queue processor"

    do {
        $now = Get-Date
        $processedCount = 0

        foreach ($notif in @($notificationQueue)) {
            if ($now -ge $notif.ScheduledTime -and $notif.Status -eq 'Queued') {
                try {
                    Write-ScriptLog -Level Info -Message "Processing queued notification: $($notif.QueueID)"

                    Show-Notification @notif.Params
                    $notif.Status = 'Sent'
                    $notif.SentAt = Get-Date
                    $processedCount++
                }
                catch {
                    $notif.Attempts++

                    if ($notif.Attempts -ge 3) {
                        $notif.Status = 'Failed'
                        Write-ScriptLog -Level Error -Message "Notification $($notif.QueueID) failed after 3 attempts: $_"
                    } else {
                        Write-ScriptLog -Level Warning -Message "Notification $($notif.QueueID) failed, retrying... (attempt $($notif.Attempts))"
                    }
                }
            }
        }

        $notificationQueue | Export-Clixml "$env:TEMP\NotificationQueue.xml" -Force

        if ($processedCount -gt 0) {
            Write-ScriptLog -Level Info -Message "Processed $processedCount queued notifications"
        }

        if (-not $Once -and $notificationQueue.Where({ $_.Status -eq 'Queued' }).Count -gt 0) {
            Start-Sleep -Seconds $ProcessingIntervalSeconds
        }
    } while (-not $Once -and $notificationQueue.Where({ $_.Status -eq 'Queued' }).Count -gt 0)

    Write-ScriptLog -Level Info -Message "Notification queue processing completed"
}

function Set-NotificationPreferences {
    [CmdletBinding()]
    param(
        [bool]$AllowNotifications = $true,
        [ValidateSet('None', 'Maintenance', 'Security', 'All')]
        [string]$NotificationLevel = 'All',
        [bool]$QuietHours = $true,
        [TimeSpan]$QuietStart = "18:00",
        [TimeSpan]$QuietEnd = "08:00"
    )

    $preferences = @{
        AllowNotifications = $AllowNotifications
        NotificationLevel = $NotificationLevel
        QuietHours = $QuietHours
        QuietStart = $QuietStart
        QuietEnd = $QuietEnd
    }

    $preferences | Export-Clixml "$env:APPDATA\NotificationPreferences.xml" -Force

    Set-ScriptConfiguration -Key "Notifications.AllowNotifications" -Value $AllowNotifications
    Set-ScriptConfiguration -Key "Notifications.NotificationLevel" -Value $NotificationLevel
    Set-ScriptConfiguration -Key "Notifications.QuietHours" -Value $QuietHours
    Set-ScriptConfiguration -Key "Notifications.QuietStart" -Value $QuietStart.ToString()
    Set-ScriptConfiguration -Key "Notifications.QuietEnd" -Value $QuietEnd.ToString()

    Write-ScriptLog -Level Info -Message "Notification preferences updated"

    return $preferences
}

function Test-ShouldSendNotification {
    [CmdletBinding()]
    param(
        [ValidateSet('Maintenance', 'Security', 'SoftwareUpdate', 'RebootRequired', 'Information')]
        [string]$NotificationType = 'Information'
    )

    $config = Get-ScriptConfiguration
    $allowNotifications = $config.Notifications.AllowNotifications

    if (-not $allowNotifications) {
        Write-ScriptLog -Level Debug -Message "Notifications disabled, skipping"
        return $false
    }

    $preferences = if (Test-Path "$env:APPDATA\NotificationPreferences.xml") {
        Import-Clixml "$env:APPDATA\NotificationPreferences.xml"
    } else {
        $config.Notifications
    }

    $now = Get-Date
    $currentTime = $now.TimeOfDay

    if ($preferences.QuietHours) {
        if ($currentTime -gt $preferences.QuietStart -and $currentTime -lt $preferences.QuietEnd) {
            Write-ScriptLog -Level Debug -Message "Quiet hours active, skipping notification"
            return $false
        }
    }

    switch ($preferences.NotificationLevel) {
        'None' {
            Write-ScriptLog -Level Debug -Message "Notification level set to None, skipping"
            return $false
        }
        'Security' {
            return $NotificationType -eq 'SecurityAlert'
        }
        'Maintenance' {
            return $NotificationType -in @('SecurityAlert', 'RebootRequired', 'Maintenance')
        }
        'All' {
            return $true
        }
        default {
            return $true
        }
    }
}

function Get-NotificationTemplates {
    [CmdletBinding()]
    param()

    return $notificationTemplates.Keys | ForEach-Object {
        [PSCustomObject]@{
            Name = $_
            Title = $notificationTemplates[$_].Title
            Buttons = ($notificationTemplates[$_].Buttons.Keys -join ', ')
        }
    }
}

function Track-NotificationResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$NotificationID,
        [Parameter(Mandatory=$true)]
        [string]$ActionTaken,
        [string]$UserID = $env:USERNAME
    )

    $response = [PSCustomObject]@{
        NotificationID = $NotificationID
        ActionTaken = $ActionTaken
        UserID = $UserID
        Timestamp = Get-Date
        ComputerName = $env:COMPUTERNAME
    }

    $responsePath = "$env:TEMP\NotificationResponses.csv"

    if (-not (Test-Path $responsePath)) {
        $response | Export-Csv -Path $responsePath -NoTypeInformation
    } else {
        $response | Export-Csv -Path $responsePath -Append -NoTypeInformation
    }

    Write-ScriptLog -Level Info -Message "Notification response tracked: $NotificationID - $ActionTaken"
}

function Get-NotificationHistory {
    [CmdletBinding()]
    param(
        [DateTime]$StartDate = (Get-Date).AddDays(-7),
        [DateTime]$EndDate = Get-Date
    )

    $responsePath = "$env:TEMP\NotificationResponses.csv"

    if (-not (Test-Path $responsePath)) {
        return @()
    }

    $history = Import-Csv $responsePath | Where-Object {
        $timestamp = [DateTime]$_.Timestamp
        $timestamp -ge $StartDate -and $timestamp -le $EndDate
    }

    return $history
}

function Schedule-RecurringNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,
        [Parameter(Mandatory=$true)]
        [hashtable]$Variables,
        [ValidateSet('Daily', 'Weekly', 'Monthly')]
        [string]$Frequency,
        [TimeSpan]$Time = "09:00",
        [DayOfWeek]$DayOfWeek = 'Monday',
        [int]$DayOfMonth = 1
    )

    $taskName = "RecurringNotification_$Template"
    $scriptPath = $PSCommandPath

    $trigger = switch ($Frequency) {
        'Daily' {
            New-ScheduledTaskTrigger -Daily -At $Time
        }
        'Weekly' {
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $Time
        }
        'Monthly' {
            New-ScheduledTaskTrigger -Monthly -DaysOfMonth $DayOfMonth -At $Time
        }
    }

    $variablesJson = $Variables | ConvertTo-Json -Compress

    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -Template `"$Template`" -VariablesJson `"$variablesJson`""

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries

    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -Force | Out-Null

    Write-ScriptLog -Level Info -Message "Scheduled recurring notification: $Template ($Frequency)"

    return $taskName
}