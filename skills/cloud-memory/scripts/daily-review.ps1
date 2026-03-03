<#
Daily review script (local-first). Intended to be run manually.
- Backup first (best-effort)
- Read today's memory file + baseline MEMORY.md
- Append a concise recap section to today's file
- Print a brief Chinese summary

Notes:
- This script does NOT install anything.
- It only edits local markdown files.
#>

$ErrorActionPreference = 'Stop'

function Resolve-WorkspacePath([string]$workspaceRoot, [string]$rel) {
  if ([System.IO.Path]::IsPathRooted($rel)) { return $rel }
  return (Join-Path $workspaceRoot $rel)
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $here 'daily-review.config.json'
if (!(Test-Path $configPath)) { throw "Missing config: $configPath" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$workspace = $config.workspaceRoot
if ([string]::IsNullOrWhiteSpace($workspace)) { throw "workspaceRoot is empty" }

# Determine date
$today = Get-Date -Format 'yyyy-MM-dd'
$dailyFile = Join-Path $workspace ("memory/{0}.md" -f $today)
$baselineFile = Join-Path $workspace $config.inputs.baseline

$backupOk = $false
$backupErr = $null
try {
  $pushRel = $config.backup.pushScript
  $push = Resolve-WorkspacePath $workspace $pushRel
  if (Test-Path $push) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $push | Out-Null
    $backupOk = $true
  } else {
    $backupErr = "push script not found: $push"
  }
} catch {
  $backupErr = $_.Exception.Message
}

if (!(Test-Path $dailyFile)) {
  New-Item -ItemType File -Force -Path $dailyFile | Out-Null
  Add-Content -Path $dailyFile -Value ("# Daily Log: {0}`n" -f $today)
}

$daily = Get-Content $dailyFile -Raw
$baseline = if (Test-Path $baselineFile) { Get-Content $baselineFile -Raw } else { "" }

# Heuristic recap placeholder (human/agent should refine)
$recap = @()
$recap += ""
$recap += "## Daily Review (auto)"
$recap += "- Backup: " + ($(if ($backupOk) { "OK" } else { "FAILED" }))
if (-not $backupOk -and $backupErr) { $recap += "  - Error: $backupErr" }
$recap += "- Notes: 请在此补充今日关键教训、被纠正点、以及需要写入 MEMORY.md 的结论。"
$recap += ""

if ($config.output.appendToDaily) {
  Add-Content -Path $dailyFile -Value ($recap -join "`n")
}

if ($config.output.briefToStdout) {
  Write-Output "同步: " + ($(if ($backupOk) { "成功" } else { "失败(继续复盘)" }))
  if (-not $backupOk -and $backupErr) { Write-Output ("同步报错: {0}" -f $backupErr) }
  Write-Output "复盘: 已在今日文件追加 Daily Review 段落（请补充内容）。"
}
