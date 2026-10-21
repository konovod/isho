$ErrorActionPreference = "Stop"

$env:LUCKY_ENV = "development"
$env:DEV_PORT = "4000"
$env:APP_ORIGIN = "http://localhost:3000,http://127.0.0.1:3000"
$env:COOKIE_SECURE = "false"

# Scoop's ImageMagick does not register its config paths on Windows.
$magick = Join-Path $env:USERPROFILE "scoop\apps\imagemagick\current"
if (Test-Path (Join-Path $magick "magick.exe")) {
  $env:MAGICK_HOME = $magick
  $env:MAGICK_CONFIGURE_PATH = $magick
  $env:MAGICK_CODER_MODULE_PATH = Join-Path $magick "modules\coders"
  $env:PATH = "$magick;$env:PATH"
} else {
  Write-Warning "ImageMagick not found at $magick. Screenshot variants will fail."
}

Set-Location (Join-Path $PSScriptRoot "..")

# `crystal run` is unreliable on Windows in this setup, so build and execute.
crystal build src/api.cr -o bin/api.exe
.\bin\api.exe
