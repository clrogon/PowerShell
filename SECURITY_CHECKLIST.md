# Security Review Checklist

This checklist is designed to help contributors and reviewers ensure security standards are maintained before merging changes.

## 📋 Before Submitting Code

### Input Validation
- [ ] All user inputs are validated before use
- [ ] File paths are checked for directory traversal attacks (`..`)
- [ ] Strings are sanitized for injection attacks
- [ ] Numeric inputs have range validation
- [ ] Enum inputs have allowed value validation
- [ ] No direct user input in SQL/WMI/XML queries

### Authentication & Authorization
- [ ] Admin privilege checks in place where needed
- [ ] Credentials use PSCredential objects (not plain text)
- [ ] No hardcoded credentials in source code
- [ ] Network operations support secure authentication
- [ ] Permission checks performed before resource access

### Cryptography
- [ ] Strong algorithms used (SHA256+, AES-256+, etc.)
- [ ] No MD5/SHA1/DES for security purposes
- [ ] Random number generators are cryptographically secure
- [ ] Keys/secrets are properly stored and managed
- [ ] Default algorithms are the most secure option

### Network Security
- [ ] HTTPS enforced for all downloads
- [ ] URLs validated before use
- [ ] SSL/TLS certificate validation enabled
- [ ] No insecure protocols (HTTP, FTP, Telnet)
- [ ] Server names validated (injection prevention)

### File System Security
- [ ] Path traversal protection implemented
- [ ] File permissions checked before operations
- [ ] Temp files created securely
- [ ] Sensitive files have restricted access
- [ ] File extensions validated

### Registry Operations
- [ ] Registry paths validated
- [ ] Values sanitized before writing
- [ ] Backup of registry keys before modification
- [ ] Error handling prevents inconsistent state
- [ ] Privilege checks for registry access

### Logging & Auditing
- [ ] No sensitive data in logs (passwords, tokens)
- [ ] Username logging is opt-in (privacy)
- [ ] Security events logged appropriately
- [ ] Log rotation implemented
- [ ] Log files have proper access controls

### Error Handling
- [ ] Security checks never commented out
- [ ] Errors don't expose sensitive information
- [ ] Graceful failure on validation issues
- [ ] No information leakage in exceptions
- [ ] Proper error messages without system details

### Code Quality
- [ ] No commented-out security code
- [ ] No debug prints with sensitive data
- [ ] No hardcoded personal information
- [ ] Clear variable naming
- [ ] Security-related code commented

## 🔍 Code Review Checklist

### During Review
- [ ] Identify all user input points
- [ ] Check for injection vulnerabilities
- [ ] Verify cryptographic implementations
- [ ] Review authentication flow
- [ ] Test for path traversal
- [ ] Validate error handling
- [ ] Check logging practices
- [ ] Review privilege escalation
- [ ] Verify network security
- [ ] Test with malicious inputs

### Security Testing
- [ ] Test with malicious file paths
- [ ] Attempt SQL/WMI/XML injection
- [ ] Try path traversal attacks
- [ ] Test with oversized inputs
- [ ] Verify authentication enforcement
- [ ] Test without admin privileges
- [ ] Attempt to bypass validation
- [ ] Check for information disclosure

## 📝 Specific Vulnerability Categories

### Injection Prevention
- [ ] SQL Injection: Use parameterized queries
- [ ] Command Injection: Avoid command concatenation
- [ ] WMI/CIM Injection: Sanitize filters, use parameterization
- [ ] XML Injection: Use XML encoding/escaping
- [ ] LDAP Injection: Validate and sanitize inputs

### Cross-Site Scripting (XSS)
- [ ] HTML encoding for web outputs
- [ ] XML entity encoding for XML outputs
- [ ] Input validation for all user data
- [ ] Content-Type headers set correctly
- [ ] Output encoding before display

### Path Traversal
- [ ] Validate and normalize paths
- [ ] Use canonical path representations
- [ ] Block directory traversal sequences
- [ ] Restrict to allowed directories
- [ ] Use whitelisting for paths

### Sensitive Data Handling
- [ ] No credentials in code
- [ ] Secure string for passwords
- [ ] No sensitive data in logs
- [ ] Encrypted storage for secrets
- [ ] Memory clearing after use

## 🚫 Common Security Anti-Patterns

### DO NOT Do These Things
- ❌ Comment out security checks
- ❌ Use string concatenation in queries
- ❌ Hardcode credentials or secrets
- ❌ Use weak cryptographic algorithms
- ❌ Log sensitive information
- ❌ Disable error checking
- ❌ Trust user input without validation
- ❌ Use insecure protocols (HTTP, etc.)
- ❌ Expose system details in errors
- ❌ Skip privilege checks

### INSTEAD Do These Things
- ✅ Use parameterized queries
- ✅ Validate and sanitize all inputs
- ✅ Use secure credential management
- ✅ Implement strong cryptography
- ✅ Log security events appropriately
- ✅ Handle errors securely
- ✅ Enable all security checks
- ✅ Enforce HTTPS/TLS
- ✅ Generic error messages
- ✅ Verify privileges before actions

## 📊 Security Scoring

For each pull request, assess security risk:

### Risk Categories
- **Critical**: Authentication bypass, data exposure, injection vulnerabilities
- **High**: Weak cryptography, insecure protocols, privilege escalation
- **Medium**: Information disclosure, inadequate logging, path traversal
- **Low**: Missing input validation, poor error handling

### Review Requirements
- **0 Critical/High issues**: ✅ Approve
- **1 Critical issue**: ❌ Request fixes
- **1 High issue**: ⚠️ Request fixes or provide strong justification
- **2+ High issues**: ❌ Reject until resolved

## 📚 Additional Resources

### Security Documentation
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [PowerShell Security](https://docs.microsoft.com/en-us/powershell/scripting/learn/security-best-practices)

### Testing Tools
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [Invoke-ScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [Security Scanner Tools](https://owasp.org/www-community/vulnerability_scanning_tools)

### Learning Resources
- [Secure Coding Practices](https://owasp.org/www-project-secure-coding-practices-quick-reference-guide/)
- [Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)

## ✅ Approval Criteria

Before approving a PR, ensure:
1. [ ] All items in "Before Submitting Code" are checked
2. [ ] Code review checklist completed
3. [ ] Security testing performed
4. [ ] No critical/high severity issues
5. [ ] Documentation updated (if needed)
6. [ ] Changelog updated (if needed)
7. [ ] No sensitive data in code
8. [ ] Security tests pass

---

**Last Updated**: January 2026
**Version**: 1.0
