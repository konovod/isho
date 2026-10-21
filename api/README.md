# isho API

Lucky 1.5 API for the isho prototype.

See the [root README](../README.md) for setup, commands, the API surface and
architecture notes. For agent-facing conventions see [AGENTS.md](../AGENTS.md).

Quick dev start (Windows):

```powershell
docker compose up -d db
shards install
crystal build tasks.cr -o bin/tasks.exe
.\bin\tasks.exe db.create
.\bin\tasks.exe db.migrate
.\bin\tasks.exe db.seed.sample_data
.\script\dev-api.ps1
```

Specs:

```powershell
.\script\spec.ps1
```
