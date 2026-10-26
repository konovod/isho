<#
.SYNOPSIS
  Builds and runs the API spec suite.

.DESCRIPTION
  Specs run against their own Postgres service (`db-test`, port 5433) whose data
  directory lives in tmpfs. Every example truncates every table, and on a Docker
  volume that costs about half a second per example — half of the whole run.

  Only one suite can use that database at a time: a second run would truncate
  tables from under the first one, and both would just wait for each other's
  locks and look like a hang. The script takes a lock for the duration of the run
  and waits for a run that is already in progress. A run started by hand also
  keeps bin\specs.exe locked, which blocks the rebuild, so the script waits for
  that one too.

.PARAMETER NoWait
  Fail instead of waiting when another run is in progress or bin\specs.exe is
  still running.

.EXAMPLE
  .\script\spec.ps1

.EXAMPLE
  .\script\spec.ps1 -e Slugify     # extra arguments go to the spec runner
#>
# No [CmdletBinding]: its common parameters would swallow the runner's own
# switches (`-e`, `-p`, `--fail-fast`), which go straight to bin/specs.exe.
param(
  [switch]$NoWait
)

$ErrorActionPreference = "Stop"

$apiDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$root = (Resolve-Path (Join-Path $apiDir "..")).Path
$specOutput = Join-Path $apiDir "bin\specs.exe"

# The test database is a separate container on 5433; development keeps 5432.
# These win over anything in `.env` because it sets no DB_* keys.
$env:LUCKY_ENV = "test"
$env:DB_HOST = "localhost"
$env:DB_PORT = "5433"

# Held open until the process exits, and closed by Windows even when it crashes,
# so a killed run never leaves a stale lock behind.
$lockPath = Join-Path ([System.IO.Path]::GetTempPath()) "isho-specs.lock"

function Open-SpecLock {
  try {
    return [System.IO.File]::Open(
      $lockPath,
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  }
  catch [System.IO.IOException] {
    return $null
  }
}

$lock = Open-SpecLock
if ($null -eq $lock) {
  if ($NoWait) {
    throw "Another spec run is using the test database. Run without -NoWait to wait for it."
  }
  Write-Host "Another spec run is in progress; waiting for it to finish..." -ForegroundColor Yellow
  while ($null -eq ($lock = Open-SpecLock)) {
    Start-Sleep -Seconds 3
  }
}

Write-Host "Starting the test database..." -ForegroundColor DarkGray
& docker compose --project-directory $root up -d --wait db-test
if ($LASTEXITCODE -ne 0) {
  throw "Could not start the db-test service (docker compose up -d --wait db-test)."
}

Set-Location $apiDir

# Windows keeps a running exe locked, so the build cannot overwrite it. The lock
# above covers runs started by this script; this covers bin\specs.exe started by
# hand or by an older copy of the script.
function Get-RunningSpecs {
  foreach ($process in @(Get-Process -Name "specs" -ErrorAction SilentlyContinue)) {
    $path = try { $process.Path } catch { $null }
    if ($path -eq $specOutput) { return $process }
  }
  return $null
}

$busy = Get-RunningSpecs
if ($null -ne $busy) {
  if ($NoWait) {
    throw "bin\specs.exe is running (PID $($busy.Id)) and blocks the rebuild. Run without -NoWait to wait for it."
  }
  Write-Host "bin\specs.exe is already running (PID $($busy.Id)); waiting for it to finish..." -ForegroundColor Yellow
  $deadline = (Get-Date).AddMinutes(20)
  while ($null -ne ($busy = Get-RunningSpecs)) {
    if ((Get-Date) -ge $deadline) {
      throw "bin\specs.exe (PID $($busy.Id)) has been running for more than 20 minutes and blocks the rebuild. If it is stuck, stop it with: Stop-Process -Id $($busy.Id)"
    }
    Start-Sleep -Seconds 3
  }
}

# `crystal spec` may terminate abnormally on Windows (Crystal 1.19). Building
# the runner and executing it directly works.
crystal build spec/all_specs.cr -o $specOutput
if ($LASTEXITCODE -ne 0) {
  $lock.Dispose()
  exit $LASTEXITCODE
}

& $specOutput @args
$status = $LASTEXITCODE

$lock.Dispose()
exit $status
