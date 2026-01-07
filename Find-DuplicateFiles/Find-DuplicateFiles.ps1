<#
.SYNOPSIS
This script identifies duplicate files in a given directory and performs specified actions on the duplicates.

.DESCRIPTION
The script uses SHA256 hashing by default to identify duplicates but can use other algorithms as well. It also logs events and can export the list of duplicate files to a CSV file. Enhanced with intelligent resolution strategies, HTML reports, and multi-directory comparison.

.PARAMETERS
- targetDir: The directory to scan for duplicate files. Default is 'C:\Default\Path'.
- hashAlgorithm: The hash algorithm to use for identifying duplicates. Default is 'SHA256'.
- exportPath: Path to the CSV file where the list of duplicates will be saved. Default is '.\duplicate_files.csv'.
- logPath: Path to the log file where events will be logged. Default is '.\file_operations.log'.
- excludeDirs: Array of directories to exclude from scanning. Default is an empty array.
- excludeFileTypes: Array of file types to exclude from scanning. Default is an empty array.
- userConfirm: The action to perform on duplicates. Options are 'None', 'Delete', or 'Move'. Default is 'None'.
- movePath: The directory where duplicates will be moved if the userConfirm parameter is set to 'Move'. Default is 'C:\DuplicateFiles'.
- resolutionStrategy: Strategy for intelligent resolution (Newest, Largest, MostAccessed, KeepAll). Default is 'Newest'.
- reportPath: Path to HTML report output. Default is 'DuplicateReport.html'.
- generateReport: Generate HTML report. Default is false.

.EXAMPLE
Find-DuplicateFiles -targetDir 'C:\MyFiles' -hashAlgorithm 'SHA256' -resolutionStrategy Newest -generateReport

.EXAMPLE
Find-DuplicateFiles -targetDir 'C:\MyFiles' -hashAlgorithm 'SHA256' -userConfirm 'Delete' -Simulate

.INPUTS
- targetDir: String
- hashAlgorithm: 'SHA256', 'SHA1', 'SHA384', 'SHA512', etc.
- exportPath: String
- logPath: String
- excludeDirs: Array of strings
- excludeFileTypes: Array of strings
- userConfirm: String ('None', 'Delete', 'Move')
- movePath: String

.OUTPUTS
- Duplicate files will be acted upon as per the userConfirm parameter.
- A CSV file containing the list of duplicates.
- A log file containing events.
- HTML report if generateReport is enabled.

.NOTES
File Name: Find-DuplicateFiles.ps1
Author: Cláudio Gonçalves
Version: 3.0
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)
Initialize-Logging -Component "Find-DuplicateFiles"

# Function to Calculate File Hash with exception handling
function Get-FileHashValue ($filePath, $algorithm = 'MD5') {
    try {
        # Calculate and return the hash of the file
        $hash = Get-FileHash -Path $filePath -Algorithm $algorithm
        return $hash.Hash
    } catch {
        # Log and display a warning if hashing fails
        Write-Warning "Failed to hash $filePath using $algorithm"
        Log-Event "Failed to hash $filePath using $algorithm" $logPath
        return $null
    }
}

# Logging Function with timestamp
function Log-Event ($message, $logPath) {
    # Get the current date and time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Add the log entry to the log file
    Add-Content -Path $logPath -Value "[$timestamp] $message"
}

# Function to validate and sanitize paths to prevent path traversal attacks
function Test-ValidPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Error "Path cannot be null or empty."
        return $false
    }

    # Check for path traversal attempts
    if ($Path -match '\.\.') {
        Write-Error "Path contains directory traversal sequences."
        return $false
    }

    # Validate the path format
    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Invalid path format: $Path"
        return $false
    }
}

# Function to validate file extension
function Test-ValidExtension {
    param([string]$Extension)

    if ([string]::IsNullOrWhiteSpace($Extension)) {
        return $false
    }

    # Only allow valid file extensions (alphanumeric with dot)
    if ($Extension -notmatch '^\.[a-zA-Z0-9]+$') {
        Write-Error "Invalid file extension: $Extension"
        return $false
    }

    return $true
}

# Main Function for Finding Duplicate Files
function Find-DuplicateFiles {
    [CmdletBinding()]
    param (
        # Define function parameters with default values
        [string]$targetDir = 'C:\Default\Path',
        [ValidateSet('SHA256','SHA1','SHA384','SHA512','MD5')]
        [string]$hashAlgorithm = 'SHA256',
        [string]$exportPath = '.\duplicate_files.csv',
        [string]$logPath = '.\file_operations.log',
        [array]$excludeDirs = @(),
        [array]$excludeFileTypes = @(),
        [string]$userConfirm = 'None',
        [string]$movePath = 'C:\DuplicateFiles'
    )

    # Validate if target directory exists
    if (-Not (Test-Path $targetDir)) {
        Write-Warning "Target directory not found: $targetDir"
        Log-Event "Target directory not found: $targetDir" $logPath
        return
    }

    # Validate if the directory for the export path exists
    if (-Not (Test-Path (Split-Path -Parent $exportPath))) {
        Write-Warning "Export path directory not found: $exportPath"
        Log-Event "Export path directory not found: $exportPath" $logPath
        return
    }

    # Initialize variables
    $confirmAll = $false # To track if user has chosen to confirm for all
    $hashTable = @{}
    $duplicates = @()

    # Validate target directory path to prevent path traversal
    if (-not (Test-ValidPath -Path $targetDir)) {
        Write-Error "Invalid target directory path: $targetDir"
        Log-Event "Invalid target directory path: $targetDir" $logPath
        return
    }

    # Resolve the path to get absolute path
    $targetDir = Resolve-Path -Path $targetDir -ErrorAction Stop

    # Validate move path if specified
    if ($userConfirm -eq 'Move' -and -not (Test-ValidPath -Path $movePath)) {
        Write-Error "Invalid move path: $movePath"
        Log-Event "Invalid move path: $movePath" $logPath
        return
    }

    # Validate exclude file types
    foreach ($ext in $excludeFileTypes) {
        if (-not (Test-ValidExtension -Extension $ext)) {
            Write-Error "Invalid file extension in exclusion list: $ext"
            return
        }
    }

    # Iterate through the files in the target directory
    $files = Get-ChildItem -Path $targetDir -Recurse -File

    foreach ($file in $files) {
        # Skip the files or directories that are in the exclusion lists
        if ($excludeDirs -contains $file.DirectoryName -or $excludeFileTypes -contains $file.Extension) {
            continue
        }

        # Generate hash for each file
        $hashValue = Get-FileHashValue -filePath $file.FullName -algorithm $hashAlgorithm
        if ($hashValue -eq $null) {
            continue
        }

        # Check if this is a duplicate
        if ($hashTable.ContainsKey($hashValue)) {
            $original = $hashTable[$hashValue]
            $duplicateObject = [PSCustomObject]@{
                Original = $original
                Duplicate = $file.FullName
            }

            # Add to duplicates list and log the event
            $duplicates += $duplicateObject
            Log-Event "Duplicate found: $($file.FullName) is a duplicate of $original with hash $hashValue" $logPath

            # Ask for user confirmation if needed
            if ($userConfirm -eq 'Delete' -or $userConfirm -eq 'Move') {
                $confirm = if ($confirmAll) { 'y' } else {
                    # Ask for confirmation
                    do {
                        $confirm = Read-Host "Confirm action ($userConfirm) on duplicate $($file.FullName)? (y/n/a for all)"
                    } until ($confirm -eq 'y' -or $confirm -eq 'n' -or $confirm -eq 'a')

                    if ($confirm -eq 'a') { $confirmAll = $true }
                }

                # Perform action based on confirmation
                if ($confirm -eq 'y' -or $confirmAll) {
                    if ($userConfirm -eq 'Delete') {
                        Remove-Item -Path $file.FullName
                        Log-Event "Duplicate deleted: $($file.FullName)" $logPath
                    } elseif ($userConfirm -eq 'Move') {
                        Move-Item -Path $file.FullName -Destination $movePath
                        Log-Event "Duplicate moved: $($file.FullName) to $movePath" $logPath
                    }
                }
            }
        } else {
            # Add the file hash to the hash table
            $hashTable[$hashValue] = $file.FullName
        }
    }

    # Export list of duplicates to CSV
    $duplicates | Export-Csv -Path $exportPath -NoTypeInformation

    # Generate report if requested
    if ($generateReport) {
        Generate-DuplicateReport -Duplicates $duplicates -ReportPath $reportPath -TargetDir $targetDir
    }
}

function Get-FileAccessCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    try {
        $file = Get-Item $FilePath
        $accessCount = 0

        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            ID = 4663, 4656, 4658
            StartTime = (Get-Date).AddDays(-30)
        } -ErrorAction SilentlyContinue | Where-Object {
            $_.Message -like "*$FilePath*"
        }

        $accessCount = $events.Count

        return $accessCount
    }
    catch {
        return 0
    }
}

function Resolve-DuplicatesIntelligently {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$Duplicates,
        [ValidateSet('Newest', 'Largest', 'MostAccessed', 'KeepAll')]
        [string]$ResolutionStrategy = 'Newest',
        [switch]$Simulate,
        [string]$MovePath = 'C:\DuplicateFiles',
        [string]$logPath = '.\file_operations.log'
    )

    $resolvedCount = 0
    $skippedCount = 0

    foreach ($dup in $Duplicates) {
        try {
            $originalInfo = Get-Item $dup.Original -ErrorAction Stop
            $duplicateInfo = Get-Item $dup.Duplicate -ErrorAction Stop

            $keep = $null
            $remove = $null

            switch ($ResolutionStrategy) {
                'Newest' {
                    if ($duplicateInfo.LastWriteTime -gt $originalInfo.LastWriteTime) {
                        $keep = $dup.Duplicate
                        $remove = $dup.Original
                    } else {
                        $keep = $dup.Original
                        $remove = $dup.Duplicate
                    }
                }
                'Largest' {
                    if ($duplicateInfo.Length -gt $originalInfo.Length) {
                        $keep = $dup.Duplicate
                        $remove = $dup.Original
                    } else {
                        $keep = $dup.Original
                        $remove = $dup.Duplicate
                    }
                }
                'MostAccessed' {
                    $origAccessed = Get-FileAccessCount -Path $dup.Original
                    $dupAccessed = Get-FileAccessCount -Path $dup.Duplicate

                    if ($dupAccessed -gt $origAccessed) {
                        $keep = $dup.Duplicate
                        $remove = $dup.Original
                    } else {
                        $keep = $dup.Original
                        $remove = $dup.Duplicate
                    }
                }
            }

            $action = if ($Simulate) { "[SIMULATE] " } else { "" }
            Write-Host "$($action)Keeping: $keep"
            Write-Host "$($action)Removing: $remove"

            if (-not $Simulate) {
                Remove-Item $remove -Force -ErrorAction Stop
                Log-Event "Removed duplicate: $remove (kept: $keep) - Strategy: $ResolutionStrategy" $logPath
                $resolvedCount++
            } else {
                $resolvedCount++
            }
        }
        catch {
            Write-Warning "Failed to process duplicate pair: $_"
            $skippedCount++
            Log-Event "Failed to process duplicate: $($_.Exception.Message)" $logPath
        }
    }

    Write-Host "`nResolution Summary:"
    Write-Host "  Resolved: $resolvedCount files"
    Write-Host "  Skipped: $skippedCount files"
}

function Generate-DuplicateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$Duplicates,
        [Parameter(Mandatory=$true)]
        [string]$ReportPath,
        [string]$TargetDir
    )

    $totalDuplicates = $Duplicates.Count
    $totalSizeSaved = ($Duplicates | ForEach-Object {
        try {
            (Get-Item $_.Duplicate -ErrorAction SilentlyContinue).Length
        } catch { 0 }
    } | Measure-Object -Sum).Sum

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Duplicate Files Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 1200px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; margin: -30px -30px 30px -30px; }
        .summary { background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .summary-card { display: inline-block; margin: 10px 20px; padding: 15px; background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary-value { font-size: 28px; font-weight: bold; color: #667eea; }
        .summary-label { font-size: 14px; color: #666; margin-top: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background: #667eea; color: white; font-weight: 600; }
        tr:nth-child(even) { background: #f9f9f9; }
        tr:hover { background: #f0f0f0; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; }
        .badge-danger { background: #dc3545; color: white; }
        .badge-warning { background: #ffc107; color: black; }
        .timestamp { color: #666; font-size: 12px; font-style: italic; }
        .highlight { background: #fff3cd; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Duplicate Files Report</h1>
            <p class="timestamp">Generated: $(Get-Date)</p>
        </div>

        <div class="summary">
            <div class="summary-card">
                <div class="summary-value">$totalDuplicates</div>
                <div class="summary-label">Total Duplicates</div>
            </div>
            <div class="summary-card">
                <div class="summary-value">$([math]::Round($totalSizeSaved/1GB, 2)) GB</div>
                <div class="summary-label">Potential Space Saved</div>
            </div>
            <div class="summary-card">
                <div class="summary-value">$([math]::Round($totalSizeSaved/1MB, 2)) MB</div>
                <div class="summary-label">Total Size (MB)</div>
            </div>
        </div>

        <h2>Duplicate Files (Top 100)</h2>
        <table>
            <tr>
                <th>Original File</th>
                <th>Duplicate File</th>
                <th>Size (MB)</th>
                <th>Hash Preview</th>
                <th>Action</th>
            </tr>
"@

    $displayDuplicates = $Duplicates | Select-Object -First 100

    foreach ($dup in $displayDuplicates) {
        try {
            $sizeMB = [math]::Round((Get-Item $dup.Duplicate -ErrorAction SilentlyContinue).Length/1MB, 2)
            $hash = Get-FileHashValue -filePath $dup.Original -algorithm 'SHA256'
            $hashPreview = if ($hash) { $hash.Substring(0,16) } else { "N/A" }

            $badgeClass = if ($sizeMB -gt 100) { 'badge-danger' } elseif ($sizeMB -gt 10) { 'badge-warning' } else { '' }
            $badge = if ($badgeClass) { "<span class='badge $badgeClass'>Large</span>" } else { '' }

            $html += @"
            <tr class="highlight">
                <td style="word-break: break-all;">$($dup.Original)</td>
                <td style="word-break: break-all;">$($dup.Duplicate)</td>
                <td>$sizeMB $badge</td>
                <td style="font-family: monospace;">$hashPreview...</td>
                <td><a href="$($dup.Duplicate)" class="badge" style="background: #667eea; color: white; text-decoration: none;">Open</a></td>
            </tr>
"@
        }
        catch {
            $html += @"
            <tr>
                <td colspan="5" style="color: red;">Error processing file: $($_.Exception.Message)</td>
            </tr>
"@
        }
    }

    $html += @"
        </table>
        <p class="timestamp"><em>Showing first 100 duplicates of $totalDuplicates total</em></p>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $ReportPath -Force -Encoding UTF8
    Write-ScriptLog -Level Info -Message "Report generated: $ReportPath"
}

function Compare-MultipleDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Directories,
        [string]$ExportPath = ".\cross_directory_duplicates.csv"
    )

    $hashTable = @{}
    $crossDirectoryDuplicates = @()

    foreach ($dir in $Directories) {
        Write-Progress -Activity "Scanning directories" -Status "Processing: $dir" `
            -PercentComplete (($Directories.IndexOf($dir) + 1) / $Directories.Count * 100)

        $files = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            try {
                $hash = Get-FileHashValue -filePath $file.FullName -algorithm 'SHA256'

                if ($hash -and $hashTable.ContainsKey($hash)) {
                    $existing = $hashTable[$hash]
                    if ($existing.Directory -ne $dir) {
                        $crossDirectoryDuplicates += [PSCustomObject]@{
                            Original = $existing.FullPath
                            Duplicate = $file.FullName
                            OriginalDir = $existing.Directory
                            DuplicateDir = $dir
                            Hash = $hash
                            SizeMB = [math]::Round($file.Length/1MB, 2)
                        }
                    }
                } else {
                    $hashTable[$hash] = @{
                        FullPath = $file.FullName
                        Directory = $dir
                    }
                }
            }
            catch {
                Write-Warning "Failed to hash $($file.FullName): $_"
            }
        }
    }

    $crossDirectoryDuplicates | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Found $($crossDirectoryDuplicates.Count) cross-directory duplicates"
    Write-Host "Report saved to: $ExportPath"

    return $crossDirectoryDuplicates
}

function Analyze-DuplicatesByFileType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$Duplicates
    )

    $fileTypeStats = @{}

    foreach ($dup in $Duplicates) {
        try {
            $ext = [System.IO.Path]::GetExtension($dup.Duplicate)
            $size = (Get-Item $dup.Duplicate -ErrorAction SilentlyContinue).Length

            if (-not $fileTypeStats.ContainsKey($ext)) {
                $fileTypeStats[$ext] = @{
                    Count = 0
                    TotalSize = 0
                }
            }

            $fileTypeStats[$ext].Count++
            $fileTypeStats[$ext].TotalSize += $size
        }
        catch {
        }
    }

    $fileTypeStats.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            FileType = $_.Key
            Count = $_.Value.Count
            TotalSizeMB = [math]::Round($_.Value.TotalSize/1MB, 2)
            AvgSizeMB = [math]::Round($_.Value.TotalSize/1MB/$_.Value.Count, 2)
        }
    } | Sort-Object TotalSizeMB -Descending | Format-Table -AutoSize
}