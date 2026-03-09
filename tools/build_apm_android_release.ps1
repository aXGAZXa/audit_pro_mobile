[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$OutputDir = "W:\AuditProMobile\_artifacts\apm-android",
    [string]$DefinesFile,
    [int]$BuildNumber = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()),
    [string]$FlutterExe = "flutter"
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

function Remove-FlutterNativeSplashFromRegistrant([string]$ProjectRootResolved) {
    $registrantPath = Join-Path $ProjectRootResolved 'android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java'
    if (-not (Test-Path $registrantPath)) {
        return
    }

    $text = Get-Content -Raw -Path $registrantPath
    if ([string]::IsNullOrWhiteSpace($text)) {
        return
    }

    # flutter_native_splash is typically a dev dependency used to generate assets.
    # Flutter may still generate a registrant entry for it, but the Android plugin
    # isn't on the release classpath for dev-only dependencies, causing javac failures.
    $pattern = '(?s)\s*try\s*\{\s*flutterEngine\.getPlugins\(\)\.add\(new\s+net\.jonhanson\.flutter_native_splash\.FlutterNativeSplashPlugin\(\)\);\s*\}\s*catch\s*\(Exception\s+e\)\s*\{\s*Log\.e\(TAG,\s*"Error registering plugin flutter_native_splash, net\.jonhanson\.flutter_native_splash\.FlutterNativeSplashPlugin",\s*e\);\s*\}\s*'
    $updated = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, "`r`n")

    if ($updated -ne $text) {
        Set-Content -Path $registrantPath -Value $updated -Encoding UTF8
        Write-Host "Patched GeneratedPluginRegistrant.java: removed flutter_native_splash registration" -ForegroundColor Yellow
    }
}

$projectRootResolved = (Resolve-Path $ProjectRoot).Path
Push-Location $projectRootResolved
try {
    $androidDir = Join-Path $projectRootResolved 'android'
    Assert-Path $androidDir "Expected Android folder at: $androidDir"

    $keyProps = Join-Path $androidDir 'key.properties'
    Assert-Path $keyProps "Missing $keyProps. Create it from android/key.properties.example and set real values."

    $definesPath = (Resolve-Path $DefinesFile).Path
    Assert-Path $definesPath "Missing defines file: $definesPath. Create it from auditpromobile.defines.example.json and set real values."

    try {
        $definesJson = Get-Content $definesPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Defines file is not valid JSON: $definesPath"
        throw
    }

    if ([string]::IsNullOrWhiteSpace([string]$definesJson.APM_MOBILE_AUTH_API_KEY)) {
        throw "APM_MOBILE_AUTH_API_KEY is missing/blank in $definesPath"
    }

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

    $fullVersion = "$buildName+$BuildNumber"
    Write-Host "Building APM Android release: versionName=$buildName versionCode=$BuildNumber (full=$fullVersion)" -ForegroundColor Cyan

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    & $FlutterExe --version | Out-Null

    & $FlutterExe clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }

    & $FlutterExe pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

    Remove-FlutterNativeSplashFromRegistrant -ProjectRootResolved $projectRootResolved

    & $FlutterExe build apk --release "--build-name=$buildName" "--build-number=$BuildNumber" "--dart-define-from-file=$definesPath"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk --release failed" }

    $apkPath = Join-Path $projectRootResolved 'build\app\outputs\flutter-apk\app-release.apk'
    Assert-Path $apkPath "APK not found at: $apkPath"

    $destApk = Join-Path $OutputDir "audit-pro-mobile-$fullVersion-release.apk"
    Copy-Item -Force $apkPath $destApk

    $hash = Get-FileHash -Algorithm SHA256 -Path $destApk
    $shaPath = Join-Path $OutputDir "audit-pro-mobile-$fullVersion-release.apk.sha256"
    ($hash.Hash.ToLowerInvariant()) | Out-File -Encoding ascii -NoNewline $shaPath

    Write-Host "OK: $destApk"
    Write-Host "OK: $shaPath"
}
finally {
    Pop-Location
}
