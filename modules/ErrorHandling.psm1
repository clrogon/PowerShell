<#
.SYNOPSIS
    Standardized error handling framework for PowerShell scripts

.DESCRIPTION
    Provides consistent error handling with support for retry logic,
    graceful degradation, and comprehensive error logging.

.NOTES
    Version: 1.0
    Author: Cláudio Gonçalves
#>

function Invoke-ScriptBlockWithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        [string]$Component = $script:LogComponent,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 5,
        [switch]$ContinueOnError,
        [switch]$ReturnErrorObject,
        [scriptblock]$RetryCallback,
        [scriptblock]$FailureCallback
    )
    
    $attempt = 0
    $success = $false
    $result = $null
    $lastError = $null
    
    while (-not $success -and $attempt -le $MaxRetries) {
        $attempt++
        
        try {
            Write-ScriptLog -Level Debug -Message "Attempting $Operation (attempt $attempt of $($MaxRetries + 1))" -Component $Component
            
            $result = & $ScriptBlock
            $success = $true
            
            Write-ScriptLog -Level Info -Message "Completed: $Operation (attempt $attempt)" -Component $Component
            
            return $result
        }
        catch {
            $lastError = $_
            $errorMessage = "Failed: $Operation (attempt $attempt) - $($_.Exception.Message)"
            
            Write-ScriptLog -Level Warning -Message $errorMessage -Component $Component
            
            if ($attempt -le $MaxRetries) {
                Write-ScriptLog -Level Debug -Message "Retrying in $RetryDelaySeconds seconds..." -Component $Component
                
                if ($RetryCallback) {
                    & $RetryCallback -Attempt $attempt -Error $_
                }
                
                Start-Sleep -Seconds $RetryDelaySeconds
            } else {
                Write-ScriptLog -Level Error -Message "Max retries reached for: $Operation" -Component $Component
                
                if ($FailureCallback) {
                    & $FailureCallback -Error $_
                }
            }
        }
    }
    
    if (-not $success -and -not $ContinueOnError) {
        throw $lastError
    }
    
    if ($ReturnErrorObject -and -not $success) {
        return @{
            Success = $false
            Error = $lastError
            Attempts = $attempt
        }
    }
    
    return $result
}

function Test-PowerShellVersion {
    [CmdletBinding()]
    param(
        [int]$MajorVersion = 5,
        [int]$MinorVersion = 1
    )
    
    $currentVersion = $PSVersionTable.PSVersion
    
    if ($currentVersion.Major -lt $MajorVersion -or 
        ($currentVersion.Major -eq $MajorVersion -and $currentVersion.Minor -lt $MinorVersion)) {
        throw "This script requires PowerShell $MajorVersion.$MinorVersion or higher. Current version: $($currentVersion.ToString())"
    }
    
    return $true
}

function Test-AdministrativePrivileges {
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )
    
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin -and $ThrowOnError) {
        throw "This script requires administrative privileges. Please run as administrator."
    }
    
    return $isAdmin
}

function Test-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ComputerNames,
        [int]$Count = 1,
        [int]$TimeoutSeconds = 5
    )
    
    $results = @{}
    
    foreach ($computer in $ComputerNames) {
        try {
            $connected = Test-Connection -ComputerName $computer -Count $Count -Quiet -ErrorAction Stop
            $results[$computer] = @{
                Connected = $connected
                Latency = if ($connected) { (Test-Connection -ComputerName $computer -Count 1).ResponseTime } else { $null }
            }
            
            if (-not $connected) {
                Write-ScriptLog -Level Warning -Message "Cannot connect to $computer"
            }
        }
        catch {
            $results[$computer] = @{
                Connected = $false
                Latency = $null
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}

function Test-DiskSpace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter = "C",
        [int]$RequiredSpaceGB = 1
    )
    
    try {
        $driveInfo = Get-PSDrive -Name $DriveLetter -ErrorAction Stop
        $freeSpaceGB = $driveInfo.Free / 1GB
        
        $result = [PSCustomObject]@{
            Drive = $DriveLetter
            FreeSpaceGB = [math]::Round($freeSpaceGB, 2)
            RequiredSpaceGB = $RequiredSpaceGB
            Sufficient = $freeSpaceGB -ge $RequiredSpaceGB
        }
        
        if (-not $result.Sufficient) {
            Write-ScriptLog -Level Warning -Message "Insufficient disk space on $DriveLetter. Required: $RequiredSpaceGB GB, Available: $([math]::Round($freeSpaceGB, 2)) GB"
        }
        
        return $result
    }
    catch {
        Write-ScriptLog -Level Error -Message "Failed to check disk space: $_"
        throw
    }
}

function Test-PathExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [ValidateSet('Container', 'Leaf', 'Any')]
        [string]$PathType = 'Any',
        [switch]$ThrowIfNotFound
    )
    
    $exists = Test-Path -Path $Path -PathType $PathType
    
    if (-not $exists -and $ThrowIfNotFound) {
        $message = if ($PathType -eq 'Container') { "Directory not found: $Path" } 
                   elseif ($PathType -eq 'Leaf') { "File not found: $Path" }
                   else { "Path not found: $Path" }
        throw $message
    }
    
    return $exists
}

function Invoke-GracefulShutdown {
    [CmdletBinding()]
    param(
        [int]$WarningSeconds = 60,
        [string]$WarningMessage = "System will restart in {0} seconds. Please save your work.",
        [scriptblock]$PreShutdownScript,
        [switch]$ShutdownComputer
    )
    
    Write-ScriptLog -Level Warning -Message "Initiating graceful shutdown sequence"
    
    $endTime = (Get-Date).AddSeconds($WarningSeconds)
    
    while ((Get-Date) -lt $endTime) {
        $remaining = [math]::Round(($endTime - (Get-Date)).TotalSeconds)
        
        if ($remaining -le 10 -or $remaining % 30 -eq 0) {
            Write-ScriptLog -Level Info -Message ($WarningMessage -f $remaining)
            
            try {
                $notificationParams = @{
                    Headline = "System Shutdown"
                    Body = ($WarningMessage -f $remaining)
                }
                
                if (Get-Command Show-Notification -ErrorAction SilentlyContinue) {
                    Show-Notification @notificationParams
                }
            }
            catch {
            }
        }
        
        Start-Sleep -Seconds 1
    }
    
    if ($PreShutdownScript) {
        Write-ScriptLog -Level Info -Message "Running pre-shutdown script"
        try {
            & $PreShutdownScript
        }
        catch {
            Write-ScriptLog -Level Error -Message "Pre-shutdown script failed: $_"
        }
    }
    
    if ($ShutdownComputer) {
        Write-ScriptLog -Level Warning -Message "Executing system shutdown"
        Restart-Computer -Force
    }
}

function Get-ScriptStackTrace {
    [CmdletBinding()]
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [int]$MaxFrames = 10
    )
    
    $stackTrace = @()
    
    for ($i = 0; $i -lt $ErrorRecord.ScriptStackTrace.Count -and $i -lt $MaxFrames; $i++) {
        $stackTrace += $ErrorRecord.ScriptStackTrace[$i]
    }
    
    return [PSCustomObject]@{
        ExceptionMessage = $ErrorRecord.Exception.Message
        ExceptionType = $ErrorRecord.Exception.GetType().FullName
        ScriptStackTrace = $stackTrace
        FullyQualifiedErrorId = $ErrorRecord.FullyQualifiedErrorId
        InvocationInfo = if ($ErrorRecord.InvocationInfo) {
            [PSCustomObject]@{
                ScriptName = $ErrorRecord.InvocationInfo.ScriptName
                ScriptLineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
                OffsetInLine = $ErrorRecord.InvocationInfo.OffsetInLine
                Line = $ErrorRecord.InvocationInfo.Line
            }
        } else { $null }
    }
}

function Format-ErrorMessage {
    [CmdletBinding()]
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    $stackTrace = Get-ScriptStackTrace -ErrorRecord $ErrorRecord
    
    $message = "ERROR: $($stackTrace.ExceptionMessage)`n"
    $message += "Type: $($stackTrace.ExceptionType)`n"
    $message += "ID: $($stackTrace.FullyQualifiedErrorId)`n"
    
    if ($stackTrace.InvocationInfo) {
        $message += "Location: $($stackTrace.InvocationInfo.ScriptName):$($stackTrace.InvocationInfo.ScriptLineNumber)`n"
    }
    
    $message += "Stack Trace:`n"
    foreach ($frame in $stackTrace.ScriptStackTrace) {
        $message += "  at $frame`n"
    }
    
    return $message
}

Export-ModuleMember -Function @(
    'Invoke-ScriptBlockWithErrorHandling',
    'Test-PowerShellVersion',
    'Test-AdministrativePrivileges',
    'Test-NetworkConnectivity',
    'Test-DiskSpace',
    'Test-PathExists',
    'Invoke-GracefulShutdown',
    'Get-ScriptStackTrace',
    'Format-ErrorMessage'
)
