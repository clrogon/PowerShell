# PowerShell Scripts Repository
## Description
Welcome to the PowerShell Scripts Repository. This repository is a collection of scripts that assist me in my daily tasks as a System Administrator. Each script is designed to automate or simplify a particular task, making my work more efficient and less prone to errors.
## Scripts
Here are the scripts currently in this repository:
### 1. Reboot Reminder
`RebootReminder.ps1` is a PowerShell script designed to remind users to reboot their system if it hasn't been rebooted within a specified number of days. The script sends a balloon notification to the user, and if the system isn't rebooted within a specified timeframe, it enforces a system reboot. [Read more here](RebootReminder/README.md).
### 2. Show Balloon Tips
`ShowBalloonTips.ps1` is a PowerShell script designed to display balloon tips to the user. This script can be used to show notifications, alerts, or reminders to the user. [Read more here](ShowBalloonTips/README.md).
### 3. Find Empty Folders
`Find-EmptyFolders.ps1` is a robust PowerShell script that identifies and logs all empty directories within the given folder path. It also logs any encountered errors and allows for control of log verbosity. [Read more here](FindEmptyFolders/README.md).
### 4. Clear MS Teams Cache
`ClearTeamsCache.ps1` is a PowerShell script designed to clear the Microsoft Teams cache and restart the application. The script aims to improve Microsoft Teams performance by removing specific cache folders. It also performs checks for administrative rights, disk space, and network connectivity, and logs these events. [Read more here](ClearTeamsCache/README.md).
### 5. Find Duplicate Files
`Find-DuplicateFiles.ps1` is a robust PowerShell script aimed at identifying and handling duplicate files within a given directory. The script uses hashing algorithms like MD5, SHA1, or SHA256 to identify duplicates. It offers a range of options such as exclusion of specific directories and file types, user confirmation for action, and more.[Read more here](Find-DuplicateFiles/README.md).
### 6. Deployment Script
`DeploymentScript.ps1` is a versatile PowerShell script designed for automating the deployment of software using MSI files across multiple remote computers. It handles various administrative tasks such as checking system prerequisites, validating network connections, managing credentials securely, and logging the deployment process.[Read more here](DeploymentScript/README.md).

## Usage
Each script can be used individually according to your needs. You can find specific instructions on how to use each script in their respective README files.

## Contribution
Feel free to contribute to this repository by submitting pull requests. Please ensure your scripts are well-documented, especially if they require specific setup or usage instructions.

## Author
Scripts curated by Cláudio Gonçalves
