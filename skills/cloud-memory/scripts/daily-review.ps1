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

# 3) Check MEMORY.md baseline/index quality
$indexMissing = @()
$indexBroken = @()
$indexDuplicates = @()
try {
  $memPath = Join-Path $workspace 'MEMORY.md'
  $memText = if (Test-Path $memPath) { Get-Content $memPath -Raw } else { '' }

  # 3a) Missing: project files not referenced by MEMORY.md
  $projDir = Join-Path $workspace 'memory/projects'
  if (Test-Path $projDir) {
    Get-ChildItem -Path $projDir -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
      if ($_.Name -eq 'README.md') { return }
      $rel = "memory/projects/$($_.Name)"
      if ($memText -notmatch [Regex]::Escape($rel)) { $indexMissing += $rel }
    }
  }

  # 3b) Broken refs: referenced memory files that do not exist locally
  $refs = @()
  foreach ($m in [Regex]::Matches($memText, "memory/(projects|infra)/[^\s`\)\]]+\.md")) {
    $refs += $m.Value
  }
  foreach ($r in $refs) {
    $full = Join-Path $workspace $r
    if (!(Test-Path $full)) { $indexBroken += $r }
  }

  # 3c) Duplicates: same ref mentioned multiple times
  $groups = $refs | Group-Object
  foreach ($g in $groups) {
    if ($g.Count -gt 1) { $indexDuplicates += ("{0} (x{1})" -f $g.Name, $g.Count) }
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
if ($indexBroken.Count -gt 0) {
  $recap += "- MEMORY.md broken refs (file missing): " + ($indexBroken -join ', ')
}
if ($indexDuplicates.Count -gt 0) {
  $recap += "- MEMORY.md duplicate refs: " + ($indexDuplicates -join ', ')
}

$recap += "- Notes: 请补充——今日关键教训/被纠正点/低效操作；并决定哪些结论需要沉淀进 MEMORY.md（删除过时项）。"
$recap += "- 纠正点清单:"
$recap += "  - (例) 我误解了 X → 以后遇到 Y 先 memory_search 再行动。"
$recap += "- 低效操作清单:"
$recap += "  - (例) 反复让你提供同一信息 → 建立项目/服务器档案并索引。"
$recap += ""

if ($config.output.appendToDaily) {
  Add-Content -Path $dailyFile -Value ($recap -join "`n")
}

if ($config.output.briefToStdout) {
  # Three-part briefing (per spec)
  Write-Output "同步:"
  Write-Output ("- 七牛同步: {0}" -f ($(if ($backupOk) { "成功" } else { "失败(继续复盘)" })))
  if (-not $backupOk -and $backupErr) { Write-Output ("  - 报错: {0}" -f $backupErr) }

  Write-Output "复盘:"
  if ($placeholders.Count -gt 0) { Write-Output ("- 未补全模板: {0}" -f ($placeholders -join ', ')) } else { Write-Output "- 未补全模板: 无" }
  if ($indexMissing.Count -gt 0) { Write-Output ("- 索引缺失: {0}" -f ($indexMissing -join ', ')) } else { Write-Output "- 索引缺失: 无" }
  if ($indexBroken.Count -gt 0) { Write-Output ("- 索引坏链: {0}" -f ($indexBroken -join ', ')) } else { Write-Output "- 索引坏链: 无" }
  if ($indexDuplicates.Count -gt 0) { Write-Output ("- 索引重复: {0}" -f ($indexDuplicates -join ', ')) } else { Write-Output "- 索引重复: 无" }

  Write-Output "建议:"
  if ($placeholders.Count -gt 0) {
    Write-Output "- 优先把 '(fill)' 的项目/主机档案补全（不然下次部署还会问你）。"
  } else {
    Write-Output "- 今日无强制补全项。"
  }
  if ($indexMissing.Count -gt 0) {
    Write-Output "- 把未收录的项目文件补进 MEMORY.md 项目索引。"
  }
  if ($indexBroken.Count -gt 0) {
    Write-Output "- 清理 MEMORY.md 里引用但文件不存在的条目（或补回对应文件）。"
  }
}
