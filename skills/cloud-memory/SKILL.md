# cloud-memory (Qiniu-backed memory vault)

**Goal**: keep a durable “cloud memory vault” for OpenClaw, so project/server knowledge persists across sessions and you don’t keep asking the human the same questions.

This skill implements **local-first memory + Qiniu (S3-compatible) sync**.

## What this skill enforces

1. **Local memory is the source of truth** during a session.
2. Before doing any work involving prior context (projects/servers/decisions/preferences), the agent MUST:
   - run `memory_search` first
   - then `memory_get` for the relevant snippets
   - only ask the human if memory confidence is low or missing
3. Qiniu is used for **backup/sync** of:
   - `MEMORY.md`
   - `memory/**/*.md`
   - optional: `memory/*.json`

## Daily review / self-improvement loop (recommended)

This skill supports a strict daily loop (inspired by your “自我进化” spec):

1) **Backup first** (always attempt; if sync fails, log and continue)
2) **Introspection & analysis** (read today’s `memory/` and compare to `MEMORY.md` baseline)
3) **Distill & adjust** (append a concise recap to today’s file, optionally update `MEMORY.md`)
4) **Briefing output** (Chinese summary: sync status + lessons + any config changes)

Red lines:
- Do **not** auto-install skills.
- Do **not** execute drafts that you wrote “as suggestions”.
- Do **not** edit `SOUL.md` casually.

## Memory structure (recommended)

Create these directories under the OpenClaw workspace root:

- `MEMORY.md` (curated long-term)
- `memory/YYYY-MM-DD.md` (daily log)
- `memory/projects/<project>.md`
- `memory/infra/<host>.md`
- `memory/heartbeat-state.json` (optional)

Templates are provided in `templates/`.

## Setup (Windows)

### 1) Install rclone

Install rclone: https://rclone.org/downloads/

Verify:

```powershell
rclone version
```

### 2) Configure Qiniu in rclone

Qiniu can be used via **S3-compatible** mode (recommended).

Run:

```powershell
rclone config
```

Create a new remote, for example name it: `qiniu`

- Storage: `s3`
- Provider: `Other`
- env_auth: `false`
- access_key_id: **(your Qiniu AK)**
- secret_access_key: **(your Qiniu SK)**
- region: leave blank (or as required)
- endpoint: **your Qiniu S3 endpoint** (e.g. `s3-cn-east-1.qiniucs.com` or the endpoint you were given)
- location_constraint: leave blank unless required

Then test:

```powershell
rclone lsd qiniu:
```

### 3) Configure this skill

Edit `scripts/cloud-memory.config.json` and fill:

- `workspaceRoot`
- `qiniuRemote` (e.g. `qiniu`)
- `bucket` (space/bucket name)
- `prefix` (folder prefix inside bucket, e.g. `openclaw-memory`)

## Sync commands

You can use either **rclone** (A) or **S3-compatible via AWS CLI** (B).

### A) rclone (push local → cloud)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\cloud-memory-push.ps1
```

### A) rclone (pull cloud → local)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\cloud-memory-pull.ps1
```

### B) S3-compatible (AWS CLI) (push local → cloud)

Prereqs:
- Install AWS CLI v2
- Set env vars `QINIU_AK` and `QINIU_SK` in your shell (**do not paste into chat**)
- Configure `scripts/cloud-memory-s3.config.json`

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\cloud-memory-s3-push.ps1
```

### B) S3-compatible (AWS CLI) (pull cloud → local)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\cloud-memory-s3-pull.ps1
```

## Operational policy

- **Never** paste AK/SK into chat.
- Keep secrets out of markdown memory files when possible.
- For infra records, store **identifiers and procedures**; keep passwords/keys in a secrets manager.

## Optional automation

- Run push on a schedule (Task Scheduler) every 30 minutes.
- Run push on session end if you have a hook (future).

## Files in this skill

- `templates/project.md`
- `templates/infra-host.md`
- `templates/daily.md`
- `scripts/cloud-memory.config.json`
- `scripts/cloud-memory-push.ps1`
- `scripts/cloud-memory-pull.ps1`
