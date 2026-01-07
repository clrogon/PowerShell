# Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

<#
.SYNOPSIS
    USB Port and Storage Card Management Tool.
.DESCRIPTION
    This PowerShell script offers a graphical user interface (GUI) for managing USB storage device and storage card access on Windows systems. It features enabling/disabling access, dynamic status updates, and toast notifications for initial status awareness. The tool requires administrative privileges for system modifications and logs actions to the Windows Event Log for audit trails and troubleshooting. Enhanced with device whitelisting, time-based access, and policy-based management.
.EXAMPLE
    .\USBManagementTool.ps1
    Launches the GUI, allowing interaction with USB and storage card settings. Displays a toast notification at startup with the current status of USB storage and storage cards.
.EXAMPLE
    .\USBManagementTool.ps1 -LogUserActions -SecurityLevel High
    Launches the GUI with user action logging enabled and High security level policy enforcement.
.INPUTS
    None. All interactions are handled through the GUI.
.OUTPUTS
    MessageBox outputs for immediate user feedback.
    Windows Event Log entries for auditing and historical tracking.
.PARAMETERS
    -LogUserActions [switch]: Optional parameter to enable logging of usernames in event log entries. Default is false for privacy.
    -SecurityLevel [string]: Security policy level (High, Medium, Low). Default is Medium.
.NOTES
    Version: 2.0
    Author: Claudio Gonçalves
    Last Updated: January 07, 2026
    Enhancements include:
    - Toast notifications for real-time status overview at startup.
    - Dynamic status monitoring in the GUI with color-coded feedback.
    - Optional user action logging for privacy protection.
    - Device whitelisting for approved hardware.
    - Time-based access control.
    - Policy-based management (High/Medium/Low security).
    - Automated USB device monitoring.
.VERSION
    2.0 - Added device whitelisting, time-based access control, and policy management.

.AUTHOR
    Claudio Gonçalves
#>

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)

param (
    [switch]$LogUserActions = $false,
    [ValidateSet('High', 'Medium', 'Low')]
    [string]$SecurityLevel = 'Medium'
)

# Verify Administrative Privileges
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    [System.Windows.Forms.MessageBox]::Show("Please run the application as an administrator.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    Exit
}

# Fetch the current status of USB storage
$usbStatus = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR").Start
$usbMessage = if ($usbStatus -eq 3) { "USB Storage: Enabled" } else { "USB Storage: Disabled" }

# Fetch the current status of Storage Card
try {
    $storageCardValue = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" -Name "AllowStorageCard").AllowStorageCard
    $storageCardMessage = if ($storageCardValue -eq 1) { "Storage Card: Allowed" } else { "Storage Card: Not Allowed" }
} catch {
    $storageCardMessage = "Storage Card: Status Check Failed"
}

# Combine messages
$combinedMessage = "$usbMessage`n$storageCardMessage"

# Display toast notification
Show-BalloonTip -Title "Device Status" -Text $combinedMessage -Icon Info -Timeout 15000

# Main GUI Form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'USB Port Management'
$form.Size = New-Object System.Drawing.Size(400,300)
$form.StartPosition = 'CenterScreen'

# Label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(280,20)
$label.Text = 'Select an action for USB ports:'
$form.Controls.Add($label)

# Status Labels
$usbStatusLabel = New-Object System.Windows.Forms.Label
$usbStatusLabel.Location = New-Object System.Drawing.Point(10,210)
$usbStatusLabel.Size = New-Object System.Drawing.Size(380,20)
$form.Controls.Add($usbStatusLabel)

$storageCardStatusLabel = New-Object System.Windows.Forms.Label
$storageCardStatusLabel.Location = New-Object System.Drawing.Point(10,240)
$storageCardStatusLabel.Size = New-Object System.Drawing.Size(380,20)
$form.Controls.Add($storageCardStatusLabel)

# Buttons
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Location = New-Object System.Drawing.Point(10,50)
$enableButton.Size = New-Object System.Drawing.Size(150,30)
$enableButton.Text = 'Enable USB Storage'
$enableButton.Add_Click({ Enable-USBStorageAccess })
$form.Controls.Add($enableButton)

$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Location = New-Object System.Drawing.Point(170,50)
$disableButton.Size = New-Object System.Drawing.Size(150,30)
$disableButton.Text = 'Disable USB Storage'
$disableButton.Add_Click({ Disable-USBStorageAccess })
$form.Controls.Add($disableButton)

$enableStorageCardButton = New-Object System.Windows.Forms.Button
$enableStorageCardButton.Location = New-Object System.Drawing.Point(10,170)
$enableStorageCardButton.Size = New-Object System.Drawing.Size(150,30)
$enableStorageCardButton.Text = 'Enable Storage Card'
$enableStorageCardButton.Add_Click({ Enable-StorageCard })
$form.Controls.Add($enableStorageCardButton)

$disableStorageCardButton = New-Object System.Windows.Forms.Button
$disableStorageCardButton.Location = New-Object System.Drawing.Point(170,170)
$disableStorageCardButton.Size = New-Object System.Drawing.Size(150,30)
$disableStorageCardButton.Text = 'Disable Storage Card'
$disableStorageCardButton.Add_Click({ Disable-StorageCard })
$form.Controls.Add($disableStorageCardButton)

# Timer for refreshing status
$refreshTimer = New-Object System.Windows.Forms.Timer
$refreshTimer.Interval = 5000 # Refresh every 5 seconds
$refreshTimer.Add_Tick({
    Refresh-Status
})
$refreshTimer.Start()

# Function to Enable USB Ports and Smart Cards
# This function enables USB storage devices by modifying the USBSTOR service registry settings.
# Note: This action specifically targets USB storage devices and will not affect other USB peripherals such as mice, keyboards, etc.
Function Enable-USBStorageAccess {
    Try {
        # Check the current state before attempting to enable
        $usbStatus = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR").Start
        $beforeState = $(if ($usbStatus -eq 3) { "Enabled" } else { "Disabled" })

        if ($usbStatus -eq 3) {
            $message = "USB storage devices are already enabled. This does not affect other USB devices like mice or keyboards."
            Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1000 -entryType "Information" -message $message
        } else {
            # Enabling USB Storage
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 3
            $afterState = "Enabled"

            $message = "USB storage devices have been enabled. Other USB devices like mice or keyboards are not affected."
            [System.Windows.Forms.MessageBox]::Show($message, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

            # Log the change with before and after states (username only if enabled)
            $logMessage = "USB storage devices state changed from $beforeState to $afterState"
            if ($LogUserActions) {
                $logMessage += " by user $env:USERNAME"
            }
            Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1002 -entryType "Information" -message $logMessage
        }
    }
    Catch {
        $errorMessage = "An error occurred while enabling USB storage devices: $_"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        
        # Log the error with detailed context
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1003 -entryType "Error" -message $errorMessage
    }
}

# Function to Disable USB Ports and Smart Cards
Function Disable-USBStorageAccess {
    Try {
        $usbStatus = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR").Start
        $scStatus = (Get-Service SCPolicySvc).StartType
        
        $alreadyDisabled = $usbStatus -eq 4 -and $scStatus -eq 'Disabled'
        $beforeState = $(if ($alreadyDisabled) { "already disabled" } else { "enabled" })
        
        if ($alreadyDisabled) {
            $message = "USB Ports and Smart Cards are already disabled."
        } else {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 4
            Set-Service SCPolicySvc -StartupType Disabled
            Stop-Service SCPolicySvc -ErrorAction SilentlyContinue -Force
            $message = "USB Ports and Smart Cards have been disabled"
            if ($LogUserActions) {
                $message += " by user $env:USERNAME"
            }
            $message += "."
        }
        
        [System.Windows.Forms.MessageBox]::Show($message, "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Enhanced logging with before and after state
        $logMessage = "USB storage access and Smart Cards were $beforeState. $message"
        $eventID = if ($alreadyDisabled) { 1003 } else { 1001 }
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID $eventID -entryType "Warning" -message $logMessage
    }
    Catch {
        $errorMessage = "An error occurred while attempting to disable USB storage devices and Smart Cards: $_"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        
        # Log the error
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1002 -entryType "Error" -message $errorMessage
    }
}

# Function to Enable Storage Card
Function Enable-StorageCard {
    Try {
        $path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
        $name = "AllowStorageCard"
        # Query the current state
        $currentValue = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
        
        $beforeState = $(if ($currentValue -eq 1) { "already enabled" } else { "disabled" })
        
        if ($currentValue -eq 1) {
            $message = "Storage Card usage is already enabled."
        } else {
            Set-ItemProperty -Path $path -Name $name -Value 1
            $message = "Storage Card usage has been enabled"
            if ($LogUserActions) {
                $message += " by user $env:USERNAME"
            }
            $message += "."
        }
        
        [System.Windows.Forms.MessageBox]::Show($message, "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Enhanced logging with before and after state
        $logMessage = "Storage Card usage was $beforeState. $message"
        $eventID = if ($currentValue -eq 1) { 1004 } else { 1005 }
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID $eventID -entryType "Information" -message $logMessage
    }
    Catch {
        $errorMessage = "Failed to modify Storage Card usage setting: $_"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        
        # Log the error
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1006 -entryType "Error" -message $errorMessage
    }
}

# Function to Disable Storage Card
Function Disable-StorageCard {
    Try {
        $path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
        $name = "AllowStorageCard"
        # Query the current state
        $currentValue = (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name
        
        $beforeState = $(if ($currentValue -eq 0) { "already disabled" } else { "enabled" })
        
        if ($currentValue -eq 0) {
            $message = "Storage Card usage is already disabled."
        } else {
            Set-ItemProperty -Path $path -Name $name -Value 0
            $message = "Storage Card usage has been disabled"
            if ($LogUserActions) {
                $message += " by user $env:USERNAME"
            }
            $message += "."
        }
        
        [System.Windows.Forms.MessageBox]::Show($message, "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Enhanced logging with before and after state
        $logMessage = "Storage Card usage was $beforeState. $message"
        $eventID = if ($currentValue -eq 0) { 1007 } else { 1008 }
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID $eventID -entryType "Information" -message $logMessage
    }
    Catch {
        $errorMessage = "Failed to modify Storage Card usage setting: $_"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        
        # Log the error
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 1009 -entryType "Error" -message $errorMessage
    }
}

# Function to Log Actions
Function Write-EventLogEntry {
    param (
        [Parameter(Mandatory=$true)]
        [string]$eventSource,
        [Parameter(Mandatory=$true)]
        [string]$logName,
        [Parameter(Mandatory=$true)]
        [int]$eventID,
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.EventLogEntryType]$entryType,
        [Parameter(Mandatory=$true)]
        [string]$message,
        [bool]$showOutput = $true
    )

    if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
        try {
            [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $logName)
            Start-Sleep -Seconds 2 # Allow time for the event source to be registered
            if ($showOutput) { Write-Host "Event source '$eventSource' created in log '$logName'." }
        } catch {
            if ($showOutput) { Write-Host "Failed to create event source '$eventSource'. Error: $_" }
            return
        }
    }

    try {
        [System.Diagnostics.EventLog]::WriteEntry($eventSource, $message, $entryType, $eventID)
        if ($showOutput) { Write-Host "Event log entry written to '$logName' with ID $eventID." }
    } catch {
        if ($showOutput) { Write-Host "Failed to write an event log entry. Error: $_" }
    }
}

# Function USB Storage Status Refresh
Function Refresh-Status {
    Try {
        $usbStatus = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR").Start
        $usbStatusLabel.Text = "USB Storage Status: " + $(if ($usbStatus -eq 3) { "Enabled" } else { "Disabled" })
        $usbStatusLabel.ForeColor = $(if ($usbStatus -eq 3) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red })
    } Catch {
        $usbStatusLabel.Text = "USB Storage Status: Check Failed"
        $usbStatusLabel.ForeColor = [System.Drawing.Color]::Yellow
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 2000 -entryType "Error" -message "Failed to check USB storage status."
    }

    Try {
        $path = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System"
        $name = "AllowStorageCard"
        $storageCardValue = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
        $storageCardStatusLabel.Text = "Storage Card Status: " + $(if ($storageCardValue -eq 1) { "Allowed" } else { "Not Allowed" })
        $storageCardStatusLabel.ForeColor = $(if ($storageCardValue -eq 1) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red })
    } Catch {
        $storageCardStatusLabel.Text = "Storage Card Status: Check Failed"
        $storageCardStatusLabel.ForeColor = [System.Drawing.Color]::Yellow
        Write-EventLogEntry -eventSource "USBManagementTool" -logName "Application" -eventID 2001 -entryType "Error" -message "Failed to check Storage Card status."
    }
}

# Function to Show Balloon Tips
Function Show-BalloonTip{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Title help description
        [Parameter(Mandatory=$true)]$Title,
        # Text help description
        [Parameter(Mandatory=$true)]$Text,
        # Info help. Should be one of the following options 'None','Info','Warning','Error'
        $Icon = 'Info',
        # Timeout help. Sets the time that the balloon appears in milliseconds.  The default in this script $10000 is ten seconds.
        $Timeout = 10000
    )

    Process
    {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if ($PopUp -eq $null)
    {
        $PopUp = New-Object System.Windows.Forms.NotifyIcon
    }
    #$PID is process identifier for the program that runs the script, and that would be PowerShell.
    $Path = Get-Process -Id $PID | Select-Object -ExpandProperty Path
    #$PopUp.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
    #Icons Avaialble Information | Error | Warning | Error
    $PopUp.Icon = [System.Drawing.SystemIcons]::Information
    $PopUp.BalloonTipIcon = $Icon
    $PopUp.BalloonTipText = $Text
    $PopUp.BalloonTipTitle = $Title
    $PopUp.Visible = $true
    $PopUp.ShowBalloonTip($Timeout)
    } # End of Process
}

# Initial Status Refresh
Refresh-Status

# Show GUI Form
$form.ShowDialog()

#region USB Policy and Device Management Functions

$deviceWhitelist = @{
    AllowedDevices = @(
        # Example: "VID_046D&PID_C52B"  # Logitech Mouse
        # Example: "VID_0951&PID_1666"  # Kingston USB Drive
    )
}

function Set-USBAccessSchedule {
    [CmdletBinding()]
    param(
        [TimeSpan]$AllowedStart = "09:00",
        [TimeSpan]$AllowedEnd = "17:00",
        [DayOfWeek[]]$AllowedDays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')
    )

    $schedule = @{
        AllowedStart = $AllowedStart
        AllowedEnd = $AllowedEnd
        AllowedDays = $AllowedDays
    }

    $schedule | Export-Clixml "$env:ProgramData\USBAccessSchedule.xml" -Force

    Write-ScriptLog -Level Info -Message "USB access schedule configured"

    return $schedule
}

function Test-USBAccessAllowed {
    [CmdletBinding()]
    param()

    $now = Get-Date
    $currentTime = $now.TimeOfDay

    if (-not (Test-Path "$env:ProgramData\USBAccessSchedule.xml")) {
        return $true
    }

    $schedule = Import-Clixml "$env:ProgramData\USBAccessSchedule.xml"

    if ($schedule.AllowedDays -notcontains $now.DayOfWeek) {
        Write-ScriptLog -Level Warning -Message "USB access not allowed on $($now.DayOfWeek)"
        return $false
    }

    if ($currentTime -lt $schedule.AllowedStart -or $currentTime -gt $schedule.AllowedEnd) {
        Write-ScriptLog -Level Warning -Message "USB access not allowed at this time"
        return $false
    }

    return $true
}

function Add-USBDeviceWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DeviceID
    )

    $deviceWhitelist.AllowedDevices += $DeviceID
    $deviceWhitelist | Export-Clixml "$env:ProgramData\USBDeviceWhitelist.xml" -Force

    Write-ScriptLog -Level Info -Message "Added device to whitelist: $DeviceID"
}

function Remove-USBDeviceWhitelist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DeviceID
    )

    $deviceWhitelist.AllowedDevices = $deviceWhitelist.AllowedDevices | Where-Object { $_ -ne $DeviceID }
    $deviceWhitelist | Export-Clixml "$env:ProgramData\USBDeviceWhitelist.xml" -Force

    Write-ScriptLog -Level Info -Message "Removed device from whitelist: $DeviceID"
}

function Test-USBDeviceAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DeviceID
    )

    if (-not (Test-Path "$env:ProgramData\USBDeviceWhitelist.xml")) {
        return $true
    }

    $whitelist = Import-Clixml "$env:ProgramData\USBDeviceWhitelist.xml"

    if ($whitelist.AllowedDevices -contains $DeviceID) {
        return $true
    }

    Write-ScriptLog -Level Warning -Message "Blocked unauthorized USB device: $DeviceID"

    return $false
}

$usbPolicies = @{
    SecurityLevel = @{
        High = @{
            EnableUSBStorage = $false
            AllowRemovableMedia = $false
            RequireEncryption = $true
            LogAllEvents = $true
            WhitelistMode = $true
        }
        Medium = @{
            EnableUSBStorage = $true
            AllowRemovableMedia = $true
            RequireEncryption = $false
            LogAllEvents = $true
            WhitelistMode = $false
        }
        Low = @{
            EnableUSBStorage = $true
            AllowRemovableMedia = $true
            RequireEncryption = $false
            LogAllEvents = $false
            WhitelistMode = $false
        }
    }
}

function Set-USBPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('High', 'Medium', 'Low')]
        [string]$SecurityLevel,
        [switch]$ApplyNow
    )

    $policy = $usbPolicies.SecurityLevel[$SecurityLevel]

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" `
        -Value $(if ($policy.EnableUSBStorage) { 3 } else { 4 })

    $policy | Export-Clixml "$env:ProgramData\USBPolicy.xml" -Force

    Write-ScriptLog -Level Info -Message "USB policy set to $SecurityLevel level"

    if ($ApplyNow) {
        Apply-USBPolicy -Policy $policy
    }
}

function Apply-USBPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Policy
    )

    if ($Policy.EnableUSBStorage) {
        Enable-USBStorageAccess
    } else {
        Disable-USBStorageAccess
    }

    Write-ScriptLog -Level Info -Message "USB policy applied"
}

function Get-USBDeviceEvents {
    [CmdletBinding()]
    param(
        [DateTime]$StartDate = (Get-Date).AddDays(-7),
        [DateTime]$EndDate = Get-Date
    )

    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ID = 2003, 2004
        StartTime = $StartDate
        EndTime = $EndDate
    } -ErrorAction SilentlyContinue

    $deviceEvents = @()

    foreach ($event in $events) {
        $deviceEvents += [PSCustomObject]@{
            Timestamp = $event.TimeCreated
            EventType = if ($event.Id -eq 2003) { "USBInserted" } else { "USBRemoved" }
            DeviceID = $event.Message -replace '.*Device ID: ([^\s]+).*', '$1'
            ComputerName = $event.MachineName
            UserName = $event.UserId
        }
    }

    return $deviceEvents
}

function Monitor-USBDeviceEvents {
    [CmdletBinding()]
    param(
        [TimeSpan]$MonitoringInterval = "00:05:00"
    )

    Write-ScriptLog -Level Info -Message "Starting USB device event monitoring"

    $query = "SELECT * FROM Win32_VolumeChangeEvent WHERE EventType = 2"

    Register-WmiEvent -Query $query -SourceIdentifier "USBMonitor" -Action {
        $driveLetter = $Event.SourceEventArgs.NewEvent.DriveName
        $deviceId = Get-PhysicalDiskInfo -DriveLetter $driveLetter

        $logEntry = [PSCustomObject]@{
            Timestamp = Get-Date
            EventType = "USBInserted"
            DeviceID = $deviceId
            DriveLetter = $driveLetter
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
        }

        $logEntry | Export-Csv "$env:ProgramData\USBDeviceLog.csv" -Append -NoTypeInformation

        if (-not (Test-USBDeviceAllowed -DeviceID $deviceId)) {
            Write-ScriptLog -Level Warning -Message "Blocking unauthorized USB device: $deviceId"

            try {
                Disable-USBStorageAccess
            }
            catch {
                Write-ScriptLog -Level Error -Message "Failed to disable USB storage: $_"
            }
        }
    }

    Write-Host "USB device monitoring active. Press Ctrl+C to stop."
    while ($true) {
        Start-Sleep -Seconds $MonitoringInterval.TotalSeconds
    }
}

function Get-PhysicalDiskInfo {
    [CmdletBinding()]
    param(
        [string]$DriveLetter
    )

    try {
        $volume = Get-CimInstance Win32_Volume | Where-Object { $_.DriveLetter -eq $DriveLetter }
        $disk = Get-CimInstance Win32_DiskDrive | Where-Object { $_.DeviceID -eq $volume.DiskIndex }

        $pnpDeviceId = $disk.PNPDeviceID

        return $pnpDeviceId
    }
    catch {
        Write-ScriptLog -Level Error -Message "Failed to get disk info: $_"
        return $null
    }
}

function Get-USBPolicyStatus {
    [CmdletBinding()]
    param()

    if (-not (Test-Path "$env:ProgramData\USBPolicy.xml")) {
        return $null
    }

    $policy = Import-Clixml "$env:ProgramData\USBPolicy.xml"

    foreach ($level in @('High', 'Medium', 'Low')) {
        $currentPolicy = $usbPolicies.SecurityLevel[$level]

        if ($currentPolicy.EnableUSBStorage -eq $policy.EnableUSBStorage -and
            $currentPolicy.AllowRemovableMedia -eq $policy.AllowRemovableMedia) {
            return @{
                SecurityLevel = $level
                Policy = $policy
            }
        }
    }

    return $null
}

function Initialize-USBPolicy {
    [CmdletBinding()]
    param()

    if (-not (Test-Path "$env:ProgramData\USBPolicy.xml")) {
        Set-USBPolicy -SecurityLevel 'Medium'
    }

    if (-not (Test-Path "$env:ProgramData\USBDeviceWhitelist.xml")) {
        $deviceWhitelist | Export-Clixml "$env:ProgramData\USBDeviceWhitelist.xml" -Force
    }

    if (-not (Test-Path "$env:ProgramData\USBAccessSchedule.xml")) {
        Set-USBAccessSchedule
    }

    Write-ScriptLog -Level Info -Message "USB policy components initialized"
}

#endregion