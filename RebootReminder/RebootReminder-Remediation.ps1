<#
.SYNOPSIS
    Intune Remediation Script for Reboot Reminder
.DESCRIPTION
    Displays reboot reminder notification to user when system is non-compliant
    Designed to run in user context for proper toast notifications
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,365)]
    [int]$DaysLimit = 7,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0,48)]
    [int]$HoursLimit = 5
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = "$env:TEMP\RebootReminder-Intune.log"
    "[$timestamp] [$Level] $Message" | Out-File -FilePath $logPath -Append
    Write-Host $Message
}

function Test-IsWeekend {
    return (Get-Date).DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)
}

function Test-IsWorkHours {
    $hour = (Get-Date).Hour
    return $hour -ge 8 -and $hour -lt 17
}

function Show-ToastNotification {
    param(
        [string]$Title,
        [string]$Message
    )

    try {
        # Try BurntToast first (if available)
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            Submit-BTNotification -Text $Title, $Message
            return
        }

        # Fallback to native Windows toast
        $template = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
</toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
        $notifier.Show($xml)
    }
    catch {
        Write-Log -Message "Failed to show toast: $_" -Level "ERROR"
    }
}

try {
    Write-Log -Message "Reboot Reminder Remediation started"

    # Check weekend and work hours
    if (Test-IsWeekend) {
        Write-Log -Message "Skipping: Today is weekend"
        exit 0
    }

    if (-not (Test-IsWorkHours)) {
        Write-Log -Message "Skipping: Outside work hours"
        exit 0
    }

    # Get uptime
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    $LastBoot = $OS.LastBootUpTime
    $Uptime = (Get-Date) - $LastBoot
    $UptimeDays = [math]::Round($Uptime.TotalDays, 1)

    Write-Log -Message "System uptime: $UptimeDays days"

    if ($UptimeDays -ge $DaysLimit) {
        # Check if we already showed a notification recently
        $trackingPath = "HKCU:\SOFTWARE\RebootReminder"
        $lastReminder = try {
            [DateTime](Get-ItemProperty -Path $trackingPath -Name "LastReminder" -ErrorAction SilentlyContinue).LastReminder
        } catch {
            [DateTime]::MinValue
        }

        $hoursSinceReminder = if ($lastReminder -gt [DateTime]::MinValue) {
            ((Get-Date) - $lastReminder).TotalHours
        } else {
            999
        }

        if ($hoursSinceReminder -ge 1) {
            Write-Log -Message "Displaying reboot reminder notification"

            $title = "System Reboot Required"
            $message = "Your system hasn't been rebooted in $UptimeDays days. Please restart to ensure security updates are applied."

            Show-ToastNotification -Title $title -Message $message

            # Update tracking
            if (-not (Test-Path $trackingPath)) {
                New-Item -Path $trackingPath -Force | Out-Null
            }
            Set-ItemProperty -Path $trackingPath -Name "LastReminder" -Value (Get-Date) -Force

            Write-Log -Message "Notification displayed successfully"
        } else {
            Write-Log -Message "Skipping: Notification shown less than 1 hour ago"
        }
    } else {
        Write-Log -Message "System is compliant"
    }

    exit 0
}
catch {
    Write-Log -Message "Remediation failed: $_" -Level "ERROR"
    exit 1
}
