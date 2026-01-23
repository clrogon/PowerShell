# Script Signing Policy

Purpose
- Ensure integrity and authenticity of PowerShell scripts in the repository.

Scope
- All PowerShell scripts (*.ps1) and PowerShell modules (*.psm1) in the repo.

Policy
- Scripts must be signed in production environments.
- CI should sign scripts automatically when a signing certificate is available.
- If a certificate is not present, signing is skipped with a warning; manual signing is required before production release.
- Signatures must be verifiable with a trusted certificate authority; avoid self-signed signatures for production.

How to sign locally
- Obtain a code signing certificate from a trusted CA.
- Use Sign-Scripts.ps1 to sign scripts:
  - Path: signings/Sign-Scripts.ps1 -Thumbprint <CERT_THUMBPRINT>
- Verify signature using Get-AuthenticodeSignature <path>.

CI/CD guidance
- In GitHub Actions, load a signing certificate (via secure secrets) and run Sign-Scripts.ps1 on all changed scripts.
- If signing fails, mark the build as failed to prevent unsigned artifacts from being released.

Review notes
- Security review should include verification that all changed scripts are signed prior to deployment.
