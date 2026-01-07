<#
.SYNOPSIS
A PowerShell script that finds and logs empty directories.
.DESCRIPTION
This script recursively scans a directory for empty subdirectories. It logs the paths of empty directories and any errors encountered during the scan. Enhanced with smart filtering, recursive cleanup, and owner analysis.
.PARAMETER FolderPath
The directory path to be scanned for empty directories. This parameter is mandatory and should be an existing directory.
.PARAMETER LogFile
The file path to which errors will be logged. Default is "C:\TSTFolder\Logs\EmptyFolders_log.log".
.PARAMETER EmptyFoldersLog
The file path to which empty directories will be logged. Default is "C:\TSTFolder\Logs\EmptyFolders_report.log".
.PARAMETER LogLevel
Controls the level of verbosity in logging. Accepted values: 'Error', 'Verbose'. Default: 'Error'.
.EXAMPLE
Find-EmptyFolders -FolderPath "C:\TestDirectory" -SmartDetection -RecursiveCleanup
.INPUTS
String. Accepts string inputs for FolderPath, LogFile, EmptyFoldersLog, LogLevel.
.OUTPUTS
None. This script does not return any output to the console, but it does write to the specified log files.
.NOTES
This script should be used with caution and tested thoroughly on non-production data before real use. It uses recursion to scan the directory, which could be slow on directories with a large number of subdirectories.
.VERSION
2.0 Enhanced with smart detection and recursive cleanup
.AUTHOR
Concept by Cláudio Gonçalves
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)
Initialize-Logging -Component "FindEmptyFolders"

function Find-EmptyFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$FolderPath,

        [string]$LogFile = "C:\TSTFolder\Logs\EmptyFolders_log.log",

        [string]$EmptyFoldersLog = "C:\TSTFolder\Logs\EmptyFolders_report.log",

        [ValidateSet('Error', 'Verbose')]
        [string]$LogLevel = 'Error'
    )

    $ErrorActionPreference = if ($LogLevel -eq 'Error') { 'Stop' } else { 'Continue' }

    if (Test-Path -Path $EmptyFoldersLog) {
        $LastWriteTime = (Get-Item $EmptyFoldersLog).LastWriteTime.ToString('yyyyMMdd_HHmmss')
        Rename-Item -Path $EmptyFoldersLog -NewName ("{0}_{1}.log" -f $EmptyFoldersLog.TrimEnd('.log'), $LastWriteTime)
    }

    $directories = Get-ChildItem -Path $FolderPath -Recurse -Directory -ErrorAction SilentlyContinue

    $i = 0
    foreach ($dir in $directories) {
        $i++
        Write-Progress -Activity "Scanning directories" -Status "$i of $($directories.Count)" -PercentComplete ($i / $directories.Count * 100)

        try {
            $files = Get-ChildItem -Path $dir.FullName -File -Recurse -ErrorAction SilentlyContinue
            if (!$files) {
                $dir.FullName | Out-File -FilePath $EmptyFoldersLog -Append
            }
        }
        catch {
            $errorMessage = "Failed to access $($dir.FullName): $($_.Exception.Message)"
            Write-Error $errorMessage
            $errorMessage | Out-File -FilePath $LogFile -Append
        }
    }
}

#region Enhanced Functions

function Find-EmptyFoldersSmart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        [switch]$IncludeSystemFiles,
        [switch]$IncludeHiddenFiles,
        [int]$MinAgeDays = 0,
        [string]$OutputPath = "empty_folders.csv"
    )

    $emptyFolders = @()
    $directories = Get-ChildItem -Path $FolderPath -Recurse -Directory -Force

    foreach ($dir in $directories) {
        Write-Progress -Activity "Scanning directories" -Status "Processing: $($dir.FullName)" `
            -PercentComplete (($directories.IndexOf($dir) + 1) / $directories.Count * 100)

        # Get files with filtering
        $files = Get-ChildItem -Path $dir.FullName -File -Force

        if (-not $IncludeHiddenFiles) {
            $files = $files | Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) }
        }

        if (-not $IncludeSystemFiles) {
            $files = $files | Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::System) }
        }

        # Check minimum age
        if ($MinAgeDays -gt 0) {
            $files = $files | Where-Object { (Get-Date) - $_.LastWriteTime -gt [TimeSpan]::FromDays($MinAgeDays) }
        }

        if ($files.Count -eq 0) {
            $emptyFolders += [PSCustomObject]@{
                Path = $dir.FullName
                Created = $dir.CreationTime
                LastModified = $dir.LastWriteTime
                AgeDays = [math]::Round(((Get-Date) - $dir.LastWriteTime).TotalDays, 1)
                Depth = ($dir.FullName -split '\\').Count
            }
        }
    }

    $emptyFolders | Export-Csv -Path $OutputPath -NoTypeInformation
    Write-Host "Found $($emptyFolders.Count) empty folders. Report: $OutputPath"

    return $emptyFolders
}

function Remove-EmptyFolders {
    [CmdletBinding()]
    param(
        [string]$FolderPath,
        [switch]$WhatIf,
        [switch]$Force,
        [string]$BackupLocation,
        [string[]]$ExcludedPaths
    )

    $emptyFolders = Find-EmptyFoldersSmart -FolderPath $FolderPath
    $removedCount = 0
    $skippedCount = 0

    foreach ($folder in $emptyFolders) {
        # Check exclusions
        $excluded = $false
        foreach ($exclusion in $ExcludedPaths) {
            if ($folder.Path -like "*$exclusion*") {
                $excluded = $true
                break
            }
        }

        if ($excluded) {
            $skippedCount++
            Write-Warning "Skipping excluded folder: $($folder.Path)"
            continue
        }

        # Backup if specified
        if ($BackupLocation) {
            $backupPath = Join-Path $BackupLocation ($folder.Path -replace [regex]::Escape($FolderPath), "")
            try {
                $null = New-Item -ItemType Directory -Path $backupPath -Force -WhatIf:$WhatIf
            }
            catch {
                Write-Warning "Could not create backup: $_"
            }
        }

        # Remove folder
        try {
            Remove-Item -Path $folder.Path -Force -WhatIf:$WhatIf
            $removedCount++
            Write-ScriptLog -Level Info -Message "Removed: $($folder.Path)"
        }
        catch {
            Write-ScriptLog -Level Error -Message "Failed to remove $($folder.Path): $_"
        }
    }

    Write-Host "`nCleanup Summary:"
    Write-Host "  Removed: $removedCount folders"
    Write-Host "  Skipped: $skippedCount folders"
}

function Find-DeeplyEmptyFolders {
    [CmdletBinding()]
    param(
        [string]$FolderPath,
        [switch]$RemoveAll
    )

    $changed = $true
    $totalRemoved = 0

    while ($changed) {
        $changed = $false
        $emptyFolders = Find-EmptyFoldersSmart -FolderPath $FolderPath

        if ($emptyFolders.Count -eq 0) {
            break
        }

        foreach ($folder in $emptyFolders) {
            try {
                Remove-Item -Path $folder.Path -Force
                Write-Host "Removed: $($folder.Path)"
                $changed = $true
                $totalRemoved++
            }
            catch {
                Write-Warning "Could not remove $($folder.Path)"
            }
        }
    }

    Write-Host "Total removed: $totalRemoved folders"
}

function Get-EmptyFolderOwners {
    [CmdletBinding()]
    param(
        [string]$FolderPath
    )

    $emptyFolders = Find-EmptyFoldersSmart -FolderPath $FolderPath
    $ownerStats = @{}

    foreach ($folder in $emptyFolders) {
        try {
            $acl = Get-Acl $folder.Path
            $owner = $acl.Owner

            if (-not $ownerStats.ContainsKey($owner)) {
                $ownerStats[$owner] = @{
                    Count = 0
                    TotalSize = 0
                    Folders = @()
                }
            }

            $ownerStats[$owner].Count++
            $ownerStats[$owner].Folders += $folder.Path
        }
        catch {
            Write-ScriptLog -Level Warning -Message "Could not get owner for $($folder.Path)"
        }
    }

    $ownerStats.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Owner = $_.Key
            FolderCount = $_.Value.Count
            Folders = $_.Value.Folders
        }
    } | Sort-Object FolderCount -Descending | Format-Table -AutoSize
}

function Schedule-EmptyFolderCleanup {
    [CmdletBinding()]
    param(
        [string]$FolderPath,
        [TimeSpan]$ScheduleTime = "02:00",
        [ValidateSet('Daily', 'Weekly')]
        [string]$Frequency = 'Weekly'
    )

    $scriptPath = $PSCommandPath

    $trigger = if ($Frequency -eq 'Daily') {
        New-ScheduledTaskTrigger -Daily -At $ScheduleTime
    } else {
        New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $ScheduleTime
    }

    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -FolderPath `"$FolderPath`" -RecursiveCleanup"

    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd

    Register-ScheduledTask -TaskName "EmptyFolderCleanup" -Trigger $trigger -Action $action -Settings $settings `
        -Description "Clean up empty directories in $FolderPath" -Force | Out-Null

    Write-ScriptLog -Level Info -Message "Scheduled empty folder cleanup: $Frequency at $ScheduleTime"
}

#endregion