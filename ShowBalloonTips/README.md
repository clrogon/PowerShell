# Show Balloon Tip Script
## Deprecation Notice
This script is deprecated. Balloon tip notifications are not recommended on modern Windows versions. Migration path: use Show-Notification.ps1 for modern toast notifications with templates, scheduling, and user preferences.
See Show-Notification/README.md for details and usage.
## Description
ShowBalloonTip.ps1 is a fun PowerShell script that displays a balloon tip in the system tray. Balloon tips are a great way to display non-intrusive notifications to users. This script can be used to learn how to create and use balloon tips in your own scripts.

This script might seem simple, but it has the potential to greatly improve the functionality of other scripts, such as the RebootReminder.ps1 script in this repository. By incorporating balloon tips, you can provide clear and immediate feedback to users, improving the overall user experience.

## Usage
You can run the script with the following parameters:

- Title: The title of the balloon tip. This parameter is mandatory.
- Text: The text of the balloon tip. This parameter is mandatory.
- Icon: The icon of the balloon tip. This parameter is optional with a default value of 'Info'.
- Timeout: The time (in milliseconds) the balloon tip is displayed. This parameter is optional with a default value of 10000 (10 seconds).
Here are a couple of examples:

### Basic usage:

```powershell
Show-BalloonTip -Title 'Tip from Guy' -Text 'Look at me!'
```
### Using optional parameters:
```powershell
Show-BalloonTip -Title 'Tip from Guy' -Text 'Look at me!' -Icon Error -Timeout 20000
```
This will display a balloon tip with an error icon that stays on the screen for 20 seconds.

## Author
Script curated by Cláudio Gonçalves
