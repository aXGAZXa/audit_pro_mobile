param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId = "emulator-5554",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$definesPath = Join-Path $projectRoot "auditpromobile.defines.json"

Write-Host "Project root: $projectRoot" -ForegroundColor Cyan
Write-Host "Defines file: $definesPath" -ForegroundColor Cyan

if (-not (Test-Path $definesPath)) {
    Write-Error "Defines file not found: $definesPath"
    Write-Host "Create it from: $(Join-Path $projectRoot 'auditpromobile.defines.example.json')" -ForegroundColor Yellow
    exit 1
}

try {
    $json = Get-Content $definesPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Defines file is not valid JSON: $definesPath"
    throw
}

$baseUrl = [string]$json.APM_API_BASE_URL
$key = [string]$json.APM_MOBILE_AUTH_API_KEY
$source = [string]$json.APM_DEFINES_SOURCE

$keySet = -not [string]::IsNullOrWhiteSpace($key)
$keyLen = if ($keySet) { $key.Trim().Length } else { 0 }

Write-Host "APM_API_BASE_URL: $baseUrl" -ForegroundColor Gray
Write-Host "APM_DEFINES_SOURCE: $source" -ForegroundColor Gray
Write-Host "APM_MOBILE_AUTH_API_KEY set: $keySet (len: $keyLen)" -ForegroundColor Gray
Write-Host "Launching Flutter on device '$DeviceId'..." -ForegroundColor Yellow

$flutterArgs = @(
    "run",
    "-d",
    $DeviceId,
    "--dart-define-from-file=$definesPath"
)

Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DryRun: not launching Flutter." -ForegroundColor Cyan
    exit 0
}

Set-Location $projectRoot
flutter @flutterArgs
