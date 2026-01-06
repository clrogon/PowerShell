# Contributing to PowerShell Scripts Repository

We're thrilled you're considering contributing to PowerShell Scripts Repository! This project thrives on input from the community, and it's because of your contributions that we can keep improving and growing this collection of scripts.

## 🔒 Security-First Contributions

This repository prioritizes security. **ALL contributions must adhere to security standards.**

Please review these documents before contributing:
- [SECURITY.md](SECURITY.md) - Security policy and guidelines
- [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) - Security review checklist
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) - Community guidelines

### Mandatory Security Requirements

1. **Input Validation**: All user inputs must be validated and sanitized
2. **No Secrets**: Never commit credentials, API keys, or passwords
3. **Strong Cryptography**: Use SHA256+ or stronger algorithms (not MD5/SHA1)
4. **HTTPS Only**: Enforce HTTPS for all network operations
5. **Path Safety**: Prevent directory traversal attacks
6. **Secure Defaults**: Use most secure default settings
7. **Privacy Protection**: Opt-in only for logging sensitive data

### Security Review Process

All pull requests undergo security review:
- Automated security scanning
- Manual code review using security checklist
- Testing with malicious inputs
- Risk assessment before merging

See [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) for detailed requirements.

## How Can I Contribute?

There are many ways you can contribute to this repository:

### Reporting Bugs

If you discover a bug within any of the scripts, please first search the issue tracker to see if it has already been reported. If it hasn't, feel free to open a new issue. In your report, include:

- A clear and descriptive title
- A detailed description of the problem
- Steps to reproduce the issue
- Any relevant logs or error messages
- Your environment details (PowerShell version, operating system)
- **Security impact** (if applicable)

### Suggesting Enhancements

Have an idea for a new feature or an improvement to an existing script? We'd love to hear from you! Please open an issue to suggest enhancements, providing:

- A clear and concise description of what the problem is
- How your suggestion addresses this problem
- Any additional context or screenshots
- **Security considerations** for the proposed feature

### Pull Requests

Pull requests are always welcome! Whether you're fixing a bug, adding a new script, or improving documentation, your contributions are valuable.

#### PR Requirements

**Before submitting a PR, ensure:**

1. Fork the repository and create your branch from main
2. If you've added a script or made significant changes, test your changes thoroughly
3. **Complete security review using SECURITY_CHECKLIST.md**
4. Update documentation with details of your changes
5. **No sensitive data or secrets committed**
6. All security checks are enabled (never commented out)

#### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix (non-breaking)
- [ ] New feature (non-breaking)
- [ ] Breaking change
- [ ] Security fix
- [ ] Documentation update

## Testing
Describe testing performed:
- [ ] Manual testing completed
- [ ] Security testing completed
- [ ] Edge cases tested

## Security Review
- [ ] Reviewed against SECURITY_CHECKLIST.md
- [ ] Input validation implemented
- [ ] No secrets committed
- [ ] Strong cryptography used
- [ ] HTTPS enforced (if applicable)
```

## Development Guidelines

### Coding Standards

#### PowerShell Best Practices
- Use approved verbs (Get, Set, New, Remove, etc.)
- Include comment-based help blocks
- Use `ShouldProcess` for destructive operations
- Implement proper error handling
- Write descriptive parameter help

#### Security Best Practices
- Validate all user inputs
- Sanitize strings before use
- Use parameterized queries (no concatenation)
- Strong cryptographic algorithms (SHA256+)
- HTTPS only for network operations
- Prevent path traversal attacks
- Never comment out security checks

### Documentation Requirements

1. **Comment-Based Help**: Every function must have help comments
2. **Parameters**: All parameters documented
3. **Examples**: At least one usage example
4. **Security Notes**: Document security considerations
5. **Privacy Notes**: If logging user data, document opt-out
6. **Changes**: Update relevant README files

## Code of Conduct

Participation in this project is subject to our [Code of Conduct](CODE_OF_CONDUCT.md). By contributing, you agree to uphold this code.

## Getting Started

- **Not sure where to start?** Look for open issues tagged with `good-first-issue` or `help-wanted`
- **Want to add a script?** Ensure it's well-documented and includes a README explaining its purpose, usage, parameters, and security considerations
- **First time contributor?** Try a small bug fix or documentation update to get familiar

### Development Setup

**Prerequisites:**
- PowerShell 5.1 or higher
- Git
- Text editor (VS Code recommended)

**Recommended VS Code Extensions:**
- PowerShell
- PSScriptAnalyzer (for security analysis)
- GitLens
- Code Spell Checker

**Testing:**
```powershell
# Enable script execution for testing
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run PSScriptAnalyzer for security checks
Invoke-ScriptAnalyzer -Path YourScript.ps1 -Settings PSGallery
```

## Additional Resources

### Security Documentation
- [SECURITY.md](SECURITY.md) - Comprehensive security policy
- [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) - Review checklist
- [CHANGELOG.md](CHANGELOG.md) - Version history

### Learning Resources
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-best-practices)
- [OWASP PowerShell Security](https://owasp.org/www-community/controls/PowerShell_Security)

## Questions?

If you have any questions or need further clarification:
- **General questions**: Open a GitHub Discussion
- **Bug reports**: Create an issue
- **Security issues**: Report privately (see SECURITY.md)
- **Feature requests**: Create an issue with `enhancement` label

## Thank You!

Your contributions to this project are greatly appreciated. Together, with security-focused development, we can make PowerShell Scripts Repository even better and safer for everyone!

---

**Remember: Security is everyone's responsibility.**
