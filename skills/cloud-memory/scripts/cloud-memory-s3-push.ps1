$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $here 'cloud-memory-s3.config.json'
if (!(Test-Path $configPath)) { throw "Missing config: $configPath" }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$workspace = $config.workspaceRoot
$endpoint = $config.endpoint
$bucket = $config.bucket
$prefix = $config.prefix

if ([string]::IsNullOrWhiteSpace($workspace)) { throw "workspaceRoot is empty" }
if ([string]::IsNullOrWhiteSpace($endpoint)) { throw "endpoint is empty" }
if ([string]::IsNullOrWhiteSpace($bucket)) { throw "bucket is empty" }
if ([string]::IsNullOrWhiteSpace($prefix)) { $prefix = 'clawX' }

$ak = $env:QINIU_AK
$sk = $env:QINIU_SK

# Fallback to persisted environment vars (setx writes these)
if ([string]::IsNullOrWhiteSpace($ak)) { $ak = [Environment]::GetEnvironmentVariable('QINIU_AK','User') }
if ([string]::IsNullOrWhiteSpace($sk)) { $sk = [Environment]::GetEnvironmentVariable('QINIU_SK','User') }
if ([string]::IsNullOrWhiteSpace($ak)) { $ak = [Environment]::GetEnvironmentVariable('QINIU_AK','Machine') }
if ([string]::IsNullOrWhiteSpace($sk)) { $sk = [Environment]::GetEnvironmentVariable('QINIU_SK','Machine') }

if ([string]::IsNullOrWhiteSpace($ak) -or [string]::IsNullOrWhiteSpace($sk)) {
  throw "Missing QINIU_AK / QINIU_SK. Set them via setx or env vars (do NOT paste keys into chat)."
}

# Requires AWS CLI v2 (works with S3-compatible providers)
$aws = 'C:\\Program Files\\Amazon\\AWSCLIV2\\aws.exe'
if (!(Test-Path $aws)) { $aws = 'aws' }
try { & $aws --version | Out-Null } catch { throw "AWS CLI not found. Install AWS CLI v2 first." }

$env:AWS_ACCESS_KEY_ID = $ak
$env:AWS_SECRET_ACCESS_KEY = $sk
$env:AWS_EC2_METADATA_DISABLED = 'true'

Write-Host "Pushing memory to S3-compatible endpoint..."
Write-Host "  endpoint: $endpoint"
Write-Host "  bucket:   $bucket"
Write-Host "  prefix:   $prefix"

foreach ($p in $config.paths) {
  $src = Join-Path $workspace $p
  if (!(Test-Path $src)) {
    Write-Host "Skip (missing): $src"
    continue
  }

  $dst = "s3://$bucket/$prefix/$p"

  if ((Get-Item $src).PSIsContainer) {
    & $aws s3 sync $src $dst --endpoint-url $endpoint --no-progress
  } else {
    & $aws s3 cp $src $dst --endpoint-url $endpoint --no-progress
  }

  if ($LASTEXITCODE -ne 0) { throw "aws s3 upload failed for $p" }
}

Write-Host "Done."
