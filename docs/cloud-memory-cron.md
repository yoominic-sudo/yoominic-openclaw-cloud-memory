# Cloud Memory Hourly Sync (OpenClaw Cron)

This repo configures an hourly cron job in OpenClaw to keep local memory in sync with Qiniu.

## Job
- Name: `cloud-memory-hourly-sync`
- Schedule: every 1 hour
- Target: isolated session (light context)

## What it does
On each run (best-effort):
1) Pull from Qiniu → local: `skills/cloud-memory/scripts/cloud-memory-s3-pull.ps1`
2) Push local → Qiniu: `skills/cloud-memory/scripts/cloud-memory-s3-push.ps1`
3) If errors occur, append a concise line to `memory/YYYY-MM-DD.md` under a `Sync Errors` section.

## Create the job

Run:

```powershell
openclaw cron add --name "cloud-memory-hourly-sync" --every 1h --session isolated --light-context --message "HOURLY_CLOUD_MEMORY_SYNC: Run pull then push for cloud memory. Step1 exec: powershell -NoProfile -ExecutionPolicy Bypass -File skills\\cloud-memory\\scripts\\cloud-memory-s3-pull.ps1 . Step2 exec: powershell -NoProfile -ExecutionPolicy Bypass -File skills\\cloud-memory\\scripts\\cloud-memory-s3-push.ps1 . Best-effort: if either fails, write a concise error line into workspace/memory/YYYY-MM-DD.md under a 'Sync Errors' section (create if missing). Do not do any other actions." --no-deliver
```

## Test the job now

Cron runs may take longer than 30s depending on network. Use a higher timeout:

```powershell
openclaw cron run d474f30e-29fb-4b03-9a7d-4f7569c14b26 --timeout 180000
```
```

## Remove the job

```powershell
openclaw cron rm d474f30e-29fb-4b03-9a7d-4f7569c14b26
```

