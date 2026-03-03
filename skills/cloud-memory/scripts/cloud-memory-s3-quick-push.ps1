$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $here 'cloud-memory-s3-quick.config.json'
if (!(Test-Path $configPath)) { throw "Missing config: $configPath" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$workspace = $config.workspaceRoot
$endpoint = $config.endpoint
$bucket = $config.bucket
$prefix = $config.prefix

$ak = $env:QINIU_AK
$sk = $env:QINIU_SK
if ([string]::IsNullOrWhiteSpace($ak)) { $ak = [Environment]::GetEnvironmentVariable('QINIU_AK','User') }
if ([string]::IsNullOrWhiteSpace($sk)) { $sk = [Environment]::GetEnvironmentVariable('QINIU_SK','User') }
if ([string]::IsNullOrWhiteSpace($ak)) { $ak = [Environment]::GetEnvironmentVariable('QINIU_AK','Machine') }
if ([string]::IsNullOrWhiteSpace($sk)) { $sk = [Environment]::GetEnvironmentVariable('QINIU_SK','Machine') }
if ([string]::IsNullOrWhiteSpace($ak) -or [string]::IsNullOrWhiteSpace($sk)) { throw 'Missing QINIU_AK/QINIU_SK' }

$aws = 'C:\\Program Files\\Amazon\\AWSCLIV2\\aws.exe'
if (!(Test-Path $aws)) { $aws = 'aws' }

$env:AWS_ACCESS_KEY_ID = $ak
$env:AWS_SECRET_ACCESS_KEY = $sk
$env:AWS_EC2_METADATA_DISABLED = 'true'

# Quick sync: only small/high-signal files, skip weekly/archive
$src = Join-Path $workspace 'memory'
$dst = "s3://$bucket/$prefix/memory"

# MEMORY.md
$mem = Join-Path $workspace 'MEMORY.md'
if (Test-Path $mem) {
  & $aws s3 cp $mem "s3://$bucket/$prefix/MEMORY.md" --endpoint-url $endpoint --only-show-errors
}

if (Test-Path $src) {
  $args = @('s3','sync', $src, $dst, '--endpoint-url', $endpoint, '--only-show-errors')
  foreach ($e in $config.quick.exclude) { $args += @('--exclude', $e) }
  foreach ($i in $config.quick.include) { $args += @('--include', $i.Replace('memory/','')) }
  # NOTE: aws sync include/exclude patterns apply to relative keys under $src
  & $aws @args
}

Write-Output 'quick push done'
