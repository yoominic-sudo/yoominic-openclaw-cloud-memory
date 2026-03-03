<#
Best-effort git backup for workspace memory files.
- Adds/commits MEMORY.md + memory/
- Pushes if remote exists
This is optional; use if you want a second backup layer besides Qiniu.
#>

$ErrorActionPreference = 'Stop'

$workspace = 'C:\Users\Administrator.DESKTOP-3UP6KU6\.openclaw\workspace'
Set-Location $workspace

# Stage memory files
git add MEMORY.md memory/ 2>$null

# Commit if there are changes
$changed = git status --porcelain
if ($changed) {
  $msg = "backup(memory): $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  git commit -m $msg | Out-Null
}

# Push if a remote is configured
$remote = (git remote) 2>$null
if ($remote) {
  git push | Out-Null
  Write-Output "Git push: OK"
} else {
  Write-Output "Git push: skipped (no remote)"
}
