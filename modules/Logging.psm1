<#
.SYNOPSIS
    Unified logging framework for PowerShell scripts

.DESCRIPTION
    Provides consistent logging across all scripts with support for
    multiple outputs (file, event log, console), log rotation, and structured data.

.NOTES
    Version: 1.0
    Author: Cláudio Gonçalves
#>

function Initialize-Logging {
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [string]$Component = $MyInvocation.MyCommand.Name,
        [string]$EventLogName = "Application",
        [string]$EventLogSource = "PowerShellScripts"
    )
    
    $config = Get-ScriptConfiguration
    
    if (-not $LogPath) {
        $logDir = $config.Logging.DefaultPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $LogPath = Join-Path $logDir "$Component.log"
    }
    
    $script:LogPath = $LogPath
    $script:LogComponent = $Component
    $script:EventLogName = $EventLogName
    $script:EventLogSource = $EventLogSource
    
    Register-EventLogSource -EventLogName $EventLogName -EventLogSource $EventLogSource
}

function Register-EventLogSource {
    [CmdletBinding()]
    param(
        [string]$EventLogName = "Application",
        [string]$EventLogSource = "PowerShellScripts"
    )
    
    if (-not [System.Diagnostics.EventLog]::SourceExists($EventLogSource)) {
        try {
            [System.Diagnostics.EventLog]::CreateEventSource($EventLogSource, $EventLogName)
        } catch {
            Write-Warning "Could not create event log source: $_"
        }
    }
}

function Write-ScriptLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose')]
        [string]$Level = 'Info',
        [string]$Component = $script:LogComponent,
        [hashtable]$Metadata = @{},
        [switch]$NoConsole,
        [switch]$NoFile,
        [switch]$NoEventLog
    )
    
    $timestamp = Get-Date
    
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Component = $Component
        Level = $Level
        Message = $Message
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        ProcessID = $PID
        Metadata = if ($Metadata.Count -gt 0) { ($Metadata.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ' } else { '' }
    }
    
    if (-not $NoConsole) {
        # Use Information stream for console output to enable better integration with PS analyzers
        $infoLine = "[$timestamp] [$Level] [$Component] $Message"
        try {
            Write-Information -Message $infoLine
        } catch {
            # Fallback for environments without Write-Information (older PS versions)
            Write-Host $infoLine
        }
    }
    
    if (-not $NoFile -and $script:LogPath) {
        Check-LogRotation -LogPath $script:LogPath
        
        $csvLine = "$($logEntry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')),$Component,$Level,$Message,$($logEntry.ComputerName),$($logEntry.UserName),$($logEntry.ProcessID),`"$($logEntry.Metadata)`""
        $csvLine | Add-Content -Path $script:LogPath -ErrorAction SilentlyContinue
    }
    
    if (-not $NoEventLog) {
        $eventType = switch ($Level) {
            'Error' { 'Error' }
            'Warning' { 'Warning' }
            default { 'Information' }
        }
        
        $eventId = switch ($Level) {
            'Error' { 1001 }
            'Warning' { 1002 }
            'Debug' { 1003 }
            'Verbose' { 1004 }
            default { 1000 }
        }
        
        try {
            Write-EventLog -LogName $script:EventLogName -Source $script:EventLogSource `
                -EntryType $eventType -Message $Message -EventId $eventId -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not write to event log: $_"
        }
    }
    
    return $logEntry
}

function Check-LogRotation {
    [CmdletBinding()]
    param(
        [string]$LogPath
    )
    
    if (-not (Test-Path $LogPath)) {
        return
    }
    
    $config = Get-ScriptConfiguration
    $maxSize = $config.Logging.MaxSize
    
    $logFile = Get-Item $LogPath
    if ($logFile.Length -gt $maxSize) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$LogPath.$timestamp"
        Move-Item -Path $LogPath -Destination $backupPath -Force
        
        Write-ScriptLog -Level Warning -Message "Log rotated to $backupPath" -NoConsole
        
        Clean-OldLogs -LogDirectory (Split-Path -Parent $LogPath)
    }
}

function Clean-OldLogs {
    [CmdletBinding()]
    param(
        [string]$LogDirectory,
        [int]$RetentionDays = 30
    )
    
    $config = Get-ScriptConfiguration
    if ($config.Logging.RetentionDays) {
        $RetentionDays = $config.Logging.RetentionDays
    }
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    
    Get-ChildItem -Path $LogDirectory -Filter "*.log.*" | Where-Object {
        $_.LastWriteTime -lt $cutoffDate
    } | Remove-Item -Force
}

function Start-LogTransaction {
    [CmdletBinding()]
    param(
        [string]$TransactionName,
        [hashtable]$InitialData = @{}
    )
    
    $script:CurrentTransaction = @{
        Name = $TransactionName
        StartTime = Get-Date
        Steps = @()
        Data = $InitialData
    }
    
    Write-ScriptLog -Level Info -Message "Transaction started: $TransactionName"
}

function Complete-LogTransaction {
    [CmdletBinding()]
    param(
        [string]$Status = 'Completed',
        [string]$AdditionalInfo = ''
    )
    
    if ($script:CurrentTransaction) {
        $duration = (Get-Date) - $script:CurrentTransaction.StartTime
        
        $summary = "Transaction '$($script:CurrentTransaction.Name)' $Status in $([math]::Round($duration.TotalSeconds, 2)) seconds"
        
        if ($AdditionalInfo) {
            $summary += " - $AdditionalInfo"
        }
        
        if ($script:CurrentTransaction.Steps.Count -gt 0) {
            $summary += " ($($script:CurrentTransaction.Steps.Count) steps)"
        }
        
        Write-ScriptLog -Level Info -Message $summary
        
        $script:CurrentTransaction = $null
    }
}

function Add-LogTransactionStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$StepName,
        [string]$StepType = 'Info',
        [hashtable]$StepData = @{}
    )
    
    if ($script:CurrentTransaction) {
        $step = [PSCustomObject]@{
            Name = $StepName
            Type = $StepType
            Timestamp = Get-Date
            Data = $StepData
        }
        
        $script:CurrentTransaction.Steps += $step
        
        Write-ScriptLog -Level $StepType -Message "Transaction step: $StepName"
    }
}

function Get-LogSummary {
    [CmdletBinding()]
    param(
        [string]$LogPath,
        [DateTime]$StartDate = (Get-Date).AddDays(-7),
        [DateTime]$EndDate = Get-Date
    )
    
    if (-not (Test-Path $LogPath)) {
        return $null
    }
    
    $logEntries = Import-Csv $LogPath | Where-Object {
        $timestamp = [DateTime]::Parse($_.Timestamp)
        $timestamp -ge $StartDate -and $timestamp -le $EndDate
    }
    
    $summary = [PSCustomObject]@{
        TotalEntries = $logEntries.Count
        InfoCount = ($logEntries | Where-Object Level -eq 'Info').Count
        WarningCount = ($logEntries | Where-Object Level -eq 'Warning').Count
        ErrorCount = ($logEntries | Where-Object Level -eq 'Error').Count
        DebugCount = ($logEntries | Where-Object Level -eq 'Debug').Count
        UniqueComponents = ($logEntries | Select-Object Component -Unique).Count
        DateRange = "$StartDate to $EndDate"
    }
    
    return $summary
}

function Search-ScriptLogs {
    [CmdletBinding()]
    param(
        [string]$SearchTerm,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug', 'Verbose', 'All')]
        [string]$Level = 'All',
        [DateTime]$StartDate = (Get-Date).AddDays(-7),
        [DateTime]$EndDate = Get-Date
    )
    
    $config = Get-ScriptConfiguration
    $logDir = $config.Logging.DefaultPath
    
    $results = @()
    
    Get-ChildItem -Path $logDir -Filter "*.log" | ForEach-Object {
        $logEntries = Import-Csv $_.FullName | Where-Object {
            $timestamp = [DateTime]::Parse($_.Timestamp)
            $timestamp -ge $StartDate -and $timestamp -le $EndDate -and
            $_.Message -like "*$SearchTerm*"
        }
        
        if ($Level -ne 'All') {
            $logEntries = $logEntries | Where-Object Level -eq $Level
        }
        
        $results += $logEntries
    }
    
    return $results
}

Export-ModuleMember -Function @(
    'Initialize-Logging',
    'Register-EventLogSource',
    'Write-ScriptLog',
    'Check-LogRotation',
    'Clean-OldLogs',
    'Start-LogTransaction',
    'Complete-LogTransaction',
    'Add-LogTransactionStep',
    'Get-LogSummary',
    'Search-ScriptLogs'
)
