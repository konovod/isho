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
  .\deploy\deploy.ps1 -SiteAddress https://isho.duckdns.org

.EXAMPLE
  # No domain: nip.io resolves <dashed-ip>.nip.io to the server (see deploy/README.md)
  .\deploy\deploy.ps1 -SiteAddress https://185-180-231-183.nip.io

.EXAMPLE
  # Games on their own origin, so Unity keeps Cache Storage and PlayerPrefs
  # (see deploy/README.md). Caddy serves /media/web there and nothing else.
  .\deploy\deploy.ps1 -SiteAddress https://isho.duckdns.org -MediaAddress https://games.isho.duckdns.org

.EXAMPLE
  .\deploy\deploy.ps1 -SampleData   # also seed demo projects and accounts

.EXAMPLE
  # Confirmation letters from a mail.ru mailbox (see deploy/README.md)
  $env:ISHO_SMTP_PASSWORD = 'app-password'
  .\deploy\deploy.ps1 -SiteAddress https://example.com -MailFrom isho2026@mail.ru

.EXAMPLE
  # Forum AI through DeepSeek. The key is written to /etc/isho/api.env.
  $env:ISHO_AI_API_KEY = 'sk-...'
  .\deploy\deploy.ps1 -SiteAddress https://example.com
#>
[CmdletBinding()]
param(
  [string]$Server = '185.180.231.183',
  [string]$SshUser = 'root',
  [string]$Password = $env:ISHO_SSH_PASSWORD,
  # Caddy site address: ':80' for plain HTTP on any host, or 'https://host' for TLS.
  [string]$SiteAddress = '',
  # Origin used by the API for cookies and the Origin check (defaults to the
  # origin of -SiteAddress, or http://<server> when the site is plain HTTP).
  [string]$PublicOrigin = '',
  # Separate origin for browser builds, for example
  # https://games.isho.duckdns.org. A sandboxed game keeps Cache Storage,
  # IndexedDB and localStorage only while it has its own origin, which is safe
  # away from the site's cookies: Caddy serves /media/web there and closes
  # everything else. Omitted means the old same-origin layout.
  [string]$MediaAddress = '',
  # DuckDNS token: before deploying, points <name>.duckdns.org at -Server with
  # the DuckDNS API (only used with a *.duckdns.org site address).
  [string]$DuckDnsToken = $env:ISHO_DUCKDNS_TOKEN,
  [ValidateSet('auto', 'true', 'false')]
  [string]$SecureCookies = 'auto',
  # Mail. Without -MailFrom the API prints letters to the journal instead of
  # sending them, and the confirmation requirement can be turned off with
  # EMAIL_CONFIRMATION=off in /etc/isho/api.env.
  [string]$MailFrom = '',
  [ValidateSet('smtp', 'sendgrid', 'dev')]
  [string]$MailAdapter = 'smtp',
  [string]$SmtpHost = 'smtp.mail.ru',
  [string]$SmtpPort = '465',
  [ValidateSet('ssl', 'starttls', 'none')]
  [string]$SmtpTls = 'ssl',
  [string]$SmtpUser = '',
  [string]$SmtpPassword = $env:ISHO_SMTP_PASSWORD,
  # DeepSeek key for the forum AI features. Without it every AI feature stays
  # off and the worker idles; the key lives only in /etc/isho/api.env.
  [string]$AiApiKey = $env:ISHO_AI_API_KEY,
  [string]$AiModel = 'deepseek-chat',
  [switch]$SampleData,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$artifact = Join-Path $PSScriptRoot 'artifacts\isho-deploy.tar.gz'

if (-not $SiteAddress) { $SiteAddress = ':80' }

# The API compares the request Origin header against APP_ORIGIN and takes the
# cookie Secure flag from the same value, so an HTTPS site with an HTTP origin
# breaks every write request and drops Secure. Derive the origin from the site
# address instead of asking for both.
$siteOrigin = ''
if ($SiteAddress -match '^(https?)://([^/]+)') { $siteOrigin = "$($Matches[1])://$($Matches[2])" }

if (-not $PublicOrigin) {
  $PublicOrigin = $(if ($siteOrigin) { $siteOrigin } else { "http://$Server" })
}
elseif ($siteOrigin -and $PublicOrigin.TrimEnd('/') -ne $siteOrigin) {
  throw "PublicOrigin '$PublicOrigin' does not match SiteAddress '$SiteAddress'. Drop -PublicOrigin to derive it from the site address, or pass '$siteOrigin'."
}
else {
  $PublicOrigin = $PublicOrigin.TrimEnd('/')
}

$duckDnsName = ''
if ($DuckDnsToken) {
  if ($siteOrigin -match '^https?://([a-z0-9-]+)\.duckdns\.org$') { $duckDnsName = $Matches[1] }
  else { throw 'DuckDnsToken only applies to a <name>.duckdns.org site address.' }
}

# The media host must be an origin of its own: the same address would only
# repeat the site block and leave games on the site's origin.
$mediaOrigin = ''
if ($MediaAddress) {
  if ($MediaAddress -notmatch '^(https?)://([^/]+)/?$') {
    throw "MediaAddress must be an origin like https://games.example.com: $MediaAddress"
  }
  $MediaAddress = "$($Matches[1])://$($Matches[2])"
  $mediaOrigin = $MediaAddress
  if ($siteOrigin -and $mediaOrigin -eq $siteOrigin) {
    throw 'MediaAddress must differ from SiteAddress.'
  }
}

if ($MailFrom) {
  if (-not $SmtpUser) { $SmtpUser = $MailFrom }
}
else {
  $MailAdapter = 'dev'
}
foreach ($value in @($SiteAddress, $PublicOrigin, $MediaAddress, $mediaOrigin, $SshUser, $Server, $MailFrom, $MailAdapter, $SmtpHost, $SmtpPort, $SmtpTls, $SmtpUser, $SmtpPassword, $AiApiKey, $AiModel)) {
  if ($value -match "'") { throw "Values passed to the server must not contain single quotes: $value" }
}

# Values are interpolated into a double-quoted here-string below, so a literal
# $ or ` inside a password would be eaten by PowerShell.
function ConvertTo-RemoteLiteral([string]$Value) {
  if (-not $Value) { return '' }
  return $Value.Replace('`', '``').Replace('$', '`$')
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

if ($duckDnsName) {
  Write-Host "==> Pointing $duckDnsName.duckdns.org at $Server" -ForegroundColor Cyan
  $updateUrl = "https://www.duckdns.org/update?domains=$duckDnsName&token=$DuckDnsToken&ip=$Server"
  $answer = (Invoke-WebRequest -UseBasicParsing -Uri $updateUrl -TimeoutSec 30).Content
  # DuckDNS answers with a bare "OK"/"KO", sometimes as raw bytes.
  if ($answer -is [byte[]]) { $answer = [Text.Encoding]::UTF8.GetString($answer) }
  $answer = "$answer".Trim()
  if ($answer -ne 'OK') { throw "DuckDNS update failed: $answer (check the token at duckdns.org)" }
}

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
ISHO_SITE_ADDRESS='$SiteAddress' ISHO_PUBLIC_ORIGIN='$PublicOrigin' ISHO_COOKIE_SECURE='$SecureCookies' ISHO_SEED_SAMPLE='$seedSample' \
ISHO_MEDIA_SITE_ADDRESS='$MediaAddress' ISHO_MEDIA_ORIGIN='$mediaOrigin' \
ISHO_MAIL_ADAPTER='$MailAdapter' ISHO_MAIL_FROM='$(ConvertTo-RemoteLiteral $MailFrom)' \
ISHO_SMTP_HOST='$(ConvertTo-RemoteLiteral $SmtpHost)' ISHO_SMTP_PORT='$SmtpPort' ISHO_SMTP_TLS='$SmtpTls' \
ISHO_SMTP_USER='$(ConvertTo-RemoteLiteral $SmtpUser)' ISHO_SMTP_PASSWORD='$(ConvertTo-RemoteLiteral $SmtpPassword)' \
ISHO_AI_API_KEY='$(ConvertTo-RemoteLiteral $AiApiKey)' ISHO_AI_MODEL='$(ConvertTo-RemoteLiteral $AiModel)' \
bash /opt/isho-release/server/bootstrap.sh /opt/isho-release
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
