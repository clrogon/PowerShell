<#
.Synopsis
   Clears Microsoft Teams cache and restarts the application.
.DESCRIPTION
   This PowerShell script improves Microsoft Teams performance by clearing specific cache folders.
   It performs various checks like administrative rights, disk space, and network connectivity before proceeding.
   The -Force switch allows forceful execution despite warnings such as low disk space or lack of administrative rights.
   Enhanced with remote clearing, cache analytics, and troubleshooting workflows.
.EXAMPLE
   ClearTeamsCache
   Clears the Teams cache using the default log folder "C:\TSTFolder\Logs".
.EXAMPLE
   ClearTeamsCache -logFolder "C:\CustomLogFolder" -Force
   Forces the script to continue even if it encounters issues like low disk space, using a custom log folder.
.EXAMPLE
   Clear-TeamsCacheRemote -ComputerNames @("PC-01", "PC-02") -NotifyUser
   Clears Teams cache remotely on specified computers.
.INPUTS
   -logFolder [string]: Specifies the folder where logs will be saved.
   -Force [switch]: Forces the script to continue even if it encounters issues like low disk space or lack of admin rights. Overrides admin and network checks.
.OUTPUTS
   Logs are saved to the specified log folder, and messages are printed to the console. An exit status is also returned.
.NOTES
   Version 2.0: Enhanced with remote clearing and analytics.
   Version 1.5: Added log rotation and more specific error messages.
   Ensure you have the necessary permissions to stop processes and remove files. Running without administrative privileges may cause some tasks to fail.
   Before running the script, consider taking backup precautions for sensitive files.
.VERSION
   2.0
.AUTHOR
   Claudio Gonçalves
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)
Initialize-Logging -Component "ClearTeamsCache"

function CheckAdminRights {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    return $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function CheckDiskSpace {
    $diskSpace = (Get-PSDrive C | Select-Object Free).Free / 1GB
    return ($diskSpace -ge 1)
}

function CheckNetwork {
    return (Test-Connection -ComputerName www.google.com -Count 1 -Quiet)
}

function StopTeams {
    try {
        $teamsProcess = Get-Process -Name Teams
        if ($teamsProcess) {
            Stop-Process -Name Teams -Force
            return $true
        }
    } catch {
        return $false
    }
}

function StartTeams {
    try {
        Start-Process -FilePath "$env:USERPROFILE\AppData\Local\Microsoft\Teams\Update.exe" -ArgumentList "--processStart ""Teams.exe"" --process-start-args ""--system-initiated"""
        Start-Sleep -Seconds 5
        if (Get-Process -Name Teams -ErrorAction SilentlyContinue) {
            Write-Host "MS Teams started."
            Add-Content -Path $logPath -Value "MS Teams started at $(Get-Date)"
        } else {
            Write-Warning "MS Teams failed to start."
            Add-Content -Path $logPath -Value "[ERROR] MS Teams failed to start at $(Get-Date)"
        }
    } catch [System.Exception] {
        Write-Warning "Failed to start MS Teams due to $_."
        Add-Content -Path $logPath -Value "[ERROR] Failed to start MS Teams due to $_ at $(Get-Date)"
    }
}

function ClearCache {
    try {
        $cachePaths = @(
            "$env:APPDATA\Microsoft\Teams\blob_storage",
            "$env:APPDATA\Microsoft\Teams\Cache",
            "$env:APPDATA\Microsoft\Teams\databases",
            "$env:APPDATA\Microsoft\Teams\GPUcache",
            "$env:APPDATA\Microsoft\Teams\IndexedDB",
            "$env:APPDATA\Microsoft\Teams\Local Storage",
            "$env:APPDATA\Microsoft\Teams\tmp"
        )
        
        foreach ($path in $cachePaths) {
            Remove-Item -Path $path -Recurse -Force
        }
        Write-Host "Cache cleared."
        Add-Content -Path $logPath -Value "Cache cleared at $(Get-Date)"
    } catch [System.Exception] {
        Write-Warning "Failed to clear Teams cache due to $_."
        Add-Content -Path $logPath -Value "[ERROR] Failed to clear Teams cache due to $_ at $(Get-Date)"
    }
}

function ClearTeamsCache {
    param (
        [string]$logFolder = "C:\TSTFolder\Logs",
        [switch]$Force
    )

    $logFile = "ClearMSTeamCachelog.log"
    $logPath = Join-Path $logFolder $logFile

    if ($Force) {
        Write-Warning "Force flag is set. Skipping some checks."
        Add-Content -Path $logPath -Value "[WARNING] Force flag is set. Skipping some checks at $(Get-Date)"
    }

    if (![System.IO.Path]::IsPathRooted($logFolder)) {
        Write-Warning "Invalid log folder path."
        return 1
    }

    if (!(Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory
    }

    if (!(Test-Path $logPath)) {
        New-Item -Path $logPath -ItemType File
    }

    # Log rotation logic
    $maxLogSize = 10MB
    if ((Get-Item $logPath).Length -gt $maxLogSize) {
        $backupLogPath = "$logFolder\backup_$((Get-Date).ToString('yyyyMMddHHmmss')).log"
        Copy-Item -Path $logPath -Destination $backupLogPath
        Clear-Content $logPath
        Add-Content -Path $logPath -Value "Log rotated and backed up to $backupLogPath at $(Get-Date)"
    }

    if (!(CheckAdminRights)) {
        Write-Warning "Not running with administrative privileges. Some tasks may fail."
        Add-Content -Path $logPath -Value "[WARNING] Script is not running with administrative privileges at $(Get-Date)"
    }

    if (!(CheckDiskSpace) -and !$Force) {
        Write-Warning "Exiting script due to low disk space."
        Add-Content -Path $logPath -Value "[ERROR] Exiting script due to low disk space at $(Get-Date)"
        return 3
    }

    if (!(CheckNetwork) -and !$Force) {
        Write-Warning "Exiting script due to no network."
        Add-Content -Path $logPath -Value "[ERROR] Exiting script due to no network at $(Get-Date)"
        return 4
    }

    if (!(StopTeams)) {
        Write-Warning "Failed to stop MS Teams."
        Add-Content -Path $logPath -Value "[WARNING] Failed to stop MS Teams at $(Get-Date)"
    }

    ClearCache
    StartTeams

    return 0
}

#region Enhanced Functions

function Clear-TeamsCacheRemotely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ComputerNames,
        [PSCredential]$Credential,
        [switch]$NotifyUser,
        [int]$WarningMinutes = 5
    )

    $results = @()

    foreach ($computer in $ComputerNames) {
        Write-Progress -Activity "Clearing Teams Cache" -Status "Processing: $computer" `
            -PercentComplete (($ComputerNames.IndexOf($computer) + 1) / $ComputerNames.Count * 100)

        $result = [PSCustomObject]@{
            ComputerName = $computer
            Success = $false
            Error = $null
            CacheSizeBefore = 0
            CacheSizeAfter = 0
        }

        try {
            # Notify user if specified
            if ($NotifyUser) {
                Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                    param($minutes)
                    Add-Type -AssemblyName Windows.UI.Notifications
                    $xml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>Teams Maintenance</text>
            <text>Teams will restart in $minutes minutes to clear cache. Please save your work.</text>
        </binding>
    </visual>
</toast>
"@
                    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
                    $doc.LoadXml($xml)
                    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Microsoft Teams").Show($doc)
                } -ArgumentList $WarningMinutes -ErrorAction SilentlyContinue
            }

            # Get cache size before
            $cacheSizeBefore = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                $cachePath = "$env:APPDATA\Microsoft\Teams"
                if (Test-Path $cachePath) {
                    (Get-ChildItem $cachePath -Recurse | Measure-Object -Property Length -Sum).Sum
                } else {
                    0
                }
            } -ErrorAction Stop

            $result.CacheSizeBefore = $cacheSizeBefore

            # Stop Teams
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                Get-Process -Name "Teams" -ErrorAction SilentlyContinue | Stop-Process -Force
            } -ErrorAction Stop

            # Clear cache
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                $cachePaths = @(
                    "$env:APPDATA\Microsoft\Teams\blob_storage",
                    "$env:APPDATA\Microsoft\Teams\Cache",
                    "$env:APPDATA\Microsoft\Teams\databases",
                    "$env:APPDATA\Microsoft\Teams\GPUcache",
                    "$env:APPDATA\Microsoft\Teams\IndexedDB",
                    "$env:APPDATA\Microsoft\Teams\Local Storage",
                    "$env:APPDATA\Microsoft\Teams\tmp"
                )

                foreach ($path in $cachePaths) {
                    if (Test-Path $path) {
                        Remove-Item $path -Recurse -Force
                    }
                }
            } -ErrorAction Stop

            # Start Teams
            Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                Start-Sleep -Seconds 3
                $updatePath = "$env:USERPROFILE\AppData\Local\Microsoft\Teams\Update.exe"
                if (Test-Path $updatePath) {
                    Start-Process -FilePath $updatePath `
                        -ArgumentList "--processStart `"Teams.exe`" --process-start-args `"--system-initiated`""
                }
            } -ErrorAction Stop

            # Get cache size after
            Start-Sleep -Seconds 10
            $cacheSizeAfter = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                $cachePath = "$env:APPDATA\Microsoft\Teams"
                if (Test-Path $cachePath) {
                    (Get-ChildItem $cachePath -Recurse | Measure-Object -Property Length -Sum).Sum
                } else {
                    0
                }
            } -ErrorAction SilentlyContinue

            $result.CacheSizeAfter = $cacheSizeAfter
            $result.Success = $true

            Write-ScriptLog -Level Info -Message "Teams cache cleared on $computer"
        }
        catch {
            $result.Error = $_.Exception.Message
            Write-ScriptLog -Level Error -Message "Failed to clear cache on $computer: $_"
        }

        $results += $result
    }

    return $results
}

function Get-TeamsCacheAnalytics {
    [CmdletBinding()]
    param(
        [string[]]$ComputerNames,
        [PSCredential]$Credential
    )

    $analytics = @()

    foreach ($computer in $ComputerNames) {
        try {
            $cacheInfo = Invoke-Command -ComputerName $computer -Credential $Credential -ScriptBlock {
                $cachePath = "$env:APPDATA\Microsoft\Teams"

                if (-not (Test-Path $cachePath)) {
                    return $null
                }

                $size = (Get-ChildItem $cachePath -Recurse -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum

                $folders = Get-ChildItem $cachePath -Directory -ErrorAction SilentlyContinue
                $folderSizes = @{}

                foreach ($folder in $folders) {
                    $folderSize = (Get-ChildItem $folder.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                        Measure-Object -Property Length -Sum).Sum
                    $folderSizes[$folder.Name] = $folderSize
                }

                return [PSCustomObject]@{
                    TotalSizeMB = [math]::Round($size/1MB, 2)
                    FolderCount = $folders.Count
                    FolderSizes = $folderSizes
                }
            } -ErrorAction Stop

            if ($cacheInfo) {
                $analytics += [PSCustomObject]@{
                    ComputerName = $computer
                    CacheSizeMB = $cacheInfo.TotalSizeMB
                    FolderCount = $cacheInfo.FolderCount
                    NeedsCleanup = $cacheInfo.TotalSizeMB -gt 500
                    LargestFolder = ($cacheInfo.FolderSizes.GetEnumerator() | 
                        Sort-Object Value -Descending | Select-Object -First 1).Name
                }
            }
        }
        catch {
            Write-Warning "Could not analyze $computer: $_"
        }
    }

    $analytics | Sort-Object CacheSizeMB -Descending | Format-Table -AutoSize

    # Summary
    $totalSize = ($analytics | Measure-Object CacheSizeMB -Sum).Sum
    $avgSize = ($analytics | Measure-Object CacheSizeMB -Average).Average
    $needsCleanup = ($analytics | Where-Object NeedsCleanup).Count

    Write-Host "`nAnalytics Summary:"
    Write-Host "  Computers: $($analytics.Count)"
    Write-Host "  Total Cache: $([math]::Round($totalSize/1024, 2)) GB"
    Write-Host "  Average Cache: $([math]::Round($avgSize, 2)) MB"
    Write-Host "  Needs Cleanup: $needsCleanup"

    return $analytics
}

function Schedule-TeamsMaintenance {
    [CmdletBinding()]
    param(
        [string[]]$ComputerNames,
        [TimeSpan]$MaintenanceTime = "22:00",
        [ValidateSet('Daily', 'Weekly')]
        [string]$Frequency = 'Weekly'
    )

    $scriptPath = $PSCommandPath

    foreach ($computer in $ComputerNames) {
        $trigger = if ($Frequency -eq 'Daily') {
            New-ScheduledTaskTrigger -Daily -At $MaintenanceTime
        } else {
            New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At $MaintenanceTime
        }

        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -RemoteComputer $computer"

        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries

        $taskName = "TeamsMaintenance_$computer"

        Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings `
            -ComputerName $computer -Description "Weekly Teams cache maintenance" -Force | Out-Null

        Write-ScriptLog -Level Info -Message "Scheduled Teams maintenance on $computer"
    }
}

function Invoke-TeamsTroubleshooting {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [PSCredential]$Credential
    )

    Write-Host "=== Teams Troubleshooting for $ComputerName ===`n"

    # Check if Teams is installed
    $teamsPath = "\\$computerName\c$\Users\*\AppData\Local\Microsoft\Teams\Update.exe"
    $teamsFound = Test-Path $teamsPath

    Write-Host "Teams Installed: $teamsFound"

    if (-not $teamsFound) {
        Write-Host "Teams is not installed on this computer."
        return
    }

    # Check if Teams is running
    $teamsRunning = Invoke-Command -ComputerName $computerName -Credential $Credential -ScriptBlock {
        Get-Process -Name "Teams" -ErrorAction SilentlyContinue
    }

    Write-Host "Teams Running: $($teamsRunning.Count -gt 0)"

    # Check cache size
    $cacheSize = Invoke-Command -ComputerName $computerName -Credential $Credential -ScriptBlock {
        $cachePath = "$env:APPDATA\Microsoft\Teams"
        if (Test-Path $cachePath) {
            [math]::Round((Get-ChildItem $cachePath -Recurse | Measure-Object -Property Length -Sum).Sum/1MB, 2)
        } else {
            0
        }
    } -ErrorAction SilentlyContinue

    Write-Host "Cache Size: $cacheSize MB"

    # Check for errors in logs
    $errorsFound = Invoke-Command -ComputerName $computerName -Credential $Credential -ScriptBlock {
        $logPath = "$env:APPDATA\Microsoft\Teams\logs.txt"
        if (Test-Path $logPath) {
            Select-String -Path $logPath -Pattern "error|Error|ERROR" | Measure-Object | Select-Object -ExpandProperty Count
        } else {
            0
        }
    } -ErrorAction SilentlyContinue

    Write-Host "Errors in Logs: $errorsFound"

    # Recommendations
    Write-Host "`nRecommendations:"

    if ($cacheSize -gt 500) {
        Write-Host "  - Cache size is large ($cacheSize MB). Consider clearing cache."
    }

    if ($errorsFound -gt 10) {
        Write-Host "  - Multiple errors found in logs. Check logs.txt for details."
    }

    if ($teamsRunning.Count -eq 0) {
        Write-Host "  - Teams is not running. Try starting Teams."
    }

    # Offer to clear cache
    $clearCache = Read-Host "Clear Teams cache? (Y/N)"
    if ($clearCache -eq 'Y') {
        Clear-TeamsCacheRemotely -ComputerNames $computerName -Credential $Credential -NotifyUser -WarningMinutes 5
    }
}

#endregion