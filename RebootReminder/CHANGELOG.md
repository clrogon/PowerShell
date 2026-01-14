# Reboot Reminder Changelog

All notable changes to the RebootReminder.ps1 script will be documented in this file.

## [6.0.0] - 2025-01-14

### Completely Rewritten for Windows 11 and Intune Compatibility

#### Major Changes
- **Full Windows 11 Compatibility**
  - Modern toast notifications using Windows.UI.Notifications
  - Native Windows 11 notification support
  - Enhanced visual presentation

- **Intune Proactive Remediations Support**
  - Dedicated detection script (`RebootReminder-Detection.ps1`)
  - Dedicated remediation script (`RebootReminder-Remediation.ps1`)
  - Exit code-based compliance detection
  - Works in both SYSTEM and user context

- **New Deployment Methods**
  - Intune Proactive Remediations
  - Intune PowerShell Scripts
  - Intune Win32 Apps
  - Windows Task Scheduler (SYSTEM context)
  - Windows Task Scheduler (User context)
  - SCCM packages

#### New Features
- **User Tracking System**
  - Tracks last reminder timestamp
  - Counts user dismissals
  - First reminder timestamp tracking
  - Per-user registry tracking (`HKCU:\SOFTWARE\RebootReminder`)

- **Compliance Reporting**
  - JSON-based compliance reports (`$env:ProgramData\RebootCompliance.json`)
  - Historical compliance data
  - Device-level compliance tracking
  - Compliance statistics and analytics

- **Enhanced Notifications**
  - BurntToast module integration (optional)
  - Fallback to native notifications
  - Action buttons: Restart Now, Snooze 1 Hour, Dismiss
  - Final warning notifications
  - Multi-stage notification system

- **Improved Scheduling**
  - Built-in task registration functions
  - User context task support
  - Flexible scheduling options (Hourly, Daily, Weekly)
  - Automatic task cleanup

- **Better Logging**
  - Structured logging with levels (Info, Warning, Error, Debug)
  - Automatic log file creation
  - Log rotation (10MB limit with archiving)
  - Enhanced error messages

- **Configuration Flexibility**
  - Dismiss time hours parameter
  - Compliance report path configuration
  - Weekend skip functionality
  - Work hours configuration

#### Removed Features
- Removed long-running while loop (unsuitable for Intune)
- Removed registry-based protocol actions (security concerns)
- Removed balloon tip notifications (outdated)

#### Bug Fixes
- Fixed registry injection vulnerabilities
- Improved user session detection
- Better error handling for missing permissions
- Fixed path traversal issues
- Resolved context switching problems (SYSTEM vs User)

#### Security Improvements
- All user inputs validated
- No arbitrary code execution
- Safe registry operations
- Proper privilege handling
- Signed script support

#### Documentation
- Comprehensive README.md
- Intune Deployment Guide (INTUNE_DEPLOYMENT.md)
- Detection and remediation scripts
- Troubleshooting guides
- Examples and use cases

### Migration from v5.0

#### Breaking Changes
- Script no longer runs continuously; use scheduled tasks or Intune for recurring execution
- Registry keys changed: Now uses `HKCU:\SOFTWARE\RebootReminder` instead of protocol-based actions
- Log path defaults changed: Now prefers `$env:USERPROFILE` over `$env:TEMP`

#### Upgrade Path
1. Remove old scheduled tasks created with v5.0
2. Clean up old registry entries if using protocol-based actions
3. Deploy new version using preferred method (Intune recommended)
4. Configure parameters as needed

## [5.0.0] - 2024-09-04

### Previous Version Features
- Toast notifications with Windows 10
- Weekend and work hours filtering
- Long-running reminder loop
- Customizable time limits
- Basic logging

### Known Issues in v5.0
- Not compatible with Intune
- No user context support
- Registry-based protocol actions (security concerns)
- Long-running process unsuitable for enterprise deployment

## Future Roadmap

### Planned Features (v7.0)
- Graph API integration for centralized reporting
- Machine learning-based optimal reboot scheduling
- Integration with Windows Update for Business
- Web-based compliance dashboard
- Advanced scheduling with machine learning
- Group Policy integration
- Azure Sentinel integration for security alerts

### Under Consideration
- Mobile device support (iOS/Android via Intune)
- Linux support (via PowerShell Core)
- Custom notification sounds
- Multi-language support
- Integration with Teams/Slack notifications
- Automated help desk ticket creation

---

**Changelog Format**: Based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
**Version Scheme**: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
