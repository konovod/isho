<#
.SYNOPSIS
  Runs the stress-test steps on the isho server over SSH.

.DESCRIPTION
  Mirrors deploy/deploy.ps1: the same host, SSH password and plink/pscp setup.
  Seed and cleanup are separate actions on purpose, so data can be removed
  manually at any time without running the seed again.

  Deploy the updated release first (the server must have the new tasks binary):
    .\deploy\deploy.ps1

.EXAMPLE
  $env:ISHO_SSH_PASSWORD = 'secret'
  .\stress\remote.ps1 -Action preflight

.EXAMPLE
  .\stress\remote.ps1 -Action backup

.EXAMPLE
  .\stress\remote.ps1 -Action seed -Yes

.EXAMPLE
  .\stress\remote.ps1 -Action probe -Label vps

.EXAMPLE
  .\stress\remote.ps1 -Action cleanup            # dry run
  .\stress\remote.ps1 -Action cleanup -Yes -Vacuum
#>
[CmdletBinding()]
param(
  [ValidateSet('preflight', 'backup', 'seed', 'stats', 'probe', 'cleanup')]
  [string]$Action = 'preflight',
  [string]$Server = '185.180.231.183',
  [string]$SshUser = 'root',
  [string]$Password = $env:ISHO_SSH_PASSWORD,
  # Direct services by default: Caddy may only answer on the configured domain.
  [string]$BaseUrl = 'http://127.0.0.1:3000',
  [string]$ApiBaseUrl = 'http://127.0.0.1:4000',
  [string]$Label = 'vps',
  [int]$Users = 1000,
  [int]$Projects = 1000,
  [int]$Tags = 1000,
  [int]$Topics = 1000,
  [int]$PostsPerTopic = 200,
  [int]$Screenshots = 1,
  [switch]$Yes,
  [switch]$Vacuum,
  [switch]$AcceptHostKey
)

$ErrorActionPreference = 'Stop'

foreach ($tool in @('plink.exe', 'pscp.exe')) {
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

function Invoke-Remote {
  param([string]$Command)
  $arguments = @('-ssh', '-l', $SshUser, '-pw', $Password)
  if (-not $AcceptHostKey) { $arguments += '-batch' }
  $arguments += @($Server, $Command)
  if ($AcceptHostKey) {
    'y' | & $Plink @arguments
  }
  else {
    & $Plink @arguments
  }
  if ($LASTEXITCODE -ne 0) { throw "Remote command failed (exit $LASTEXITCODE)" }
}

function New-TaskCommand([string]$TaskArguments) {
  $inner = "set -a; . /etc/isho/api.env; set +a; cd /srv/isho/api && ./bin/tasks $TaskArguments"
  return "runuser -u isho -- bash -c '$inner'"
}

function Show-ServerState {
  $command = @'
echo '--- memory ---'
free -m
echo '--- disk ---'
df -h / /var/lib/postgresql 2>/dev/null || df -h /
echo '--- services ---'
systemctl is-active isho-api isho-web caddy || true
systemctl show -p MemoryCurrent isho-api isho-web 2>/dev/null || true
echo '--- postgres data ---'
du -sh /var/lib/postgresql/*/main 2>/dev/null || true
echo '--- tasks binary ---'
ls -l /srv/isho/api/bin/tasks
'@
  Invoke-Remote ($command.Replace("`r`n", "`n"))
  Write-Host ''
  Invoke-Remote (New-TaskCommand 'db.stress.stats')
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

switch ($Action) {
  'preflight' {
    Write-Host "==> Preflight $Server" -ForegroundColor Cyan
    Show-ServerState
  }

  'backup' {
    $file = "/root/isho-before-stress-$stamp.sql.gz"
    Write-Host "==> Dumping isho_production to $file" -ForegroundColor Cyan
    $timer = [Diagnostics.Stopwatch]::StartNew()
    # The redirect runs as root; only pg_dump itself needs the postgres user.
    Invoke-Remote "runuser -u postgres -- pg_dump isho_production | gzip > $file"
    $timer.Stop()
    Invoke-Remote "ls -lh $file && sha256sum $file"
    Write-Host ("Dump finished in {0:N1} s" -f $timer.Elapsed.TotalSeconds) -ForegroundColor Green
    Write-Host "Restore: gunzip -c $file | runuser -u postgres -- psql isho_production"
  }

  'seed' {
    if (-not $Yes) {
      throw 'Refusing to seed without -Yes: the data is published in the catalog and forum.'
    }

    $taskArgs = "db.stress.seed --users=$Users --projects=$Projects --tags=$Tags --topics=$Topics --posts-per-topic=$PostsPerTopic --screenshots=$Screenshots"
    Write-Host "==> Seeding stress data on $Server" -ForegroundColor Cyan
    Write-Host "    users=$Users projects=$Projects tags=$Tags topics=$Topics posts/topic=$PostsPerTopic screenshots/project=$Screenshots"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Remote (New-TaskCommand $taskArgs)
    $timer.Stop()
    Write-Host ("Seed finished in {0:N1} s" -f $timer.Elapsed.TotalSeconds) -ForegroundColor Green
    Write-Host ''
    Invoke-Remote (New-TaskCommand 'db.stress.stats')
  }

  'stats' {
    Write-Host "==> Stress statistics on $Server" -ForegroundColor Cyan
    Invoke-Remote (New-TaskCommand 'db.stress.stats')
  }

  'probe' {
    if ($Label -notmatch '^[A-Za-z0-9_-]+$') {
      throw 'Label may contain only letters, digits, underscore and dash.'
    }

    $localProbe = Join-Path $PSScriptRoot 'probe.mjs'
    if (-not (Test-Path $localProbe)) { throw "Probe not found: $localProbe" }

    $remoteProbe = '/tmp/isho-stress-probe.mjs'
    $remoteJson = "/tmp/isho-stress-$Label.json"
    $resultsDir = Join-Path $PSScriptRoot 'results'
    New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null
    $localJson = Join-Path $resultsDir "$Label-$stamp.json"

    Write-Host "==> Uploading probe to $Server" -ForegroundColor Cyan
    & $Pscp -pw $Password -batch $localProbe "${SshUser}@${Server}:$remoteProbe"
    if ($LASTEXITCODE -ne 0) { throw 'Probe upload failed.' }

    try {
      $probeArgs = "--base $BaseUrl --api-base $ApiBaseUrl --label $Label --json-out $remoteJson"
      $node = '/opt/node22/bin/node'
      Write-Host "==> Running probe ($BaseUrl / $ApiBaseUrl)" -ForegroundColor Cyan
      Invoke-Remote "$node $remoteProbe $probeArgs"

      Write-Host "==> Downloading results" -ForegroundColor Cyan
      & $Pscp -pw $Password -batch "${SshUser}@${Server}:$remoteJson" $localJson
      if ($LASTEXITCODE -ne 0) { throw 'Result download failed.' }
      Write-Host "Saved: $localJson" -ForegroundColor Green
    }
    finally {
      Invoke-Remote "rm -f $remoteProbe $remoteJson" 2>$null
    }
  }

  'cleanup' {
    $taskArgs = 'db.stress.cleanup'
    if ($Yes) { $taskArgs += ' --yes' }
    if ($Vacuum) { $taskArgs += ' --vacuum' }

    if (-not $Yes) {
      Write-Host '==> Dry run (pass -Yes to delete)' -ForegroundColor Yellow
    }
    else {
      Write-Host '==> Deleting stress data (only marker records)' -ForegroundColor Cyan
    }

    $timer = [Diagnostics.Stopwatch]::StartNew()
    Invoke-Remote (New-TaskCommand $taskArgs)
    $timer.Stop()
    Write-Host ("Cleanup command finished in {0:N1} s" -f $timer.Elapsed.TotalSeconds) -ForegroundColor Green
    Write-Host ''
    Show-ServerState
  }
}
