<#
.SYNOPSIS
  Install mise on Windows with the official PowerShell installer and, on
  request, add PowerShell activation.

.DESCRIPTION
  Runs https://mise.run/powershell, which installs the official release to
  ~\.local\bin, verifies it against SHASUMS256.txt from GitHub Releases, and
  adds that directory to the user Path. Needs PowerShell 5.1 or newer.

.PARAMETER Version
  Release to install, such as v2026.10.4. Default: the newest release.

.PARAMETER Activate
  Append the activation line to $PROFILE (once).

.PARAMETER ShimsOnPath
  Also add the shims directory to the user Path, for cmd.exe, editors and
  other programs that never read $PROFILE.

.EXAMPLE
  .\install-mise.ps1 -Activate -ShimsOnPath
#>
[CmdletBinding()]
param(
    [string]$Version,
    [switch]$Activate,
    [switch]$ShimsOnPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Version) {
    if (-not $Version.StartsWith('v')) { $Version = "v$Version" }
    $env:MISE_VERSION = $Version
}
if ($ShimsOnPath) {
    $env:MISE_INSTALL_SHIMS_PATH = '1'
}

Write-Host 'Installing mise from https://mise.run/powershell'
Invoke-RestMethod -Uri 'https://mise.run/powershell' | Invoke-Expression

$mise = Join-Path $HOME '.local\bin\mise.exe'
if ($env:MISE_INSTALL_PATH) { $mise = $env:MISE_INSTALL_PATH }
if (-not (Test-Path $mise)) {
    throw "installer finished but $mise is missing"
}

if ($Activate) {
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    $activation = '(&mise activate pwsh) | Out-String | Invoke-Expression'
    if (-not (Select-String -Path $PROFILE -SimpleMatch $activation -Quiet)) {
        Add-Content -Path $PROFILE -Value $activation
        Write-Host "Added activation to $PROFILE"
    }
    else {
        Write-Host "Activation already present in $PROFILE"
    }
}

& $mise --version
Write-Host 'Next: open a new terminal, then run: mise doctor'
