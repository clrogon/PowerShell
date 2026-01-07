<#
.SYNOPSIS
    Centralized configuration management for PowerShell scripts

.DESCRIPTION
    Provides unified configuration management across all scripts with support for
    default configurations, environment-specific overrides, and persistence.

.NOTES
    Version: 1.0
    Author: Cláudio Gonçalves
#>

function Initialize-ScriptConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$env:ProgramData\PowerShellScripts\ScriptConfig.xml",
        [hashtable]$DefaultConfig
    )
    
    $configDir = Split-Path -Parent $ConfigPath
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $script:Configuration = if (Test-Path $ConfigPath) {
        Import-Clixml $ConfigPath
    } else {
        @{}
    }
    
    if ($DefaultConfig) {
        foreach ($key in $DefaultConfig.Keys) {
            if (-not $script:Configuration.ContainsKey($key)) {
                $script:Configuration[$key] = $DefaultConfig[$key]
            }
        }
    }
    
    Save-ScriptConfiguration -ConfigPath $ConfigPath
    return $script:Configuration
}

function Get-ScriptConfiguration {
    [CmdletBinding()]
    param(
        [string]$Key,
        $DefaultValue = $null
    )
    
    if (-not $script:Configuration -or $script:Configuration.Count -eq 0) {
        Initialize-ScriptConfiguration
    }
    
    if ($Key) {
        if ($script:Configuration.ContainsKey($Key)) {
            return $script:Configuration[$Key]
        } else {
            return $DefaultValue
        }
    } else {
        return $script:Configuration
    }
}

function Set-ScriptConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key,
        [Parameter(Mandatory=$true)]
        $Value,
        [string]$ConfigPath = "$env:ProgramData\PowerShellScripts\ScriptConfig.xml"
    )
    
    if (-not $script:Configuration -or $script:Configuration.Count -eq 0) {
        Initialize-ScriptConfiguration -ConfigPath $ConfigPath
    }
    
    $script:Configuration[$Key] = $Value
    Save-ScriptConfiguration -ConfigPath $ConfigPath
}

function Save-ScriptConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$env:ProgramData\PowerShellScripts\ScriptConfig.xml"
    )
    
    if ($script:Configuration) {
        $script:Configuration | Export-Clixml -Path $ConfigPath -Force
    }
}

function Get-DefaultConfiguration {
    return @{
        Logging = @{
            DefaultPath = "$env:ProgramData\PowerShellScripts\Logs"
            MaxSize = 10MB
            RetentionDays = 30
            Level = "Info"
            EventLogName = "Application"
            EventLogSource = "PowerShellScripts"
        }
        Notifications = @{
            SMTPServer = "smtp.company.com"
            SMTPPort = 587
            FromAddress = "noreply@company.com"
            UseSSL = $true
            QuietHours = $true
            QuietStart = "18:00"
            QuietEnd = "08:00"
        }
        Deployment = @{
            Stages = @('Pilot', 'Phase1', 'Phase2', 'Production')
            SuccessThreshold = 0.9
            WarningMinutes = @(60, 30, 15, 5)
            MaxRetries = 3
        }
        Security = @{
            RequireSSL = $true
            ValidateCertificates = $true
            MaxLoginAttempts = 3
            SessionTimeoutMinutes = 30
        }
        Performance = @{
            MaxConcurrentOperations = 10
            TimeoutSeconds = 300
            RetryDelaySeconds = 5
        }
    }
}
