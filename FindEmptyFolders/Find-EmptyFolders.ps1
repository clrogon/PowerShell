<#
.SYNOPSIS
A PowerShell script that finds and logs empty directories.
.DESCRIPTION
This script recursively scans a directory for empty subdirectories. It logs the paths of empty directories and any errors encountered during the scan.
.PARAMETER FolderPath
The directory path to be scanned for empty directories. This parameter is mandatory and should be an existing directory.
.PARAMETER LogFile
The file path to which errors will be logged. Default is "C:\TSTFolder\Logs\EmptyFolders_log.log".
.PARAMETER EmptyFoldersLog
The file path to which empty directories will be logged. Default is "C:\TSTFolder\Logs\EmptyFolders_report.log".
.PARAMETER LogLevel
Controls the level of verbosity in logging. Accepted values: 'Error', 'Verbose'. Default: 'Error'.
.EXAMPLE
Find-EmptyFolders -FolderPath "C:\TestDirectory" -LogFile "C:\Logs\Errors.log" -EmptyFoldersLog "C:\Logs\Empty.log" -LogLevel "Verbose"
.INPUTS
String. Accepts string inputs for FolderPath, LogFile, EmptyFoldersLog, LogLevel.
.OUTPUTS
None. This script does not return any output to the console, but it does write to the specified log files.
.NOTES
This script should be used with caution and tested thoroughly on non-production data before real use. It uses recursion to scan the directory, which could be slow on directories with a large number of subdirectories.
.VERSION
1.0 Initial script
1.1 Added error handling and logging
1.2 Added option to rename log file if exists
1.3 Added separate logging for empty folders
1.4 Added option to control log level
.AUTHOR
Concept by Cláudio Gonçalves
#>

function Find-EmptyFolders {
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
