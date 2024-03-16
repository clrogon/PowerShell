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
```
This runs the script with the predefined parameters.

### Using custom values:

```powershell
./DeploymentScript.ps1 -msiFilePath "C:\Custom\installer.msi" -installerUrl "https://example.com/custominstaller.msi" -logPath "C:\CustomLogs\deployment.log"
```
## Contributing
Contributions are welcomed and appreciated. If you have improvements or bug fixes, please follow these steps:

## Fork the repository.
Create a new branch for your changes.
Develop and test your changes.
Submit a pull request with a detailed description of your contribution.
## FAQ / Troubleshooting
Q: What if the script doesn't execute on a remote computer?

A: Ensure you have administrative access to the remote machine and that the machine is reachable over the network.

Q: How can I troubleshoot log file errors?

A: Check the logPath parameter to ensure it's correctly pointing to a writable location.
## Author
Concept and development by Claudio Gonçalves.
