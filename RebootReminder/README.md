# Reboot Reminder PowerShell Script
## Description
RebootReminder.ps1 is a PowerShell script designed to remind users to reboot their system if it hasn't been rebooted within a specified number of days. The script sends a balloon notification to the user. If the system is not rebooted within a specified timeframe, the script will enforce a system reboot.

This script is ideally run with the Windows Task Scheduler on a daily basis to check for the last reboot time.

## Usage
You can run the script with custom parameters or with default values. Here are some examples:

Using default values:
./RebootReminder.ps1 -DaysLimit 7
This will run the script with the default values for HoursLimit (5 hours), LogPath (C:\temp\RebootLog.log), WorkStart (8 AM), and WorkEnd (5 PM).

Using custom values:
./RebootReminder.ps1 -DaysLimit 7 -HoursLimit 4 -LogPath "C:\logs\RebootLog.log" -WorkStart 9 -WorkEnd 18
This will run the script with custom values. The script will enforce a reboot if the computer hasn't been rebooted within 4 hours. It will log the events to C:\logs\RebootLog.log. The script will only send notifications between 9 AM and 6 PM.

## Parameters
DaysLimit: Mandatory parameter. The number of days to check for the last reboot.
HoursLimit: Optional parameter. The number of hours before enforcing a reboot. Default is 5 hours.
LogPath: Optional parameter. The path for the log file. Default is C:\temp\RebootLog.log.
WorkStart: Optional parameter. The start of the workday in 24-hour format. Default is 8.
WorkEnd: Optional parameter. The end of the workday in 24-hour format. Default is 17.
## Author
Concept by Cláudio Gonçalves
