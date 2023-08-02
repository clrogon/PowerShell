function Find-EmptyFolders {
    param (
        [string]$FolderPath = "C:\",
        [string]$LogFile = "C:\TSTFolder\Logs\EmptyFolders_log.log",
        [string]$EmptyFoldersLog = "C:\TSTFolder\Logs\EmptyFolders_report.log"
    )

    # If the report file already exists, rename it with the last modified timestamp
    if (Test-Path -Path $EmptyFoldersLog) {
        $LastWriteTime = (Get-Item $EmptyFoldersLog).LastWriteTime.ToString('yyyyMMdd_HHmmss')
        Rename-Item -Path $EmptyFoldersLog -NewName ("{0}_{1}.log" -f $EmptyFoldersLog.TrimEnd('.log'), $LastWriteTime)
    }

    Get-ChildItem -Path $FolderPath -Recurse -Directory | ForEach-Object {
        try {
            $files = Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction Stop
            if (!$files) {
                $_.FullName | Out-File -FilePath $EmptyFoldersLog -Append
            }
        }
        catch {
            $errorMessage = "Failed to access $($_.FullName): $($_.Exception.Message)"
            Write-Error $errorMessage
            $errorMessage | Out-File -FilePath $LogFile -Append
        }
    }
}

Find-EmptyFolders
