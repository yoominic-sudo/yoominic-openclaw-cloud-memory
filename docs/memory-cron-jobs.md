# Memory Cron Jobs (v2)

This documents two optional cron jobs inspired by linux.do 1621623.

## 1) memory-sync (capture conversations → daily file)

Purpose: scan recent sessions and append compressed, deduped summaries to `memory/YYYY-MM-DD.md`.

Recommended schedule: 4 times/day.

Example:

```powershell
openclaw cron add \
  --name "memory-sync" \
  --cron "0 10,14,18,22 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --light-context \
  --no-deliver \
  --timeout 180000 \
  --message "MEMORY_SYNC: Use sessions_list (last 4h). Skip isolated. Skip sessions with <2 user msgs. For each session, use sessions_history to read. Idempotency: if daily file already contains session:<FIRST8>, skip. Append 3-10 bullets with key requests, decisions, outcomes. Do not modify MEMORY.md." 
```

## 2) memory-tidy (compress weekly + distill to MEMORY.md)

Purpose: compress old daily files into weekly summaries, distill long-term memory with strict criteria, and archive.

Recommended schedule: daily 03:00.

```powershell
openclaw cron add \
  --name "memory-tidy" \
  --cron "0 3 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --light-context \
  --no-deliver \
  --timeout 300000 \
  --message "MEMORY_TIDY: Phase1 weekly compress >7d daily into memory/weekly/; Phase2 distill to MEMORY.md only if meets 4 criteria; backup MEMORY.md to memory/archive/; enforce 80 lines/5KB limit; Phase3 archive compressed dailies. Best-effort; never touch SOUL.md." 
```

Notes:
- These jobs require the agent to have access to sessions_list/sessions_history tools.
- Keep them strict and conservative in what they write to MEMORY.md.
