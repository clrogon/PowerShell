<#
.Synopsis
   This PowerShell script measures transfer speeds between servers and logs performance metrics for analysis and troubleshooting purposes.

.Description
   The script facilitates performance measurement between two specified servers by transferring a test file multiple times and recording duration and speed metrics for each iteration. It provides detailed logs for both performance measurement and script execution, enhancing visibility into network and storage performance. Enhanced with historical tracking, multi-path testing, and trend analysis.

.Example
   .\Measure-TransferSpeed.ps1 -SourceServer "ABC" -DestinationServer "XYZ" -FileSizeMB 100 -Iterations 5 -IncludeHistoricalComparison
   Initiates transfer speed measurement between servers "ABC" and "XYZ" using a 100 MB test file for 5 iterations with historical comparison.

.Example
   .\Measure-TransferSpeed.ps1 -SourceServer "ABC" -DestinationServers @("XYZ", "PDQ") -FileSizeMB 100 -MultiPathTest
   Tests transfer speeds to multiple destination servers for redundancy validation.

.Example
   $credential = Get-Credential
   .\Measure-TransferSpeed.ps1 -SourceServer "ABC" -DestinationServer "XYZ" -FileSizeMB 100 -Credential $credential
   Initiates transfer speed measurement with authentication using provided credentials.

.Inputs
   Parameters include SourceServer, DestinationServer(s), FileSizeMB, Iterations, Credential, HistoricalDataPath, MultiPathTest options.

.Outputs
   Detailed logs for performance measurement, historical trends, and multi-path comparison reports.

.Notes
   This script is designed for system administrators and network engineers to monitor and optimize transfer speeds between servers. It supports both local and remote execution scenarios, enabling comprehensive performance testing in various environments.
   Version: 2.0
   Author: Cláudio Gonçalves
   Last Updated: January 07, 2026
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)

function Measure-TransferSpeed {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SourceServer,
        [Parameter(Mandatory=$true)]
        [string]$DestinationServer,
        [Parameter(Mandatory=$true)]
        [int]$FileSizeMB,
        [int]$Iterations = 1,
        [PSCredential]$Credential,
        [switch]$CloudEnabled,
        [string]$MeasurementLogFilePath,
        [string]$ExecutionLogFilePath,
        [string]$HistoricalDataPath = "$env:USERPROFILE\TransferSpeedHistory.csv",
        [switch]$IncludeHistoricalComparison,
        [switch]$GenerateReport,
        [string]$ReportPath = "$env:USERPROFILE\TransferSpeedReport.html"
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

        # Validate server names to prevent injection
        if ($SourceServer -match '[^a-zA-Z0-9.\-]' -or $DestinationServer -match '[^a-zA-Z0-9.\-]') {
            throw "Invalid server name detected. Server names should only contain alphanumeric characters, dots, and hyphens."
        }

        # Generate file on source server using New-Item
        $filePath = "\\$SourceServer\file.txt"
        $destPath = "\\$DestinationServer\file.txt"

        # Create file on source with credential if provided
        $fileParams = @{
            Path = $filePath
            ItemType = "file"
            Value = " "
            Force = $true
            ErrorAction = "Stop"
        }

        if ($Credential) {
            if (-not (Test-Path -Path "\\$SourceServer\`$" -Credential $Credential -ErrorAction SilentlyContinue)) {
                throw "Unable to connect to source server $SourceServer with provided credentials."
            }

            # Use New-PSDrive for credential-based access
            $sourceDrive = New-PSDrive -Name "SourceTest" -PSProvider FileSystem -Root "\\$SourceServer\`$" -Credential $Credential -ErrorAction Stop
            $testFilePath = "SourceTest:\file.txt"
            New-Item @fileParams | Out-Null
        } else {
            New-Item @fileParams | Out-Null
        }

        # Measure transfer performance
        $results = @()
        for ($i = 1; $i -le $Iterations; $i++) {
            # Execution Log: Log transfer operation
            if ($ExecutionLogFilePath) {
                $logMessage = "Iteration $i: Transferring file from $SourceServer to $DestinationServer"
                Add-Content -Path $ExecutionLogFilePath -Value $logMessage
            }

            $iterationStartTime = Get-Date

            if ($Credential) {
                # Copy using credential via PSDrive
                $destDrive = New-PSDrive -Name "DestTest" -PSProvider FileSystem -Root "\\$DestinationServer\`$" -Credential $Credential -ErrorAction Stop
                Copy-Item -Path $testFilePath -Destination "DestTest:\file.txt" -ErrorAction Stop
                Remove-PSDrive -Name "DestTest" -Force
            } else {
                Copy-Item -Path $filePath -Destination $destPath -ErrorAction Stop
            }

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
        if ($Credential -and $testFilePath) {
            Remove-Item -Path $testFilePath -Force -ErrorAction SilentlyContinue
            Remove-PSDrive -Name "SourceTest" -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        }

        # Return results
        $finalResult = [PSCustomObject]@{
            LowestSpeed = $lowestSpeed
            HighestSpeed = $highestSpeed
            AverageSpeed = $averageSpeed
        }

        # Store results for historical tracking
        $historicalResult = [PSCustomObject]@{
            Timestamp = Get-Date
            SourceServer = $SourceServer
            DestinationServer = $DestinationServer
            AverageSpeed = $averageSpeed
            LowestSpeed = $lowestSpeed
            HighestSpeed = $highestSpeed
            Iterations = $Iterations
            FileSizeMB = $FileSizeMB
        }

        # Append to historical data
        $historicalResult | Export-Csv -Path $HistoricalDataPath -Append -NoTypeInformation -Force

        # Compare with historical performance
        if ($IncludeHistoricalComparison) {
            $historicalData = Import-Csv $HistoricalDataPath -ErrorAction SilentlyContinue
            if ($historicalData) {
                $historicalAvg = $historicalData |
                    Where-Object { $_.SourceServer -eq $SourceServer -and $_.DestinationServer -eq $DestinationServer } |
                    Where-Object { $_.Timestamp -ne $historicalResult.Timestamp.ToString() } |
                    Select-Object -ExpandProperty AverageSpeed |

                if ($historicalAvg) {
                    $historicalAvgValue = [double]$historicalAvg
                    $trend = if ($averageSpeed -gt $historicalAvgValue * 1.1) { "IMPROVED" }
                             elseif ($averageSpeed -lt $historicalAvgValue * 0.9) { "DEGRADED" }
                             else { "STABLE" }

                    $trendMessage = "Performance Trend: $trend (Current: $([math]::Round($averageSpeed/1MB, 2)) MB/s vs Historical Avg: $([math]::Round($historicalAvgValue/1MB, 2)) MB/s)"

                    if ($MeasurementLogFilePath) {
                        Add-Content -Path $MeasurementLogFilePath -Value $trendMessage
                    }
                    Write-Host $trendMessage
                }
            }
        }

        # Generate report if requested
        if ($GenerateReport) {
            Generate-TransferSpeedReport -ReportPath $ReportPath -CurrentResult $finalResult -HistoricalPath $HistoricalDataPath
        }

        return $finalResult
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

function Test-NetworkLatency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DestinationServer,
        [PSCredential]$Credential,
        [int]$PingCount = 10
    )

    $pings = @()
    for ($i = 1; $i -le $PingCount; $i++) {
        $ping = Test-Connection -ComputerName $DestinationServer -Count 1 -ErrorAction SilentlyContinue
        if ($ping) {
            $pings += $ping.ResponseTime
        }
    }

    if ($pings.Count -eq 0) {
        return $null
    }

    return [PSCustomObject]@{
        AverageLatency = ($pings | Measure-Object -Average).Average
        MinLatency = ($pings | Measure-Object -Minimum).Minimum
        MaxLatency = ($pings | Measure-Object -Maximum).Maximum
        PacketLoss = ((10 - $pings.Count) / 10) * 100
    }
}

function Measure-MultiPathTransfer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceServer,
        [Parameter(Mandatory=$true)]
        [string[]]$DestinationServers,
        [int]$FileSizeMB = 100,
        [PSCredential]$Credential
    )

    $results = @()
    foreach ($dest in $DestinationServers) {
        Write-Progress -Activity "Testing Multi-Path Transfer" -Status "Testing: $dest" `
            -PercentComplete (($DestinationServers.IndexOf($dest) + 1) / $DestinationServers.Count * 100)

        try {
            $result = Measure-TransferSpeed -SourceServer $SourceServer -DestinationServer $dest `
                -FileSizeMB $FileSizeMB -Credential $Credential -ErrorAction Stop

            $results += [PSCustomObject]@{
                Destination = $dest
                SpeedMBps = [math]::Round($result.AverageSpeed/1MB, 2)
                LowestSpeedMBps = [math]::Round($result.LowestSpeed/1MB, 2)
                HighestSpeedMBps = [math]::Round($result.HighestSpeed/1MB, 2)
                Status = if ($result.AverageSpeed -gt 10MB) { "FAST" } else { "SLOW" }
            }
        }
        catch {
            $results += [PSCustomObject]@{
                Destination = $dest
                SpeedMBps = "ERROR"
                LowestSpeedMBps = "ERROR"
                HighestSpeedMBps = "ERROR"
                Status = "FAILED"
                Error = $_.Exception.Message
            }
        }
    }

    return $results | Sort-Object SpeedMBps -Descending
}

function Measure-TransferSpeedWithThrottling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceServer,
        [Parameter(Mandatory=$true)]
        [string]$DestinationServer,
        [int]$FileSizeMB = 100,
        [int]$BandwidthLimitMbps,
        [PSCredential]$Credential
    )

    $expectedTime = ($FileSizeMB * 8) / $BandwidthLimitMbps
    $result = Measure-TransferSpeed -SourceServer $SourceServer -DestinationServer $DestinationServer `
        -FileSizeMB $FileSizeMB -Credential $Credential
    $actualSpeedMBps = [math]::Round($result.AverageSpeed/1MB, 2)

    Write-Host "Expected time at $BandwidthLimitMbps Mbps: $([math]::Round($expectedTime, 2)) seconds"
    Write-Host "Actual speed: $actualSpeedMBps MB/s"

    $efficiency = if ($actualSpeedMBps -gt 0) {
        [math]::Round(($actualSpeedMBps * 8) / $BandwidthLimitMbps * 100, 1)
    } else { 0 }

    Write-Host "Efficiency: $efficiency%"

    return [PSCustomObject]@{
        ExpectedTime = $expectedTime
        ActualTime = ($FileSizeMB * 8) / $actualSpeedMBps
        ExpectedSpeed = $BandwidthLimitMbps
        ActualSpeedMBps = $actualSpeedMBps
        EfficiencyPercent = $efficiency
    }
}

function Generate-TransferSpeedReport {
    [CmdletBinding()]
    param(
        [string]$ReportPath,
        [PSCustomObject]$CurrentResult,
        [string]$HistoricalPath
    )

    $historicalData = if (Test-Path $HistoricalPath) { Import-Csv $HistoricalPath } else { @() }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Transfer Speed Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .summary { background: #4CAF50; color: white; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .metric { display: inline-block; margin: 10px 20px; }
        .metric-label { display: block; font-size: 12px; opacity: 0.9; }
        .metric-value { font-size: 24px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background: #4CAF50; color: white; }
        tr:nth-child(even) { background: #f2f2f2; }
        .fast { color: #4CAF50; font-weight: bold; }
        .slow { color: #f44336; font-weight: bold; }
        .timestamp { color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Transfer Speed Report</h1>
        <div class="timestamp">Generated: $(Get-Date)</div>

        <div class="summary">
            <h2>Current Performance</h2>
            <div class="metric">
                <span class="metric-label">Average Speed</span>
                <span class="metric-value">$([math]::Round($CurrentResult.AverageSpeed/1MB, 2)) MB/s</span>
            </div>
            <div class="metric">
                <span class="metric-label">Lowest Speed</span>
                <span class="metric-value">$([math]::Round($CurrentResult.LowestSpeed/1MB, 2)) MB/s</span>
            </div>
            <div class="metric">
                <span class="metric-label">Highest Speed</span>
                <span class="metric-value">$([math]::Round($CurrentResult.HighestSpeed/1MB, 2)) MB/s</span>
            </div>
        </div>

        <h2>Historical Performance</h2>
        <table>
            <tr>
                <th>Timestamp</th>
                <th>Source</th>
                <th>Destination</th>
                <th>Average (MB/s)</th>
                <th>Trend</th>
            </tr>
"@

    foreach ($entry in $historicalData | Select-Object -Last 10 | Sort-Object Timestamp -Descending) {
        $timestamp = [DateTime]$entry.Timestamp
        $speed = [double]$entry.AverageSpeed
        $trend = if ($speed -gt 10MB) { '<span class="fast">FAST</span>' } else { '<span class="slow">SLOW</span>' }

        $html += @"
            <tr>
                <td>$($timestamp.ToString('yyyy-MM-dd HH:mm'))</td>
                <td>$($entry.SourceServer)</td>
                <td>$($entry.DestinationServer)</td>
                <td>$([math]::Round($speed/1MB, 2))</td>
                <td>$trend</td>
            </tr>
"@
    }

    $html += @"
        </table>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $ReportPath -Force
    Write-Host "Report generated: $ReportPath"
}
