<#
.SYNOPSIS
This script identifies duplicate files in a given directory and performs specified actions on the duplicates.

.DESCRIPTION
The script uses MD5 hashing by default to identify duplicate files but can use other algorithms as well. It also logs events and can export the list of duplicate files to a CSV file.

.PARAMETERS
- targetDir: The directory to scan for duplicate files. Default is 'C:\Default\Path'.
- hashAlgorithm: The hash algorithm to use for identifying duplicates. Default is 'MD5'.
- exportPath: Path to the CSV file where the list of duplicates will be saved. Default is '.\duplicate_files.csv'.
- logPath: Path to the log file where events will be logged. Default is '.\file_operations.log'.
- excludeDirs: Array of directories to exclude from scanning. Default is an empty array.
- excludeFileTypes: Array of file types to exclude from scanning. Default is an empty array.
- userConfirm: The action to perform on duplicates. Options are 'None', 'Delete', or 'Move'. Default is 'None'.
- movePath: The directory where duplicates will be moved if the userConfirm parameter is set to 'Move'. Default is 'C:\DuplicateFiles'.

.EXAMPLE
Find-DuplicateFiles -targetDir 'C:\MyFiles' -hashAlgorithm 'SHA256' -userConfirm 'Delete'

.INPUTS
- targetDir: String
- hashAlgorithm: 'MD5', 'SHA1', 'SHA256', etc.
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

.NOTES
File Name: Find-DuplicateFiles.ps1
Author: Cláudio Gonçalves
Version: 2.0
#>

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

# Main Function for Finding Duplicate Files
function Find-DuplicateFiles {
    [CmdletBinding()]
    param (
        # Define function parameters with default values
        [string]$targetDir = 'C:\Default\Path',
        [string]$hashAlgorithm = 'MD5',
        [string]$exportPath = '.\duplicate_files.csv',
        [string]$logPath = '.\file_operations.log', # New Parameter for logging
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
}
