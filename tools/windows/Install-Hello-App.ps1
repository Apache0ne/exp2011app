$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$env:PATH = "$root;$env:PATH"
$appleDevicesStoreId = '9NP83LWLPZ9K'

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

function Install-AppleDeviceSupport {
    Write-Host ""
    Write-Host "Windows cannot see an Apple USB device yet." -ForegroundColor Yellow
    Write-Host "Installing Apple's official Apple Devices component supplies the Windows"
    Write-Host "Apple Mobile Device USB service used by libimobiledevice."
    Write-Host ""

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        $wingetExe = $winget.Source
        Write-Host "Trying Microsoft Store install through WinGet..." -ForegroundColor Cyan
        & $wingetExe install --id $appleDevicesStoreId --source msstore `
            --accept-source-agreements --accept-package-agreements `
            --silent --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Apple Devices install/update completed." -ForegroundColor Green
        } else {
            Write-Host "WinGet could not finish Apple Devices automatically (exit $LASTEXITCODE)." -ForegroundColor Yellow
        }
    }

    $devices = Get-ConnectedDevices
    if ($devices.Count -eq 0) {
        Write-Host "Opening the official Apple Devices Microsoft Store page..." -ForegroundColor Cyan
        Start-Process "ms-windows-store://pdp/?ProductId=$appleDevicesStoreId"
        Write-Host "Install Apple Devices if the Store shows it is not installed."
        Read-Host "After installation, reconnect/unlock the iPhone, tap Trust if prompted, then press Enter" | Out-Null
    }
}

function Ensure-DeveloperMode([string]$Udid) {
    $tool = Join-Path $root 'idevicedevmodectl.exe'
    if (-not (Test-Path $tool)) { return }

    try {
        $statusText = (& $tool --udid $Udid list 2>&1 | Out-String)
    } catch {
        return
    }

    $disabledPattern = '(?im)^\s*' + [regex]::Escape($Udid) + '\s+disabled\s*$'
    if ($statusText -notmatch $disabledPattern) {
        return
    }

    Write-Host ""
    Write-Host "Developer Mode is currently disabled on the iPhone." -ForegroundColor Yellow
    Write-Host "A development-signed sideloaded app needs Developer Mode on iOS 16+."
    Write-Host "The open-source idevicedevmodectl helper can enable/reveal it."
    Write-Host "If the phone has no passcode this can reboot it automatically; with a passcode"
    Write-Host "iOS normally requires you to enable the revealed switch on the phone itself."
    $answer = Read-Host "Try to enable/reveal Developer Mode now? [Y/n]"
    if ($answer -match '^(n|no)$') { return }

    & $tool --udid $Udid enable
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Finish Developer Mode on the iPhone:" -ForegroundColor Yellow
        Write-Host "Settings > Privacy & Security > Developer Mode"
        Write-Host "iOS may reboot and ask for an on-device confirmation."
        Read-Host "Press Enter after Developer Mode is enabled and the iPhone is unlocked again" | Out-Null
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
    'idevicepair.exe',
    'idevicedevmodectl.exe'
)
foreach ($name in $required) {
    if (-not (Test-Path (Join-Path $root $name))) {
        Stop-Friendly "The release package is incomplete: missing $name"
    }
}

Write-Host "Connect the iPhone by USB, unlock it, and leave it unlocked." -ForegroundColor Cyan
$devices = Get-ConnectedDevices
if ($devices.Count -eq 0) {
    Install-AppleDeviceSupport
    Start-Sleep -Seconds 2
    $devices = Get-ConnectedDevices
}

if ($devices.Count -eq 0) {
    Write-Host "No iPhone is visible yet." -ForegroundColor Yellow
    Write-Host "Reconnect USB, unlock the phone, and tap Trust if iOS asks."
    Read-Host "Press Enter to retry detection" | Out-Null
    $devices = Get-ConnectedDevices
}

if ($devices.Count -eq 0) {
    Stop-Friendly "No iPhone was detected after installing/checking Apple Devices. Try another data-capable USB cable/port, open Apple Devices once, then rerun this installer."
}

if ($devices.Count -gt 1) {
    Write-Host "More than one iOS device is connected:" -ForegroundColor Yellow
    $devices | ForEach-Object { Write-Host "  $_" }
    Stop-Friendly "For this first test, connect only the iPhone you want to install to."
}

$udid = $devices[0]
Write-Host "Detected iPhone: $udid" -ForegroundColor Green
Write-Host "Checking trust/pairing..."

& (Join-Path $root 'idevicepair.exe') validate *> $null
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
Ensure-DeveloperMode $udid

Write-Host ""
Write-Host "Starting Apple development signing + installation..." -ForegroundColor Cyan
Write-Host "Sideloader will ask for an Apple ID/password and, when Apple requires it, a 2FA code."
Write-Host "A free Apple developer identity is sufficient for this test; free provisioning normally expires after 7 days."
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
Write-Host "Look for 'exp2011app' on the iPhone and open it."
Write-Host "If iOS still blocks launch, finish Developer Mode under Settings > Privacy & Security"
Write-Host "and trust your developer identity under Settings > General > VPN & Device Management if shown."
exit 0
