# Show-Notification PowerShell Script
## Description
**Show-Notification.ps1** is part of a collection of PowerShell scripts designed to enhance system interaction and user engagement on Windows-based systems. While there are many scripts available for creating Windows toast notifications, this script is not about being the best in every scenario but about fitting specific use cases, particularly those encountered in my workflow. It provides a flexible way to create and display customizable toast notifications, including options for images, interactive buttons, expiration times, and more.

## Features
- **Customizable Notification Templates**: Choose from several notification templates to best suit the message content.
- **Interactive Buttons**: Add actionable buttons to notifications, allowing users to interact directly with the alert.
- **App Logo Integration**: Customize notifications with your application's logo for brand recognition.
- **Silent Mode**: Notifications can be sent silently, without interrupting the user.
- **Expiration Time Setting**: Specify how long the notification should remain visible.

The script is ideal for deployment in scenarios requiring immediate user attention, feedback collection, or as part of a larger automation process.

## Usage
The script accepts various parameters for customization and flexibility. Here are some examples:

**Basic Usage with Default Template:**

```powershell
./Show-Notification.ps1 -ToastTitle "Reminder" -ToastText "Time for a coffee break!"
```
## Using Custom Values and Interactive Buttons:
Define a hashtable for buttons as actions:
```powershell
$buttons = @{
    "Snooze" = "snoozeAction";
    "Dismiss" = "dismissAction"
}
./Show-Notification.ps1 -ToastTitle "Meeting Alert" -ToastText "Your meeting starts in 10 minutes." -Buttons $buttons
```
This will display a notification with "Snooze" and "Dismiss" buttons, providing users with options to interact with the alert.
## Scheduling the Script with Task Scheduler
Automate notification delivery by scheduling this script via the Task Scheduler:
```powershell
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\\path\\to\\Show-Notification.ps1 -ToastTitle 'Reminder' -ToastText 'Time for a coffee break!'"
$Trigger = New-ScheduledTaskTrigger -AtLogon
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -TaskName "CoffeeBreakReminder" -Description "Displays a coffee break reminder notification at user logon."
```
Adjust the script path and parameters according to your needs. This example creates a task that displays a coffee break reminder at every user logon.
## Parameters
- **ToastTitle:** Mandatory. The title of the toast notification.
- **ToastText:** Mandatory. The main content text of the toast notification.
- **TemplateType:** Optional. Specifies the notification template. Default is ToastImageAndText04.
- **ExpirationTime:** Optional. The time in minutes before the notification expires. Default is 1 minute.
- **AppLogo:** Optional. Path to the image file used as the app logo in the notification.
- **Silent:** Optional. If set, the notification will not make a sound.
- **Buttons:** Optional. A hashtable defining the text and actions for interactive buttons within the notification.
## FAQ / Troubleshooting
Q: The notification doesn't appear. What could be wrong?
A: Ensure the script's execution policy permits it to run. Check the paths to any specified images or logos to ensure they are correct and accessible.
## Contributing
Contributions are welcome! If you've identified bugs, have suggestions for new features, or want to improve the script, please fork the repository, make your changes, and submit a pull request.
## Author
Concept and implementation by Cláudio Gonçalves.
