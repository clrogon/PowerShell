# Find Empty Folders Script
## Description
Find-EmptyFolders.ps1 is a robust PowerShell script designed to find and log all empty directories in the specified folder path. This can be particularly useful when trying to clean up a file system, or even for auditing purposes.

Beyond its primary function, this script has been enhanced with features such as error logging and verbosity control, providing a comprehensive tool for system administrators and IT professionals.

## Usage
You can run the script with the following parameters:

- FolderPath: The directory path to be scanned for empty directories. This parameter is mandatory.
- LogFile: The file path to which errors will be logged. This parameter is optional with a default value of 'C:\TSTFolder\Logs\EmptyFolders_log.log'.
- EmptyFoldersLog: The file path to which empty directories will be logged. This parameter is optional with a default value of 'C:\TSTFolder\Logs\EmptyFolders_report.log'.
- LogLevel: Controls the level of verbosity in logging. Accepted values: 'Error', 'Verbose'. This parameter is optional with a default value of 'Error'.

### Basic usage:

```powershell
Find-EmptyFolders -FolderPath 'C:\TestDirectory'
```
### Using optional parameters:
```powershell
Find-EmptyFolders -FolderPath 'C:\TestDirectory' -LogFile 'C:\Logs\Errors.log' -EmptyFoldersLog 'C:\Logs\Empty.log' -LogLevel 'Verbose'
```
This will scan the C:\TestDirectory directory for empty folders, log any errors to 'C:\Logs\Errors.log', log empty directories to 'C:\Logs\Empty.log', and set the verbosity level to 'Verbose'.

## Author
Script curated by Cláudio Gonçalves

