<#
.SYNOPSIS
    Automated Software Deployment Script

.DESCRIPTION
    This PowerShell script is designed to automate the deployment of software 
    across multiple remote computers. It checks for prerequisites, validates 
    environment and paths, handles secure credential management, and performs 
    the software installation if necessary.

    The script uses an MSI file for installation and logs activities for monitoring 
    and troubleshooting.

.PARAMETERS
    $msiFilePath: Path to the MSI installer file on the local system.
    $installerUrl: URL to download the MSI installer.
    $installerPath: Temporary path on remote machines for the installer.
    $logPath: Path for the log file to record deployment details.
    $computers: Array of target computer names for deployment.

.EXAMPLE
    .\DeploymentScript.ps1

    This command runs the script with the predefined parameters in the script.

.NOTES
    Author: Cláudio Gonçalves
    Version: 1.0
    Date: 13/11/2023
    Prerequisites: PowerShell 5.0 or higher, Administrative privileges

#>

# Define global variables
$msiFilePath = "C:\Users\cagv\Downloads\Teams_windows_x64 (1).msi"
$installerUrl = "https://statics.teams.cdn.office.net/production-windows-x64/1.6.00.29964/Teams_windows_x64.msi"
$installerPath = "\\remote\path\installer.msi"
$logPath = "C:\TSTFolder\Logs\deployment.log"
$computers = @("Computer1", "Computer2", "Computer3")

# Check PowerShell version
$minPowershellVersion = 5
if ($PSVersionTable.PSVersion.Major -lt $minPowershellVersion) {
    Write-Host "This script requires PowerShell version $minPowershellVersion or higher."
    #exit # Commented out for testing purposes
}

# Check for administrative privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Information "This script requires administrative privileges."
    #exit # Commented out for testing purposes
}

# Check network connectivity
foreach ($computer in $computers) {
    if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
        Write-Warning "Unable to reach $computer. Please check network connectivity."
        #exit # Commented out for testing purposes
    }
}

# Validate paths
if (-not (Test-Path $msiFilePath)) {
    Write-Warning "MSI file path does not exist: $msiFilePath"
    #exit # Commented out for testing purposes
}

if (-not (Test-Path $logPath)) {
    Write-Warning "Log file path does not exist: $logPath"
    #exit # Commented out for testing purposes
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
    # Add logic to validate the URL (e.g., check format, ensure it uses HTTPS, etc.)
    return $true # Placeholder, replace with actual validation logic
}

# Enhanced validation of paths and URLs
if (-not (Validate-Url $installerUrl)) {
    Write-Warning "Installer URL is not valid or secure: $installerUrl"
    #exit # Commented out for testing purposes
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
    Write-Warning "Failed to retrieve the product code from the MSI file."
    #exit # Commented out for testing purposes
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
            Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE IdentifyingNumber = '$productCode'"
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
