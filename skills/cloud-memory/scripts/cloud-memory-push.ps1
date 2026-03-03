$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $here 'cloud-memory.config.json'

if (!(Test-Path $configPath)) { throw "Missing config: $configPath" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$workspace = $config.workspaceRoot
$remote = $config.qiniuRemote
$bucket = $config.bucket
$prefix = $config.prefix

if ([string]::IsNullOrWhiteSpace($workspace)) { throw "workspaceRoot is empty" }
if ([string]::IsNullOrWhiteSpace($remote)) { throw "qiniuRemote is empty" }
if ([string]::IsNullOrWhiteSpace($bucket) -or $bucket -like '*YOUR_BUCKET*') { throw "bucket is not set in cloud-memory.config.json" }
if ([string]::IsNullOrWhiteSpace($prefix)) { $prefix = 'openclaw-memory' }

Write-Host "Pushing memory to $remote:$bucket/$prefix ..."

foreach ($p in $config.paths) {
  $src = Join-Path $workspace $p
  if (!(Test-Path $src)) {
    Write-Host "Skip (missing): $src"
    continue
  }

  $dst = "$remote`:$bucket/$prefix/$p"

  # copy is safer than sync for a small set; use sync if you want deletions to propagate
  rclone copy $src $dst --create-empty-src-dirs --checksum --metadata --transfers 4 --checkers 8
  if ($LASTEXITCODE -ne 0) { throw "rclone failed for $p" }
}

Write-Host "Done."
