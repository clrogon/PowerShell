# ClearTeamsCache PowerShell Script
## Description
ClearTeamsCache.ps1 is a PowerShell script designed to clear the Microsoft Teams cache and restart the application. The script aims to improve Microsoft Teams performance by removing specific cache folders. It also performs checks for administrative rights, disk space, and network connectivity, and logs these events.

This script can be run manually or scheduled to run automatically, depending on the organization's needs.

## Usage
You can run the script with custom parameters or with default values. Here are some examples:
-logFolder: Optional parameter. Specifies the folder where logs will be saved. Default is C:\TSTFolder\Logs.
-Force: Optional switch. Forces the script to continue even if it encounters issues.

### Using default values::

```powershell
./ClearTeamsCache.ps1
```
This will run the script with the default log folder located at C:\TSTFolder\Logs.

### Using custom values:
```powershell
./ClearTeamsCache.ps1 -logFolder "C:\CustomLogs" -Force
```
This will run the script with a custom log folder and will force the script to proceed even if it encounters issues like low disk space or lack of network connectivity.

## Author
Concept and development by Claudio Gonçalves.
