param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId = "emulator-5554",

    [Parameter(Mandatory = $false)]
    [string]$EmulatorName = "Pixel_7",

    [Parameter(Mandatory = $false)]
    [int]$WaitSeconds = 180
)

function Get-FlutterDevices {
    try {
        $raw = flutter devices --machine 2>$null
        if (-not $raw) { return @() }
        return ($raw | ConvertFrom-Json)
    }
    catch {
        return @()
    }
}

function Test-FlutterDeviceOnline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    $devices = Get-FlutterDevices
    if (-not $devices) { return $false }

    foreach ($d in $devices) {
        if ($null -ne $d -and ("$($d.id)") -eq $DeviceId) {
            return $true
        }
    }

    return $false
}

if (Test-FlutterDeviceOnline -DeviceId $DeviceId) {
    Write-Host "Emulator '$DeviceId' already online." -ForegroundColor Green
    exit 0
}

Write-Host "Emulator '$DeviceId' not online; launching '$EmulatorName'..." -ForegroundColor Yellow
flutter emulators --launch $EmulatorName | Out-Host

$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    if (Test-FlutterDeviceOnline -DeviceId $DeviceId) {
        Write-Host "Emulator '$DeviceId' is online." -ForegroundColor Green
        exit 0
    }

    Start-Sleep -Seconds 2
}

Write-Error "Timed out waiting for emulator '$DeviceId' to come online (waited ${WaitSeconds}s)."
exit 1
