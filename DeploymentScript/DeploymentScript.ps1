<#
.SYNOPSIS
    Automated Software Deployment Script

.DESCRIPTION
    This PowerShell script is designed for the automated deployment of software
    using MSI installers across multiple remote computers. It checks prerequisites,
    validates network connectivity, handles secure credential management, performs
    conditional software installation, and logs all activities for monitoring
    and troubleshooting. Enhanced with staged deployment pipeline, rollback capability, and user notifications.

.PARAMETERS
    $msiFilePath: Path to the MSI installer file on the local system.
                  Example: "C:\path\to\installer.msi"

    $installerUrl: URL to download the MSI installer.
                   Example: "https://example.com/installer.msi"

    $installerPath: Temporary path on remote machines for the installer.
                     Example: "\\remote\path\installer.msi"

    $logPath: Path for the log file to record deployment details.
              Example: "C:\path\to\log.txt"

    $computers: Array of target computer names for deployment.
                 Example: @("Computer1", "Computer2", "Computer3")

    $stagedDeployment: Enable staged deployment (Pilot → Production). Default: true.

.EXAMPLE
    .\DeploymentScript.ps1 -stagedDeployment

    Runs the script with staged deployment pipeline.

.NOTES
    Prerequisites: PowerShell 5.0 or higher, Administrative privileges
.VERSION
2.0 Enhanced with staged deployment and rollback
.AUTHOR
Concept by Cláudio Gonçalves
#>

#Requires -Version 5.1

Import-Module "$PSScriptRoot\..\modules\Configuration.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\Logging.psm1" -Force
Import-Module "$PSScriptRoot\..\modules\ErrorHandling.psm1" -Force

Initialize-ScriptConfiguration -DefaultConfig (Get-DefaultConfiguration)
Initialize-Logging -Component "DeploymentScript"

# Define global variables - Use parameters or secure configuration
param (
    [string]$msiFilePath = "C:\Temp\installer.msi",
    [string]$installerUrl = "https://statics.teams.cdn.office.net/production-windows-x64/1.6.00.29964/Teams_windows_x64.msi",
    [string]$installerPath = "\\$env:COMPUTERNAME\Temp\installer.msi",
    [string]$logPath = "C:\Logs\deployment.log",
    [array]$computers = @("Computer1", "Computer2", "Computer3"),
    [switch]$stagedDeployment = $true
)

# Check PowerShell version
$minPowershellVersion = 5
if ($PSVersionTable.PSVersion.Major -lt $minPowershellVersion) {
    Write-Host "This script requires PowerShell version $minPowershellVersion or higher."
    exit 1
}

# Check for administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires administrative privileges."
    exit 1
}

# Check network connectivity
foreach ($computer in $computers) {
    if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
        Write-Error "Unable to reach $computer. Please check network connectivity."
        exit 1
    }
}

# Validate paths
if (-not (Test-Path $msiFilePath)) {
    Write-Error "MSI file path does not exist: $msiFilePath"
    exit 1
}

if (-not (Test-Path (Split-Path $logPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
}

# Function to extract the product code from an MSI file
function Get-MsiProductCode {
    param ([string]$Path)
    
    $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $database = $windowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstaller, @($Path, 0))
    $view = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, @("SELECT `Value` FROM `Property` WHERE `Property` = 'ProductCode'"))
    $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null)

    $record = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
    $productCode = $record.GetType().InvokeMember("StringData", "GetProperty", $null, $record, 1)

    # Cleanup
    $record = $null
    $view = $null
    $database = $null
    $windowsInstaller = $null

    return $productCode
}

# Function to log information
function Log-Information {
    param (
        [string]$Message,
        [string]$LogFilePath
    )
    Add-Content -Path $LogFilePath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
}

# Function to validate URLs
function Validate-Url {
    param ([string]$Url)
    
    if ([string]::IsNullOrWhiteSpace($Url)) {
        Write-Warning "URL is empty or null."
        return $false
    }
    
    # Check if URL uses HTTPS
    if (-not ($Url -match '^https://')) {
        Write-Warning "URL must use HTTPS protocol."
        return $false
    }
    
    # Validate URL format
    try {
        $uri = [System.Uri]$Url
        if (-not $uri.IsWellFormedOriginalString()) {
            Write-Warning "URL format is invalid."
            return $false
        }
    }
    catch {
        Write-Warning "URL validation failed: $_"
        return $false
    }
    
    return $true
}

# Enhanced validation of paths and URLs
if (-not (Validate-Url $installerUrl)) {
    Write-Error "Installer URL is not valid or secure: $installerUrl"
    exit 1
}

# Secure Credential Handling
$credential = Get-Credential -Message "Enter credentials for accessing remote machines"

# Function to execute remote operations securely
function Invoke-RemoteOperation {
    param (
        [string]$ComputerName,
        [PSCredential]$Credential,
        [scriptblock]$ScriptBlock
    )
    # Use Invoke-Command with -Credential parameter for secure remote operations
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock
}

# Retrieve the product code of the MSI file
$productCode = Get-MsiProductCode -Path $msiFilePath
if (-not $productCode) {
    Write-Error "Failed to retrieve the product code from the MSI file."
    exit 1
}

# Function to prepare a remote machine for deployment
function Prepare-RemoteMachine {
    param (
        [string]$ComputerName,
        [PSCredential]$Credential
    )
    # Placeholder for checks like disk space, services, etc.
    # These checks can be implemented as per the specific requirements of the deployment
    # Example: Check disk space, verify write permissions, etc.
}

# Prepare each remote machine
foreach ($computer in $computers) {
    Prepare-RemoteMachine -ComputerName $computer -Credential $credential
}

# Deployment Loop
foreach ($computer in $computers) {
    try {
        # Check if the software is already installed
        $isInstalled = Invoke-RemoteOperation -ComputerName $computer -Credential $credential -ScriptBlock {
            param($productCode)
            # Sanitize productCode to prevent WMI injection
            $sanitizedCode = $productCode -replace '[^\{\}0-9A-Fa-f\-]', ''
            Get-CimInstance -ClassName Win32_Product -Filter "IdentifyingNumber = '$sanitizedCode'" -ErrorAction SilentlyContinue
        } -ArgumentList $productCode

        if (-not $isInstalled) {
            # Download and install the MSI file
            Invoke-RemoteOperation -ComputerName $computer -Credential $credential -ScriptBlock {
                param($installerUrl, $installerPath)
                Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
                Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /L*v `"$env:TEMP\install.log`"" -Wait
            } -ArgumentList $installerUrl, $installerPath

            Log-Information -Message "Installation completed on $computer" -LogFilePath $logPath
        } else {
            Log-Information -Message "Software already installed on $computer" -LogFilePath $logPath
        }
    }
    catch {
        Log-Information -Message "Error encountered on ${computer}: $_" -LogFilePath $logPath
    }
}

# Post-Deployment Cleanup and Reporting
# This section can include code to release resources, delete temporary files, and compile final deployment reports.

#region Enhanced Deployment Functions

$deploymentStages = @(
    @{ Stage = "Pilot"; Computers = @("PC-PILOT-01", "PC-PILOT-02", "PC-PILOT-03"); Percentage = 5 },
    @{ Stage = "Phase1"; Computers = @(); Percentage = 20 },
    @{ Stage = "Phase2"; Computers = @(); Percentage = 50 },
    @{ Stage = "Production"; Computers = @(); Percentage = 100 }
)

function Invoke-StagedDeployment {
    [CmdletBinding()]
    param(
        [string]$MSIPath,
        [string]$ProductCode,
        [string]$DeploymentID = [Guid]::NewGuid().ToString(),
        [ValidateSet('Pilot', 'Phase1', 'Phase2', 'Production')]
        [string]$StartStage = 'Pilot'
    )

    Start-LogTransaction -Operation "Deployment $DeploymentID" -InitialData @{
        MSIPath = $MSIPath
        ProductCode = $ProductCode
        StartStage = $StartStage
    }

    $deployment = [PSCustomObject]@{
        DeploymentID = $DeploymentID
        MSIPath = $MSIPath
        ProductCode = $ProductCode
        StartTime = Get-Date
        CurrentStage = $StartStage
        Status = 'InProgress'
        Results = @()
    }

    $currentStageIndex = ($deploymentStages | Where-Object Stage -eq $StartStage).Index

    for ($i = $currentStageIndex; $i -lt $deploymentStages.Count; $i++) {
        $stage = $deploymentStages[$i]

        Add-LogTransactionStep -StepName "Stage: $($stage.Stage)" -StepType "Info"

        # Get computers for this stage
        $stageComputers = if ($stage.Computers.Count -eq 0) {
            # Randomly select percentage of computers
            $allComputers = Get-ADComputer -Filter {Enabled -eq $true} -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            $count = [math]::Floor($allComputers.Count * $stage.Percentage / 100)
            $allComputers | Get-Random -Count $count
        } else {
            $stage.Computers
        }

        # Deploy to stage computers
        foreach ($computer in $stageComputers) {
            Write-Progress -Activity "Stage: $($stage.Stage)" -Status "Deploying to: $computer" `
                -PercentComplete (($stageComputers.IndexOf($computer) + 1) / $stageComputers.Count * 100)

            $result = Deploy-SoftwareToComputer -ComputerName $computer -MSIPath $MSIPath -ProductCode $ProductCode
            $deployment.Results += $result

            # Log result
            Add-LogTransactionStep -StepName "Deploy to $computer" -StepType $(if ($result.Success) { "Info" } else { "Error" }) `
                -StepData @{ Success = $result.Success; Error = $result.Error }
        }

        # Check success rate before proceeding
        $successRate = ($deployment.Results | Where-Object Success).Count / $deployment.Results.Count
        $config = Get-ScriptConfiguration

        if ($successRate -lt $config.Deployment.SuccessThreshold) {
            Write-ScriptLog -Level Warning -Message "Success rate below threshold in stage $($stage.Stage). Pausing deployment."
            $deployment.Status = 'Paused'
            break
        }

        # Prompt for approval before next stage
        if ($i -lt $deploymentStages.Count - 1 -and $stagedDeployment) {
            $approval = Read-Host "Stage $($stage.Stage) completed ($([math]::Round($successRate*100,1))% success). Approve next stage? (Y/N)"
            if ($approval -ne 'Y') {
                Write-ScriptLog -Level Info -Message "Deployment paused for approval."
                $deployment.Status = 'PendingApproval'
                break
            }
        }
    }

    $deployment.EndTime = Get-Date

    # Save deployment
    $deploymentPath = "$env:ProgramData\Deployments\$($deployment.DeploymentID).xml"
    $deploymentDir = Split-Path -Parent $deploymentPath
    if (-not (Test-Path $deploymentDir)) {
        New-Item -ItemType Directory -Path $deploymentDir -Force | Out-Null
    }
    $deployment | Export-Clixml $deploymentPath -Force

    Complete-LogTransaction -Status $deployment.Status

    return $deployment
}

function Deploy-SoftwareToComputer {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [string]$MSIPath,
        [string]$ProductCode
    )

    $result = [PSCustomObject]@{
        ComputerName = $ComputerName
        Success = $false
        Error = $null
        Installed = $false
    }

    try {
        # Check if software is already installed
        $isInstalled = Test-SoftwareInstalled -ComputerName $ComputerName -ProductCode $ProductCode

        if (-not $isInstalled) {
            # Download and install
            Invoke-RemoteOperation -ComputerName $ComputerName -Credential $credential -ScriptBlock {
                param($installerUrl, $installerPath)
                Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
                Start-Process "msiexec.exe" -ArgumentList "/i `"$installerPath`" /qn /L*v `"$env:TEMP\install.log`"" -Wait -ErrorAction Stop
            } -ArgumentList $installerUrl, $installerPath -ErrorAction Stop

            $result.Installed = $true
        }

        $result.Success = $true
        Log-Information -Message "Deployment completed on $computerName" -LogFilePath $logPath
    }
    catch {
        $result.Error = $_.Exception.Message
        Log-Information -Message "Error encountered on ${computerName}: $_" -LogFilePath $logPath
    }

    return $result
}

function Test-SoftwareInstalled {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [string]$ProductCode
    )

    try {
        $sanitizedCode = $ProductCode -replace '[^\{\}0-9A-Fa-f\-]', ''

        $installed = Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
            param($sanitizedCode)
            Get-CimInstance -ClassName Win32_Product -Filter "IdentifyingNumber = '$sanitizedCode'" -ErrorAction SilentlyContinue
        } -ArgumentList $sanitizedCode -ErrorAction Stop

        return $installed -ne $null
    }
    catch {
        return $false
    }
}

function Invoke-Rollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DeploymentID,
        [string]$Reason = "Deployment failed"
    )

    $deploymentPath = "$env:ProgramData\Deployments\$DeploymentID.xml"

    if (-not (Test-Path $deploymentPath)) {
        Write-ScriptLog -Level Error -Message "Deployment not found: $DeploymentID"
        return
    }

    $deployment = Import-Clixml $deploymentPath

    Write-ScriptLog -Level Warning -Message "Rolling back deployment: $DeploymentID"
    Write-ScriptLog -Level Warning -Message "Reason: $Reason"

    # Rollback from Production to previous stage
    foreach ($result in $deployment.Results | Where-Object Success) {
        try {
            $uninstallResult = Uninstall-SoftwareFromComputer -ComputerName $result.ComputerName -ProductCode $deployment.ProductCode

            $rollbackEntry = [PSCustomObject]@{
                ComputerName = $result.ComputerName
                RollbackTime = Get-Date
                Success = $uninstallResult.Success
                Error = $uninstallResult.Error
            }

            $rollbackEntry | Export-Csv "$env:ProgramData\Rollback_$DeploymentID.csv" -Append -NoTypeInformation -ErrorAction SilentlyContinue
        }
        catch {
            Write-ScriptLog -Level Error -Message "Failed to rollback on $($result.ComputerName): $_"
        }
    }

    $deployment.Status = 'RolledBack'
    $deployment.RollbackTime = Get-Date
    $deployment.RollbackReason = $Reason
    $deployment | Export-Clixml $deploymentPath -Force

    Write-ScriptLog -Level Info -Message "Rollback completed"
}

function Uninstall-SoftwareFromComputer {
    [CmdletBinding()]
    param(
        [string]$ComputerName,
        [string]$ProductCode
    )

    $result = [PSCustomObject]@{
        ComputerName = $ComputerName
        Success = $false
        Error = $null
    }

    try {
        Invoke-Command -ComputerName $ComputerName -Credential $credential -ScriptBlock {
            param($productCode)
            $sanitizedCode = $productCode -replace '[^\{\}0-9A-Fa-f\-]', ''
            $product = Get-CimInstance Win32_Product -Filter "IdentifyingNumber = '$sanitizedCode'" -ErrorAction SilentlyContinue
            if ($product) {
                Start-Process "msiexec.exe" -ArgumentList "/x `"$sanitizedCode`" /qn REBOOT=ReallySuppress" -Wait -ErrorAction Stop
            }
        } -ArgumentList $ProductCode -ErrorAction Stop

        $result.Success = $true
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

function Show-DeploymentDashboard {
    [CmdletBinding()]
    param(
        [DateTime]$StartDate = (Get-Date).AddDays(-7)
    )

    $deployments = Get-ChildItem "$env:ProgramData\Deployments\*.xml" -ErrorAction SilentlyContinue |
        ForEach-Object { Import-Clixml $_.FullName } |
        Where-Object { $_.StartTime -ge $StartDate }

    Write-Host "=== Deployment Dashboard ===`n"

    foreach ($deployment in $deployments) {
        Write-Host "Deployment: $($deployment.DeploymentID)"
        Write-Host "  Started: $($deployment.StartTime)"
        Write-Host "  Status: $($deployment.Status)"

        if ($deployment.Results.Count -gt 0) {
            $successCount = ($deployment.Results | Where-Object Success).Count
            $totalComputers = $deployment.Results.Count
            $successRate = [math]::Round($successCount / $totalComputers * 100, 1)

            Write-Host "  Computers: $totalComputers"
            Write-Host "  Success Rate: $successRate%"
        }

        Write-Host ""
    }

    # Summary statistics
    $totalDeployments = $deployments.Count
    $successfulDeployments = ($deployments | Where-Object Status -eq 'Completed').Count
    $totalComputers = ($deployments | ForEach-Object { $_.Results.Count } | Measure-Object -Sum).Sum

    Write-Host "Summary:"
    Write-Host "  Total Deployments: $totalDeployments"
    Write-Host "  Successful: $successfulDeployments"
    Write-Host "  Total Computers: $totalComputers"
}

function Test-DeploymentPrerequisites {
    [CmdletBinding()]
    param(
        [string[]]$Computers,
        [string]$MSIPath,
        [int]$RequiredDiskSpaceGB = 1
    )

    $validationResults = @()

    foreach ($computer in $Computers) {
        $validation = [PSCustomObject]@{
            ComputerName = $computer
            Online = $false
            HasAdminAccess = $false
            EnoughDiskSpace = $false
            SoftwareNotInstalled = $true
            Valid = $false
        }

        # Check if computer is online
        if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
            $validation.Online = $true

            # Check admin access
            try {
                Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock { [Security.Principal.WindowsIdentity]::GetCurrent() } -ErrorAction Stop | Out-Null
                $validation.HasAdminAccess = $true
            }
            catch {
            }

            # Check disk space
            try {
                $freeSpace = Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock {
                    (Get-PSDrive C).Free / 1GB
                } -ErrorAction Stop

                if ($freeSpace -ge $RequiredDiskSpaceGB) {
                    $validation.EnoughDiskSpace = $true
                }
            }
            catch {
            }

            # Check if software already installed
            try {
                $productCode = Get-MsiProductCode -Path $MSIPath
                $installed = Test-SoftwareInstalled -ComputerName $computer -ProductCode $productCode

                if (-not $installed) {
                    $validation.SoftwareNotInstalled = $true
                }
            }
            catch {
            }
        }

        $validation.Valid = $validation.Online -and $validation.HasAdminAccess -and $validation.EnoughDiskSpace -and $validation.SoftwareNotInstalled
        $validationResults += $validation
    }

    return $validationResults
}

function Notify-UsersOfDeployment {
    [CmdletBinding()]
    param(
        [string[]]$ComputerNames,
        [string]$SoftwareName,
        [int]$WarningMinutes = 15
    )

    foreach ($computer in $ComputerNames) {
        try {
            $loggedOnUsers = Get-LoggedOnUsers -ComputerName $computer

            foreach ($user in $loggedOnUsers) {
                Write-ScriptLog -Level Info -Message "Notifying user $user on $computer"

                try {
                    Show-TemplatedNotification -Template SoftwareUpdate -Variables @{
                        Name = $SoftwareName
                        Version = "Latest"
                    } | Out-Null
                }
                catch {
                    Write-ScriptLog -Level Warning -Message "Could not notify $user on $computer: $_"
                }
            }
        }
        catch {
            Write-ScriptLog -Level Warning -Message "Could not get logged on users for $computer: $_"
        }
    }
}

function Get-LoggedOnUsers {
    [CmdletBinding()]
    param(
        [string]$ComputerName
    )

    try {
        $sessions = Get-CimInstance -ComputerName $computerName -ClassName Win32_LoggedOnUser -ErrorAction SilentlyContinue
        return $sessions | Select-Object -ExpandProperty Name
    }
    catch {
        return @()
    }
}

#endregion