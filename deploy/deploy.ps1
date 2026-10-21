<#
.SYNOPSIS
  Builds isho in WSL (Ubuntu 24.04) and deploys it to a Ubuntu server over SSH.

.DESCRIPTION
  Artifacts (Lucky release binaries + Nuxt server build) are produced in WSL,
  uploaded with PuTTY's pscp and installed by deploy/server/bootstrap.sh, which
  also provisions PostgreSQL, Node.js, Caddy, systemd services and env files on
  first run.

  The SSH password is taken from -Password or $env:ISHO_SSH_PASSWORD.
  Host keys are cached by plink on the first connection.

.EXAMPLE
  $env:ISHO_SSH_PASSWORD = 'secret'
  .\deploy\deploy.ps1

.EXAMPLE
  .\deploy\deploy.ps1 -SiteAddress https://vm4775508.firstbyte.club

.EXAMPLE
  .\deploy\deploy.ps1 -SampleData   # also seed demo projects and accounts
#>
[CmdletBinding()]
param(
  [string]$Server = '185.180.231.183',
  [string]$SshUser = 'root',
  [string]$Password = $env:ISHO_SSH_PASSWORD,
  # Caddy site address: ':80' for plain HTTP on any host, or 'https://host' for TLS.
  [string]$SiteAddress = '',
  # Origin used by the API for cookies and the Origin check (defaults to http://<server>).
  [string]$PublicOrigin = '',
  [ValidateSet('auto', 'true', 'false')]
  [string]$SecureCookies = 'auto',
  [switch]$SampleData,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$artifact = Join-Path $PSScriptRoot 'artifacts\isho-deploy.tar.gz'

if (-not $SiteAddress) { $SiteAddress = ':80' }
if (-not $PublicOrigin) { $PublicOrigin = "http://$Server" }
foreach ($value in @($SiteAddress, $PublicOrigin, $SshUser, $Server)) {
  if ($value -match "'") { throw "Values passed to the server must not contain single quotes: $value" }
}

foreach ($tool in @('wsl', 'plink.exe', 'pscp.exe')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue) -and -not (Test-Path (Join-Path 'D:\Programs\PuTTY' $tool))) {
    throw "$tool not found in PATH."
  }
}

$Plink = (Get-Command plink.exe -ErrorAction SilentlyContinue).Source
if (-not $Plink) { $Plink = 'D:\Programs\PuTTY\plink.exe' }
$Pscp = (Get-Command pscp.exe -ErrorAction SilentlyContinue).Source
if (-not $Pscp) { $Pscp = 'D:\Programs\PuTTY\pscp.exe' }

if (-not $Password) {
  $secure = Read-Host -AsSecureString "SSH password for $SshUser@$Server"
  $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
if (-not $Password) { throw 'SSH password is required.' }

function ConvertTo-WslPath([string]$Path) {
  $full = (Resolve-Path -LiteralPath $Path).Path
  $drive = $full.Substring(0, 1).ToLowerInvariant()
  return "/mnt/$drive" + $full.Substring(2).Replace('\', '/')
}

function Invoke-Remote {
  param([string]$Command, [switch]$AllowHostKeyPrompt)
  $arguments = @('-ssh', '-l', $SshUser, '-pw', $Password)
  if (-not $AllowHostKeyPrompt) { $arguments += '-batch' }
  $arguments += @($Server, $Command)
  if ($AllowHostKeyPrompt) {
    'y' | & $Plink @arguments
  }
  else {
    & $Plink @arguments
  }
  if ($LASTEXITCODE -ne 0) { throw "Remote command failed (exit $LASTEXITCODE): $Command" }
}

if (-not $SkipBuild) {
  Write-Host '==> Building release in WSL' -ForegroundColor Cyan
  $buildScript = ConvertTo-WslPath (Join-Path $PSScriptRoot 'build-wsl.sh')
  & wsl -u root -e bash $buildScript
  if ($LASTEXITCODE -ne 0) { throw 'WSL build failed.' }
}
if (-not (Test-Path $artifact)) { throw "Artifact not found: $artifact" }

Write-Host "==> Uploading $(Split-Path -Leaf $artifact) to $Server" -ForegroundColor Cyan
& $Pscp -pw $Password -batch $artifact "${SshUser}@${Server}:/tmp/isho-deploy.tar.gz"
if ($LASTEXITCODE -ne 0) { throw 'Upload failed.' }

$seedSample = if ($SampleData) { '1' } else { '0' }
$remote = @"
rm -rf /opt/isho-release && mkdir -p /opt/isho-release &&
tar -xzf /tmp/isho-deploy.tar.gz -C /opt/isho-release &&
ISHO_SITE_ADDRESS='$SiteAddress' ISHO_PUBLIC_ORIGIN='$PublicOrigin' ISHO_COOKIE_SECURE='$SecureCookies' ISHO_SEED_SAMPLE='$seedSample' bash /opt/isho-release/server/bootstrap.sh /opt/isho-release
"@
# plink passes the command verbatim; CRLF would become part of the last argument.
$remote = $remote.Replace("`r`n", "`n")

Write-Host '==> Installing on the server' -ForegroundColor Cyan
try {
  Invoke-Remote $remote -AllowHostKeyPrompt
}
finally {
  Invoke-Remote 'rm -f /tmp/isho-deploy.tar.gz'
}

Write-Host ''
Write-Host "Deployed to $PublicOrigin" -ForegroundColor Green
