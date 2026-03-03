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

# MEMORY.md
$mem = Join-Path $workspace 'MEMORY.md'
$memParent = Split-Path -Parent $mem
if ($memParent) { New-Item -ItemType Directory -Force -Path $memParent | Out-Null }
& $aws s3 cp "s3://$bucket/$prefix/MEMORY.md" $mem --endpoint-url $endpoint --only-show-errors

# Quick sync memory folder (skip weekly/archive)
$dst = Join-Path $workspace 'memory'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
$src = "s3://$bucket/$prefix/memory"

$args = @('s3','sync', $src, $dst, '--endpoint-url', $endpoint, '--only-show-errors')
foreach ($e in $config.quick.exclude) { $args += @('--exclude', $e.Replace('memory/','')) }
foreach ($i in $config.quick.include) { $args += @('--include', $i.Replace('memory/','')) }
& $aws @args

Write-Output 'quick pull done'
