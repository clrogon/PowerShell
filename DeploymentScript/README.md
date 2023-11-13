# DeploymentScript PowerShell Script

## Description
`DeploymentScript.ps1` is a versatile PowerShell script designed for automating the deployment of software using MSI files across multiple remote computers. The script facilitates various administrative tasks such as checking system prerequisites, validating network connections, managing credentials securely, and logging the deployment process. It supports custom configurations for targeted deployment, enhancing efficiency and control for system administrators.

## Usage

The script allows execution with either default parameters or custom options for specific deployment needs.

### Parameters:
- `msiFilePath`: Path to the MSI installer file. Default is 'C:\path\to\installer.msi'.
- `installerUrl`: URL to download the MSI installer. Example: 'https://example.com/installer.msi'.
- `installerPath`: Temporary path on remote machines for the installer. Example: '\\remote\path\installer.msi'.
- `logPath`: Path for the log file to record deployment details. Default is '.\deployment.log'.
- `computers`: An array of target computer names for deployment.

### Using default values:

```powershell
./DeploymentScript.ps1
