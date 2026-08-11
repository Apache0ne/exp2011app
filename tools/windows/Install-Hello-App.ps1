$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$env:PATH = "$root;$env:PATH"

function Stop-Friendly([string]$Message, [int]$Code = 1) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit $Code
}

function Get-ConnectedDevices {
    $tool = Join-Path $root 'idevice_id.exe'
    if (-not (Test-Path $tool)) { return @() }
    try {
        $lines = & $tool -l 2>$null
        return @($lines | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    } catch {
        return @()
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " Exp2011App - Hello iPhone sideload test"
Write-Host "============================================================"
Write-Host ""
Write-Host "This package signs the unsigned GitHub-built IPA with YOUR Apple"
Write-Host "development identity and installs it to the connected iPhone."
Write-Host "Apple credentials are handled by the bundled open-source Sideloader."
Write-Host ""

$required = @(
    'sideloader.exe',
    'Exp2011App-unsigned.ipa',
    'idevice_id.exe',
    'idevicepair.exe'
)
foreach ($name in $required) {
    if (-not (Test-Path (Join-Path $root $name))) {
        Stop-Friendly "The release package is incomplete: missing $name"
    }
}

$devices = Get-ConnectedDevices
if ($devices.Count -eq 0) {
    Write-Host "No iPhone is visible yet." -ForegroundColor Yellow
    Write-Host "1. Connect the iPhone by USB."
    Write-Host "2. Unlock it."
    Write-Host "3. Tap Trust if iOS asks whether to trust this computer."
    Write-Host ""
    Read-Host "Press Enter after the phone is connected and unlocked" | Out-Null
    $devices = Get-ConnectedDevices
}

if ($devices.Count -eq 0) {
    Stop-Friendly "No iPhone was detected. Reconnect the cable, unlock the phone, and run this installer again."
}

if ($devices.Count -gt 1) {
    Write-Host "More than one iOS device is connected:" -ForegroundColor Yellow
    $devices | ForEach-Object { Write-Host "  $_" }
    Stop-Friendly "For this first test, connect only the iPhone you want to install to."
}

$udid = $devices[0]
Write-Host "Detected iPhone: $udid" -ForegroundColor Green
Write-Host "Checking trust/pairing..."

$validateOutput = & (Join-Path $root 'idevicepair.exe') validate 2>&1
$paired = ($LASTEXITCODE -eq 0)

if (-not $paired) {
    Write-Host "The computer and iPhone are not paired yet." -ForegroundColor Yellow
    Write-Host "Keep the iPhone unlocked and tap Trust when prompted."
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $pairOutput = & (Join-Path $root 'idevicepair.exe') pair 2>&1
        if ($LASTEXITCODE -eq 0) {
            $paired = $true
            break
        }
        Write-Host ($pairOutput | Out-String).Trim()
        if ($attempt -lt 4) {
            Write-Host "Waiting for the Trust prompt..."
            Start-Sleep -Seconds 3
        }
    }
}

if (-not $paired) {
    Stop-Friendly "Pairing did not complete. Unlock the iPhone, accept Trust, reconnect USB, then run this again."
}

Write-Host "Pairing OK." -ForegroundColor Green
Write-Host ""
Write-Host "Starting Apple development signing + installation..." -ForegroundColor Cyan
Write-Host "You will be asked for an Apple ID/password and, when Apple requires it, a 2FA code."
Write-Host "A free Apple developer identity is sufficient for this test, but the app normally expires after 7 days."
Write-Host ""

& (Join-Path $root 'sideloader.exe') install (Join-Path $root 'Exp2011App-unsigned.ipa') -i
$installCode = $LASTEXITCODE
if ($installCode -ne 0) {
    Stop-Friendly "Sideloader could not complete the install. The log above contains the exact failing step." $installCode
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " INSTALL COMPLETED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Look for 'exp2011app' on the iPhone."
Write-Host ""
Write-Host "If iOS blocks the first launch:"
Write-Host "  - Settings > Privacy & Security > Developer Mode (enable if requested)."
Write-Host "  - Settings > General > VPN & Device Management (trust your developer identity if shown)."
Write-Host "A Developer Mode change can require an iPhone reboot and confirmation on-device."
exit 0
