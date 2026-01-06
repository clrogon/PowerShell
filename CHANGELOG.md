# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0] - 2026-01-07

### Security 🔒
- **Critical Security Fixes**: Comprehensive security audit and remediation across all scripts
- **DeploymentScript.ps1**:
  - Removed hardcoded personal paths, now parameterized
  - Fixed WMI injection vulnerability with proper sanitization
  - Implemented HTTPS-only URL validation
  - Enabled all previously disabled security checks
  - Switched to Get-CimInstance with parameterized queries
- **Find-DuplicateFiles.ps1**:
  - Changed default hash algorithm from MD5 to SHA256
  - Added path traversal protection
  - Implemented file extension validation
  - Added comprehensive input sanitization
- **RebootReminder.ps1**:
  - Added strict alphanumeric-only validation for registry operations
  - Implemented dangerous command pattern blocking
  - Added script content length limits
  - Enhanced ActionName sanitization
- **USBPortManagement.ps1**:
  - Made username logging optional via `-LogUserActions` parameter
  - Default privacy-first configuration (no username logging)
  - Enhanced parameter documentation
- **Show-Notification.ps1**:
  - Added XML entity escaping for all user inputs
  - Implemented image path validation
  - Added file extension whitelist validation
  - Enhanced XSS protection
- **Measure-TransferSpeed.ps1**:
  - Added Credential parameter for secure network access
  - Implemented PSDrive support for authenticated connections
  - Added server name validation
  - Enhanced network security

### Documentation 📚
- Added comprehensive **SECURITY.md** file with:
  - Security policy and guidelines
  - Reporting procedures for security issues
  - Best practices for contributors and users
  - Security audit history
- Updated **README.md** with:
  - Security section highlighting implemented features
  - Link to SECURITY.md
  - Security-first messaging
- Updated individual script READMEs with:
  - Security features documentation
  - Privacy controls information
  - Best practices guidance
- Created **CHANGELOG.md** for tracking all changes

### Added 🆕
- Security audit framework
- Input validation helper functions
- Path sanitization utilities
- XML escaping functions
- Security review checklist for contributors
- Digital signing recommendations

### Changed 🔄
- All scripts now use secure defaults
- Disabled all security bypass modes
- Enhanced error handling without information leakage
- Improved logging for security events

### Fixed 🐛
- WMI injection vulnerability (DeploymentScript.ps1)
- Registry injection vulnerability (RebootReminder.ps1)
- XML injection vulnerability (Show-Notification.ps1)
- Path traversal vulnerabilities (multiple scripts)
- Weak cryptography defaults (Find-DuplicateFiles.ps1)
- Disabled security checks (DeploymentScript.ps1)

## [1.0] - Previous Release

### Initial Scripts
- Reboot Reminder
- Show Balloon Tips
- Find Empty Folders
- Clear MS Teams Cache
- Find Duplicate Files
- Deployment Script
- USB Port and Storage Card Management Tool
- Show-Notification
- Measure Transfer Speed

[Unreleased]: https://github.com/claudiogoncalves/PowerShell/compare/v1.0...HEAD
[2.0]: https://github.com/claudiogoncalves/PowerShell/releases/tag/v2.0
