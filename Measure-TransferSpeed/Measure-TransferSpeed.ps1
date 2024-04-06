<#
.Synopsis
   This PowerShell script measures transfer speeds between servers and logs performance metrics for analysis and troubleshooting purposes.

.Description
   The script facilitates performance measurement between two specified servers by transferring a test file multiple times and recording duration and speed metrics for each iteration. It provides detailed logs for both performance measurement and script execution, enhancing visibility into network and storage performance.

.Example
   .\Measure-TransferSpeed.ps1 -SourceServer "ABC" -DestinationServer "XYZ" -FileSizeMB 100 -Iterations 5 -MeasurementLogFilePath "MeasurementLog.txt" -ExecutionLogFilePath "ExecutionLog.txt"
   Initiates transfer speed measurement between servers "ABC" and "XYZ" using a 100 MB test file for 5 iterations. Logs performance metrics to "MeasurementLog.txt" and script execution details to "ExecutionLog.txt".

.Inputs
   Parameters include SourceServer, DestinationServer, FileSizeMB, Iterations, MeasurementLogFilePath, and ExecutionLogFilePath. Additional options for ExportResults and CloudEnabled provide flexibility in result handling and cloud integration.

.Outputs
   Detailed logs for performance measurement and script execution, facilitating analysis and troubleshooting of transfer speed issues.

.Notes
   This script is designed for system administrators and network engineers to monitor and optimize transfer speeds between servers. It supports both local and remote execution scenarios, enabling comprehensive performance testing in various environments.
   Version: 1.0
   Author: Cláudio Gonçalves
   Last Updated: April 06, 2024
#>

function Measure-TransferSpeed {
    param (
        [string]$SourceServer,                 # Source server name or IP address
        [string]$DestinationServer,           # Destination server name or IP address
        [int]$FileSizeMB,                     # Size of the file to transfer in megabytes
        [int]$Iterations = 1,                 # Number of iterations to perform the transfer (multiple attempts for accuracy)
        [switch]$CloudEnabled,                # Indicates if cloud features are enabled (not currently used)
        [string]$MeasurementLogFilePath,     # Path to the performance measurement log file
        [string]$ExecutionLogFilePath        # Path to the execution log file
    )

    try {
        # Execution Log: Log script start
        if ($ExecutionLogFilePath) {
            $logMessage = "Script start: $(Get-Date)"
            Add-Content -Path $ExecutionLogFilePath -Value $logMessage
        }

        # Measurement Log: Log start time
        $startTime = Get-Date
        if ($MeasurementLogFilePath) {
            $logMessage = "### Starting operation at $startTime"
            Add-Content -Path $MeasurementLogFilePath -Value $logMessage
        }

        # Generate file on source server using New-Item
        $filePath = "\\$SourceServer\file.txt"
        New-Item -Path $filePath -ItemType "file" -Value " " -Force

        # Measure transfer performance
        $results = @()
        for ($i = 1; $i -le $Iterations; $i++) {
            # Execution Log: Log transfer operation
            if ($ExecutionLogFilePath) {
                $logMessage = "Iteration $i: Transferring file from $SourceServer to $DestinationServer"
                Add-Content -Path $ExecutionLogFilePath -Value $logMessage
            }

            $iterationStartTime = Get-Date
            Copy-Item -Path $filePath -Destination "\\$DestinationServer\file.txt" -ErrorAction Stop
            $iterationEndTime = Get-Date

            $duration = ($iterationEndTime - $iterationStartTime).TotalSeconds
            $speed = ($FileSizeMB * 1MB) / $duration  # Bytes per second

            $results += [PSCustomObject]@{
                Iteration = $i
                Duration = $duration
                Speed = $speed
            }

            # Measurement Log: Log iteration details
            if ($MeasurementLogFilePath) {
                $logMessage = "Iteration $i - Duration: $duration seconds, Speed: $speed bytes/second"
                Add-Content -Path $MeasurementLogFilePath -Value $logMessage
            }
        }

        # Calculate lowest, highest, and average speeds
        $lowestSpeed = $results | Measure-Object -Property Speed -Minimum | Select-Object -ExpandProperty Minimum
        $highestSpeed = $results | Measure-Object -Property Speed -Maximum | Select-Object -ExpandProperty Maximum
        $averageSpeed = ($results | Measure-Object -Property Speed -Average).Average

        # Measurement Log: Log report generation
        if ($MeasurementLogFilePath) {
            $logMessage = "Lowest Speed: $lowestSpeed bytes/second"
            Add-Content -Path $MeasurementLogFilePath -Value $logMessage
            $logMessage = "Highest Speed: $highestSpeed bytes/second"
            Add-Content -Path $MeasurementLogFilePath -Value $logMessage
            $logMessage = "Average Speed: $averageSpeed bytes/second"
            Add-Content -Path $MeasurementLogFilePath -Value $logMessage
        }

        # Execution Log: Log script end
        if ($ExecutionLogFilePath) {
            $logMessage = "Script end: $(Get-Date)"
            Add-Content -Path $ExecutionLogFilePath -Value $logMessage
        }

        # Export results to CSV file if desired
        if ($PSCmdlet.MyInvocation.BoundParameters['ExportResults']) {
            $results | Export-Csv -Path $ExportResults -NoTypeInformation
        }

        # Remove temporary file
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue

        # Return results
        [PSCustomObject]@{
            LowestSpeed = $lowestSpeed
            HighestSpeed = $highestSpeed
            AverageSpeed = $averageSpeed
        }
    }
    catch {
        $errorMessage = "An error occurred: $_"
        Write-Error $errorMessage
        
        # Execution Log: Log error
        if ($ExecutionLogFilePath) {
            $logMessage = "Error: $errorMessage"
            Add-Content -Path $ExecutionLogFilePath -Value $logMessage
        }
    }
}
