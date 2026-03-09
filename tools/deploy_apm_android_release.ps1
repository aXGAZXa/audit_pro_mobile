[CmdletBinding()]
param(
    [string]$ArtifactsDir = "W:\AuditProMobile\_artifacts\apm-android",
    [string]$SourceApk
)

$ErrorActionPreference = 'Stop'

function Assert-Path([string]$Path, [string]$Message) {
    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

Assert-Path $ArtifactsDir "Artifacts directory not found: $ArtifactsDir"

if ([string]::IsNullOrWhiteSpace($SourceApk)) {
    $candidate = Get-ChildItem -Path $ArtifactsDir -File -Filter "audit-pro-mobile-*-release.apk" |
    Where-Object { $_.Name -ne "audit-pro-mobile-release.apk" } |
    Sort-Object -Property LastWriteTimeUtc -Descending |
    Select-Object -First 1

    if (-not $candidate) {
        throw "No versioned APK found in: $ArtifactsDir"
    }

    $SourceApk = $candidate.FullName
}

Assert-Path $SourceApk "Source APK not found: $SourceApk"

$destApk = Join-Path $ArtifactsDir "audit-pro-mobile-release.apk"
Copy-Item -Force $SourceApk $destApk

$hash = Get-FileHash -Algorithm SHA256 -Path $destApk
$shaPath = Join-Path $ArtifactsDir "audit-pro-mobile-release.apk.sha256"
($hash.Hash.ToLowerInvariant()) | Out-File -Encoding ascii -NoNewline $shaPath

Write-Host "Deployed APM APK:" -ForegroundColor Cyan
Write-Host "  Source: $SourceApk" -ForegroundColor Gray
Write-Host "  Target: $destApk" -ForegroundColor Green
Write-Host "  SHA:    $shaPath" -ForegroundColor Green
