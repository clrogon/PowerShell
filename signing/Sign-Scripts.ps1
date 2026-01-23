<#
This script signs PowerShell scripts (and modules) using a code signing certificate
installed in the local certificate store. If no certificate thumbprint is provided and
no certificate is found, the script will log a warning and skip signing for that file.
Usage:
  .\signing\Sign-Scripts.ps1 -Paths @(".\Measure-TransferSpeed\Measure-TransferSpeed.ps1", ".\Logging.psm1") -Thumbprint "ABCDEF123456..."
  or sign all if -Paths not provided:
  .\signing\Sign-Scripts.ps1 -Thumbprint $env:CODE_SIGN_THUMBPRINT
#>
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Paths,
    [string]$Thumbprint = $env:CODE_SIGN_THUMBPRINT
)

function Get-CertFromThumb {
    param([string]$tp)
    if (-not $tp) { return $null }
    try {
        $cert = Get-ChildItem -Path "Cert:\CurrentUser\My\$tp" -ErrorAction Stop
        return $cert
    } catch {
        return $null
    }
}

$cert = Get-CertFromThumb -tp $Thumbprint

if (-not $Paths -or $Paths.Count -eq 0) {
    # Default to all PowerShell scripts in the repository
    $Paths = Get-ChildItem -Path '.' -Recurse -Include '*.ps1','*.psm1' -File | ForEach-Object { $_.FullName }
}

foreach ($p in $Paths) {
    if (-not (Test-Path $p)) { Write-Host "Skipping missing path: $p"; continue }
    if (-not $cert) {
        Write-Warning "No signing certificate found for thumbprint '$Thumbprint'. Skipping signing of '$p'."
        continue
    }
    try {
        $sig = Set-AuthenticodeSignature -FilePath $p -Certificate $cert -ErrorAction Stop
        if ($sig.Status -eq 'UnknownError') {
            Write-Warning "Signing result for '$p' uncertain: $($sig.Status)"
        } else {
            Write-Host "Signed $p with thumbprint $Thumbprint" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to sign '$p': $_"
    }
}
