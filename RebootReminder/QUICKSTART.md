# Quick Start Guide - Reboot Reminder

Get Reboot Reminder up and running in minutes.

## Quick Deployment (5 Minutes)

### Option A: Windows Task Scheduler (No Intune)

1. **Copy the script** to your target folder:
   ```powershell
   Copy-Item "RebootReminder.ps1" "C:\Scripts\"
   ```

2. **Run PowerShell as Administrator** and execute:
   ```powershell
   cd C:\Scripts
   .\RebootReminder.ps1 -DaysLimit 7
   ```

3. **Create a scheduled task**:
   ```powershell
   $ScriptPath = "C:\Scripts\RebootReminder.ps1"
   $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -IntuneMode"
   $Trigger = New-ScheduledTaskTrigger -Daily -At 9am
   $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
   Register-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -TaskName "RebootReminder" -Force
   ```

Done! The script will run daily at 9 AM.

---

### Option B: Intune (10 Minutes)

#### Step 1: Prepare Scripts (2 minutes)

Create three files:

1. **RebootReminder.ps1** - Main script (already created)
2. **RebootReminder-Detection.ps1** - Detection script
3. **RebootReminder-Remediation.ps1** - Remediation script

#### Step 2: Upload Detection Script (3 minutes)

1. Go to [Intune Portal](https://endpoint.microsoft.com)
2. Navigate to **Devices** > **Remediations**
3. Click **Create Script Package**
4. **Name**: "Reboot Reminder Detection"
5. Upload `RebootReminder-Detection.ps1`
6. **Run as**: System
7. **Run using 64-bit**: Yes
8. Assign to test group
9. Click **Create**

#### Step 3: Upload Remediation Script (5 minutes)

1. Go to **Devices** > **Remediations**
2. Click **Create Script Package**
3. **Name**: "Reboot Reminder Remediation"
4. Upload `RebootReminder-Remediation.ps1`
5. **Run as**: Logged-on user (important for notifications!)
6. **Run using 64-bit**: Yes
7. **Frequency**: Hourly
8. Assign to test group
9. Click **Create**

Done! Check back in an hour to see compliance status.

---

## Common Use Cases

### Use Case 1: Standard Desktop Management

**Scenario**: Manage desktops with standard security requirements

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 7 -HoursLimit 5
```

**Deployment**: Intune Proactive Remediations with hourly checks

### Use Case 2: Laptop Users

**Scenario**: Laptop users who may be offline or working irregular hours

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 14 -HoursLimit 8
```

**Deployment**: Intune PowerShell script running on logon

### Use Case 3: Post-Patch Tuesday Enforcement

**Scenario**: Force reboots after Patch Tuesday updates

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 3 -HoursLimit 2 -ForceReboot
```

**Deployment**: Scheduled task 4 days after Patch Tuesday

### Use Case 4: Security-Sensitive Environment

**Scenario**: High-security environment requiring frequent reboots

**Configuration**:
```powershell
.\RebootReminder.ps1 -DaysLimit 5 -HoursLimit 4 -WorkStart 7 -WorkEnd 19
```

**Deployment**: Hourly Intune remediation with extended work hours

---

## Testing Your Deployment

### Test in Intune

1. **Create a test group** with 1-2 devices
2. **Deploy to test group only**
3. **Monitor compliance** after deployment
4. **Check logs** on test devices:
   ```powershell
   Get-Content "$env:TEMP\RebootReminder-Intune.log" -Tail 50
   ```

### Test Locally

1. **Simulate non-compliance** by modifying the detection script temporarily:
   ```powershell
   # Change $DaysLimit to 0 for testing
   param([int]$DaysLimit = 0)
   ```

2. **Run the script**:
   ```powershell
   .\RebootReminder.ps1 -DaysLimit 7 -IntuneMode
   ```

3. **Verify notification** appears
4. **Check logs**:
   ```powershell
   Get-Content "$env:USERPROFILE\RebootLog.log" -Tail 50
   ```

---

## Verification Checklist

After deployment, verify the following:

- [ ] Script runs successfully on test devices
- [ ] Toast notifications appear when system is non-compliant
- [ ] Users can dismiss or snooze notifications
- [ ] Logs are being written correctly
- [ ] Compliance reports are being generated
- [ ] Forced reboots work after grace period
- [ ] Weekend skip is working (test on Saturday/Sunday)
- [ ] Work hours filtering is working

---

## Troubleshooting Common Issues

### Issue: Script doesn't run

**Quick Fix**: Check execution policy and permissions
```powershell
Get-ExecutionPolicy -List
# Should allow the script to run
```

### Issue: No notifications appear

**Quick Fix**: Check Windows notification settings
```
Settings > System > Notifications & actions
Ensure "Get notifications from apps" is ON
```

### Issue: Intune shows error

**Quick Fix**: Check Intune logs
```powershell
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" -Tail 100
```

---

## Next Steps

1. **Review the full documentation**:
   - [README.md](README.md) - Complete feature list and documentation
   - [INTUNE_DEPLOYMENT.md](INTUNE_DEPLOYMENT.md) - Detailed Intune deployment guide
   - [CHANGELOG.md](CHANGELOG.md) - Version history and changes

2. **Customize for your environment**:
   - Adjust `DaysLimit` based on your security requirements
   - Set appropriate `HoursLimit` for your users
   - Configure work hours if your team works non-standard hours

3. **Plan your rollout**:
   - Start with a small pilot group
   - Monitor compliance for 1-2 weeks
   - Adjust parameters as needed
   - Roll out to full organization

4. **Set up monitoring**:
   - Check compliance reports regularly
   - Review logs periodically
   - Gather user feedback
   - Adjust parameters based on data

---

## Support Resources

- **Documentation**: See README.md and INTUNE_DEPLOYMENT.md
- **Issues**: Report bugs or request features via GitHub Issues
- **Logs**: Check `$env:USERPROFILE\RebootLog.log` or `$env:TEMP\RebootReminder-Intune.log`

---

## Getting Help

If you encounter issues:

1. **Check the logs** first - they usually contain the answer
2. **Review troubleshooting section** in the main documentation
3. **Search existing issues** on GitHub
4. **Create a new issue** with:
   - Windows version
   - PowerShell version
   - Script parameters used
   - Error message or log excerpt
   - Deployment method (Intune/Task Scheduler/SCCM)

---

**Ready to deploy?** Follow Option A (Task Scheduler) or Option B (Intune) above.

**Need more details?** Check out the full [README.md](README.md) or [INTUNE_DEPLOYMENT.md](INTUNE_DEPLOYMENT.md).
