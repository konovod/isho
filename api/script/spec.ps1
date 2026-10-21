$ErrorActionPreference = "Stop"

$env:LUCKY_ENV = "test"

Set-Location (Join-Path $PSScriptRoot "..")

# `crystal spec` may terminate abnormally on Windows (Crystal 1.19). Building
# the runner and executing it directly works.
crystal build spec/all_specs.cr -o bin/specs.exe
.\bin\specs.exe
