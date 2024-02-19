# PowerShell Scripts Repository

## Description
Welcome to my PowerShell Scripts Repository, a personal collection crafted to streamline and enhance system administration tasks. Each script, born from daily challenges and insights, is tailored to automate or simplify operations, significantly boosting efficiency and reducing errors. This repository is not just a toolset but a reflection of practical, hands-on experience designed to empower fellow administrators with solutions that have been tested in the trenches of IT management.

## Disclaimer
> [!IMPORTANT]
> **Important Notice:** The PowerShell scripts within this repository are provided "as is", with no guarantees. Your use of these scripts is solely at your own discretion and risk. It is strongly recommended to thoroughly test each script in a controlled, non-production environment before incorporating them into your regular workflow. This step ensures compatibility and prevents any unintended consequences in your systems or operations.

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
`Find-DuplicateFiles.ps1` is a robust PowerShell script aimed at identifying and handling duplicate files within a given directory. The script uses hashing algorithms like MD5, SHA1, or SHA256 to identify duplicates. It offers a range of options such as exclusion of specific directories and file types, user confirmation for action, and more. [Read more here](Find-DuplicateFiles/README.md).

### 6. Deployment Script
`DeploymentScript.ps1` is a versatile PowerShell script designed for automating the deployment of software using MSI files across multiple remote computers. It handles various administrative tasks such as checking system prerequisites, validating network connections, managing credentials securely, and logging the deployment process. [Read more here](DeploymentScript/README.md).

### 7. USB Port and Storage Card Management Tool
`USBManagementTool.ps1` is a PowerShell script designed to enable, disable, and monitor the status of USB storage device access and storage card usage on Windows systems. This tool provides a graphical user interface (GUI) for easy interaction and requires administrative privileges for operation. [Read more here](USBPortManagement/README.md).

## Usage
Each script in this repository is designed for standalone use, tailored to specific system administration tasks. For detailed guidance on deployment and customization, refer to the README files accompanying each script. These documents offer step-by-step instructions, ensuring you can leverage the full potential of each tool efficiently.

## Contribution
We warmly welcome contributions to enrich this repository. If you've developed a script that can benefit the system administration community, please share it with us through a pull request. We ask that your submissions include comprehensive documentation, covering usage, setup, and any prerequisites, to assist others in seamlessly integrating your solutions.

## Author Note
"Curated with care by Cláudio Gonçalves, this repository reflects a commitment to sharing knowledge and tools that make the demanding role of a system administrator a bit easier. Each script is a product of practical experience and is intended to offer a helping hand to peers in the IT field."
