<#
.Synopsis
   Clears Microsoft Teams cache and restarts the application.
.DESCRIPTION
   This PowerShell script improves Microsoft Teams performance by clearing specific cache folders. 
   It performs various checks like administrative rights, disk space, and network connectivity before proceeding. 
   The -Force switch allows forceful execution despite warnings such as low disk space or lack of administrative rights.
.EXAMPLE
   ClearTeamsCache
   Clears the Teams cache using the default log folder "C:\TSTFolder\Logs".
.EXAMPLE
   ClearTeamsCache -logFolder "C:\CustomLogFolder" -Force
   Forces the script to continue even if it encounters issues like low disk space, using a custom log folder.
.INPUTS
   -logFolder [string]: Specifies the folder where logs will be saved.
   -Force [switch]: Forces the script to continue even if it encounters issues like low disk space or lack of admin rights. Overrides admin and network checks.
.OUTPUTS
   Logs are saved to the specified log folder, and messages are printed to the console. An exit status is also returned.
.NOTES
   Version 1.0: Initial version of the script.
   Version 1.1: Added administrative check and disk space check.
   Version 1.2: Modularized the script into separate functions for each major task.
   Version 1.3: Added -Force switch to allow forceful execution despite warnings.
   Version 1.4: Added ClearCache function to clear Microsoft Teams cache.
   Version 1.5: Added log rotation and more specific error messages.
   Ensure you have the necessary permissions to stop processes and remove files. Running without administrative privileges may cause some tasks to fail.
   Before running the script, consider taking backup precautions for sensitive files.
.VERSION
   1.5
.AUTHOR
   Claudio Gonçalves
#>

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
