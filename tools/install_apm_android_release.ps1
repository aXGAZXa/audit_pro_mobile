[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId = "emulator-5554",

    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $false)]
    [string]$DefinesFile,

    [Parameter(Mandatory = $false)]
    [int]$BuildNumber = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()),

    [Parameter(Mandatory = $false)]
    [string]$FlutterExe = "flutter",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = (Join-Path $PSScriptRoot '..')
}

if ([string]::IsNullOrWhiteSpace($DefinesFile)) {
    $DefinesFile = (Join-Path (Join-Path $PSScriptRoot '..') 'auditpromobile.defines.json')
}

function Assert-Path([string]$Path, [string]$Message) {
    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

$projectRootResolved = (Resolve-Path $ProjectRoot).Path
$definesPath = (Resolve-Path $DefinesFile).Path

Write-Host "Project root: $projectRootResolved" -ForegroundColor Cyan
Write-Host "Defines file: $definesPath" -ForegroundColor Cyan
Write-Host "Target device: $DeviceId" -ForegroundColor Cyan

Assert-Path $definesPath "Missing defines file: $definesPath. Create it from auditpromobile.defines.example.json and set real values."

try {
    $definesJson = Get-Content $definesPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Defines file is not valid JSON: $definesPath"
    throw
}

$key = [string]$definesJson.APM_MOBILE_AUTH_API_KEY
$keySet = -not [string]::IsNullOrWhiteSpace($key)
$keyLen = if ($keySet) { $key.Trim().Length } else { 0 }

Write-Host "APM_MOBILE_AUTH_API_KEY set: $keySet (len: $keyLen)" -ForegroundColor Gray

if (-not $keySet) {
    throw "APM_MOBILE_AUTH_API_KEY is missing/blank in $definesPath"
}

$flutterArgs = @(
    "install",
    "--release",
    "-d",
    $DeviceId
)

Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DryRun: not installing." -ForegroundColor Cyan
    exit 0
}

Push-Location $projectRootResolved
try {
    & $FlutterExe pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

    $pubspecPath = Join-Path $projectRootResolved 'pubspec.yaml'
    Assert-Path $pubspecPath "pubspec.yaml not found at: $pubspecPath"

    $pubspecVersionLine = (Get-Content $pubspecPath | Where-Object { $_ -match '^version\s*:' } | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($pubspecVersionLine)) {
        throw "Unable to find 'version:' in $pubspecPath"
    }

    $pubspecVersion = ($pubspecVersionLine -replace '^version\s*:\s*', '').Trim()
    $buildName = ($pubspecVersion -split '\+')[0].Trim()
    if ([string]::IsNullOrWhiteSpace($buildName)) {
        throw "Invalid pubspec version value: '$pubspecVersion'"
    }

    # --no-tree-shake-icons: the declared-forms runtime renders DATA-DRIVEN icons (non-const IconData
    # built from the form definition), which Flutter's icon tree-shaker rejects. Required since forms
    # became data-driven (unification endgame).
    & $FlutterExe build apk --release --no-tree-shake-icons "--build-name=$buildName" "--build-number=$BuildNumber" "--dart-define-from-file=$definesPath"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed" }

    $apkPath = Join-Path $projectRootResolved 'build\app\outputs\flutter-apk\app-release.apk'
    Assert-Path $apkPath "APK not found at: $apkPath"

    $installArgs = @(
        "install",
        "--release",
        "-d",
        $DeviceId,
        "--use-application-binary=$apkPath"
    )

    Write-Host "flutter $($installArgs -join ' ')" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "DryRun: not installing." -ForegroundColor Cyan
        exit 0
    }

    & $FlutterExe @installArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter install failed" }
}
finally {
    Pop-Location
}
