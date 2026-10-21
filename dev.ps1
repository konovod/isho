<#
.SYNOPSIS
  Starts the isho API and web frontend for local development.

.DESCRIPTION
  The API is started through api/script/dev-api.ps1, which sets the ImageMagick
  environment and builds bin/api.exe. This script waits for the API health
  endpoint and then runs Nuxt in the foreground. Ctrl+C stops both servers.

.EXAMPLE
  .\dev.ps1

.EXAMPLE
  .\dev.ps1 -ApiTimeoutSeconds 300
#>
[CmdletBinding()]
param(
  [ValidateRange(10, 1800)]
  [int]$ApiTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$apiScript = Join-Path $root "api\script\dev-api.ps1"
$webDir = Join-Path $root "web"
$healthUrl = "http://127.0.0.1:4000/api/v1/health"

foreach ($command in @("crystal", "npm")) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command was not found in PATH."
  }
}

if (-not (Test-Path $apiScript)) {
  throw "API dev script not found at $apiScript."
}

if (-not (Test-Path (Join-Path $webDir "node_modules"))) {
  throw "Frontend dependencies are missing. Run 'npm install' in web/ first."
}

$api = $null
$webStarted = $false

function Test-ApiReady {
  try {
    Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2 | Out-Null
    return $true
  }
  catch {
    return $false
  }
}

function Stop-Api {
  if ($null -eq $api -or $api.HasExited) {
    return
  }

  Write-Host "Stopping API..." -ForegroundColor DarkGray
  & taskkill.exe /PID $api.Id /T /F 2>$null | Out-Null
}

Write-Host ""
Write-Host "  isho dev" -ForegroundColor Cyan
Write-Host "  API  http://127.0.0.1:4000" -ForegroundColor DarkGray
Write-Host "  Web  http://localhost:3000" -ForegroundColor DarkGray
Write-Host ""

try {
  if (Test-ApiReady) {
    Write-Host "API is already running on port 4000; using it." -ForegroundColor Yellow
  }
  else {
    Write-Host "Starting API..." -ForegroundColor Cyan
    $shell = if ($PSVersionTable.PSEdition -eq "Core") {
      Join-Path $PSHOME "pwsh.exe"
    }
    else {
      Join-Path $PSHOME "powershell.exe"
    }

    $api = Start-Process `
      -FilePath $shell `
      -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$apiScript`"" `
      -WorkingDirectory $root `
      -NoNewWindow `
      -PassThru

    $deadline = (Get-Date).AddSeconds($ApiTimeoutSeconds)
    while (-not (Test-ApiReady)) {
      if ($api.HasExited) {
        throw "API exited with code $($api.ExitCode) during startup. See the log above."
      }
      if ((Get-Date) -ge $deadline) {
        throw "API did not become ready within $ApiTimeoutSeconds seconds."
      }
      Start-Sleep -Milliseconds 500
    }

    Write-Host "API is ready." -ForegroundColor Green
  }

  Write-Host "Starting Nuxt..." -ForegroundColor Cyan
  Push-Location $webDir
  $webStarted = $true
  npm run dev
}
finally {
  if ($webStarted) {
    Pop-Location
  }
  Stop-Api
}
