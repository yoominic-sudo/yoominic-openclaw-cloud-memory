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

# === Introspection & analysis (heuristics) ===

# 1) Git changes (memory only)
$gitOk = $false
$changedMemory = @()
try {
  Push-Location $workspace
  $porcelain = git status --porcelain 2>$null
  if ($LASTEXITCODE -eq 0) {
    $gitOk = $true
    foreach ($line in ($porcelain -split "`n")) {
      $l = $line.Trim()
      if (-not $l) { continue }
      # format: "XY path"
      $path = $l.Substring(3)
      if ($path -like 'MEMORY.md' -or $path -like 'memory/*') { $changedMemory += $path }
    }
  }
} catch {
  # ignore
} finally {
  try { Pop-Location } catch {}
}

# 2) Detect placeholder "(fill)" in project/infra files
$placeholders = @()
try {
  $targets = @(
    Join-Path $workspace 'memory/projects',
    Join-Path $workspace 'memory/infra'
  )
  foreach ($t in $targets) {
    if (!(Test-Path $t)) { continue }
    Get-ChildItem -Path $t -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
      $c = Get-Content $_.FullName -Raw
      if ($c -match '\(fill\)') { $placeholders += ("memory/" + $_.Directory.Name + "/" + $_.Name) }
    }
  }
} catch {
  # ignore
}

# 3) Check MEMORY.md index completeness for projects
$indexMissing = @()
try {
  $memPath = Join-Path $workspace 'MEMORY.md'
  $memText = if (Test-Path $memPath) { Get-Content $memPath -Raw } else { '' }
  $projDir = Join-Path $workspace 'memory/projects'
  if (Test-Path $projDir) {
    Get-ChildItem -Path $projDir -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.Name -eq 'README.md') { return }
      $rel = "memory/projects/$($_.Name)"
      if ($memText -notmatch [Regex]::Escape($rel)) { $indexMissing += $rel }
    }
  }
} catch {
  # ignore
}

# === Recap block appended to today ===
$recap = @()
$recap += ""
$recap += "## Daily Review (auto)"
$recap += "- Backup(Qiniu): " + ($(if ($backupOk) { "OK" } else { "FAILED" }))
if (-not $backupOk -and $backupErr) { $recap += "  - Error: $backupErr" }

if ($gitOk) {
  if ($changedMemory.Count -gt 0) {
    $recap += "- Changes(git): " + ($changedMemory -join ', ')
  } else {
    $recap += "- Changes(git): none (memory)"
  }
} else {
  $recap += "- Changes(git): unavailable"
}

if ($placeholders.Count -gt 0) {
  $recap += "- Incomplete docs (contain '(fill)'): " + ($placeholders -join ', ')
}

if ($indexMissing.Count -gt 0) {
  $recap += "- MEMORY.md index missing entries: " + ($indexMissing -join ', ')
}

$recap += "- Notes: 请补充——今日关键教训/被纠正点/低效操作；并决定哪些结论需要沉淀进 MEMORY.md（删除过时项）。"
$recap += ""

if ($config.output.appendToDaily) {
  Add-Content -Path $dailyFile -Value ($recap -join "`n")
}

if ($config.output.briefToStdout) {
  Write-Output ("同步: {0}" -f ($(if ($backupOk) { "成功" } else { "失败(继续复盘)" })))
  if (-not $backupOk -and $backupErr) { Write-Output ("同步报错: {0}" -f $backupErr) }
  if ($placeholders.Count -gt 0) { Write-Output ("未补全模板: {0}" -f ($placeholders -join ', ')) }
  if ($indexMissing.Count -gt 0) { Write-Output ("索引缺失: {0}" -f ($indexMissing -join ', ')) }
  Write-Output "复盘: 已在今日文件追加 Daily Review 段落（请补充内容）。"
}
