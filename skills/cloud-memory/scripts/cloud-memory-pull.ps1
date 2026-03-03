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

Write-Host "Pulling memory from $remote:$bucket/$prefix ..."

foreach ($p in $config.paths) {
  $dst = Join-Path $workspace $p
  $src = "$remote`:$bucket/$prefix/$p"

  # copydown; does not delete local files
  rclone copy $src $dst --create-empty-src-dirs --checksum --metadata --transfers 4 --checkers 8
  if ($LASTEXITCODE -ne 0) { throw "rclone failed for $p" }
}

Write-Host "Done."
