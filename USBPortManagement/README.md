# USB Port and Storage Card Management Tool

## Overview
The USB Port and Storage Card Management Tool is a PowerShell script designed to enable, disable, and monitor the status of USB storage device access and storage card usage on Windows systems. This tool provides a graphical user interface (GUI) for easy interaction and requires administrative privileges for operation.

## Features
- **Enable/Disable USB Storage**: Quickly enable or disable access to USB storage devices.
- **Enable/Disable Storage Card**: Manage access to storage cards with a simple click.
- **Dynamic Status Updates**: View real-time status of USB and storage card access directly in the GUI.
- **Toast Notifications**: Receive immediate status updates upon script startup via toast notifications.
- **Event Logging**: Actions and errors are logged in the Windows Event Log for auditing and troubleshooting.

## Prerequisites
- Windows 10 or Windows 11
- PowerShell 5.1 or higher
- Administrative privileges

## Installation
No installation is required. Download the `USBManagementTool.ps1` script and run it on your Windows system.

## Usage
1. Open PowerShell as an administrator.
2. Navigate to the directory containing `USBManagementTool.ps1`.
3. Execute the script:
   ```powershell
   .\USBManagementTool.ps1
4. Use the GUI to enable/disable USB storage and storage cards. The current status is displayed and updated dynamically.

## Logging
The tool logs all actions and errors to the Windows Event Log under the "Application" log. This can be viewed using the Event Viewer (eventvwr.msc).

## Versioning
1.1: Added toast notifications and dynamic status monitoring.
## Author
Claudio Gonçalves - Feedback and suggestions are welcome.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments
Feel free to customize this `README.md` file as needed, including updating the contact information, adding a section for known issues or FAQs, or providing more detailed instructions on using the tool.
