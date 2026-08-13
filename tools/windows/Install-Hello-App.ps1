$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$env:PATH = "$root;$env:PATH"
$appleDevicesStoreId = '9NP83LWLPZ9K'

# Keep this experiment's Apple/ADI state separate from other applications.
# The installer writes only here and inside the extracted release folder.
$stateBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $env:APPDATA }
$stateRoot = Join-Path $stateBase 'Exp2011App\SideloaderRuntime-v5'

function Stop-Friendly([string]$Message, [int]$Code = 1) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit $Code
}

function Assert-NotElevated {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Stop-Friendly "Do not run this installer as Administrator. Close it and run Install-Hello-App.cmd normally. The sideload flow does not require administrator privileges." 2
        }
    } catch {
        Write-Host "Could not determine elevation state; continuing as the current user." -ForegroundColor Yellow
    }
}

function Verify-BundleIntegrity {
    $manifest = Join-Path $root 'BUNDLE-SHA256SUMS.txt'
    if (-not (Test-Path $manifest)) {
        Stop-Friendly "Safety manifest BUNDLE-SHA256SUMS.txt is missing. Do not run this package." 3
    }

    $entries = @(Get-Content $manifest | Where-Object { $_ -and -not $_.StartsWith('#') })
    if ($entries.Count -eq 0) {
        Stop-Friendly "Safety manifest is empty. Do not run this package." 3
    }

    foreach ($line in $entries) {
        $parts = $line -split "`t", 2
        if ($parts.Count -ne 2) {
            Stop-Friendly "Malformed safety manifest entry: $line" 3
        }
        $expected = $parts[0].Trim().ToUpperInvariant()
        $relative = $parts[1].Trim()
        if ($expected -notmatch '^[0-9A-F]{64}$') {
            Stop-Friendly "Invalid SHA256 in safety manifest for $relative" 3
        }

        $path = Join-Path $root $relative
        if (-not (Test-Path $path -PathType Leaf)) {
            Stop-Friendly "Release file is missing: $relative" 3
        }
        $actual = (Get-FileHash $path -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actual -ne $expected) {
            Stop-Friendly "Release integrity check failed for $relative. Delete this folder and download the ZIP again from GitHub Releases." 3
        }
    }

    Write-Host "Release SHA256 integrity checks: PASS" -ForegroundColor Green
}

function Initialize-WindowsTlsTrust {
    $helper = Join-Path $root 'New-WindowsTrustBundle.ps1'
    if (-not (Test-Path $helper -PathType Leaf)) {
        Stop-Friendly "Windows TLS trust helper is missing from the release." 3
    }

    $caFile = Join-Path $stateRoot 'windows-trusted-roots.pem'
    try {
        & $helper -OutputPath $caFile
    } catch {
        Stop-Friendly "Could not export the read-only Windows trusted-root certificate stores for TLS verification: $($_.Exception.Message)" 8
    }

    if (-not (Test-Path $caFile -PathType Leaf)) {
        Stop-Friendly "Windows TLS trust bundle was not created." 8
    }

    $env:SSL_CERT_FILE = $caFile
    Write-Host "Sideloader TLS trust: Windows trusted roots via SSL_CERT_FILE" -ForegroundColor Green
}

function Get-ConnectedDevices {
    $tool = Join-Path $root 'idevice_id.exe'
    if (-not (Test-Path $tool)) { return }
    try {
        $lines = & $tool -l 2>$null
        $lines | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    } catch {
        return
    }
}

function Get-ConnectedDeviceArray {
    # Windows PowerShell unwraps a one-item pipeline result to a scalar.
    return @(Get-ConnectedDevices)
}

function Start-AppleDevicesApp {
    try {
        $entry = Get-StartApps | Where-Object { $_.Name -eq 'Apple Devices' } | Select-Object -First 1
        if ($entry) {
            Write-Host "Starting the already-installed Apple Devices app..." -ForegroundColor Cyan
            Start-Process "shell:AppsFolder\$($entry.AppID)" -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
            return $true
        }
    } catch {
        Write-Host "Could not auto-start Apple Devices: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $false
}

function Require-AppleDeviceSupport {
    Write-Host ""
    Write-Host "Windows cannot currently see the iPhone through Apple device services." -ForegroundColor Yellow
    Write-Host "For safety, this installer will NOT install or modify Windows software automatically."
    Write-Host "Install/open Apple's official 'Apple Devices' app from Microsoft Store, then reconnect and unlock the iPhone."
    Write-Host "Microsoft Store product ID: $appleDevicesStoreId"
    Write-Host ""
    Stop-Friendly "Apple device support is not ready. Open Apple Devices yourself, confirm the iPhone appears there, then rerun this installer." 4
}

function Require-DeveloperMode([string]$Udid) {
    $tool = Join-Path $root 'idevicedevmodectl.exe'
    if (-not (Test-Path $tool)) {
        Stop-Friendly "Developer Mode status tool is missing from the release." 5
    }

    try {
        $statusText = (& $tool --udid $Udid list 2>&1 | Out-String)
    } catch {
        Write-Host "Could not read Developer Mode status. The installer will not attempt to change it automatically." -ForegroundColor Yellow
        return
    }

    $disabledPattern = '(?im)^\s*' + [regex]::Escape($Udid) + '\s+disabled\s*$'
    if ($statusText -notmatch $disabledPattern) {
        return
    }

    Write-Host ""
    Write-Host "Developer Mode is disabled." -ForegroundColor Yellow
    Write-Host "This installer intentionally will NOT enable it, reboot the phone, or change this security setting for you."
    Write-Host "On the iPhone, manually use: Settings > Privacy & Security > Developer Mode."
    Write-Host "iOS will explain the security impact and ask you to restart/confirm on the device."
    Stop-Friendly "Enable Developer Mode manually on the iPhone, reconnect/unlock it after the restart, then rerun this installer." 5
}

Assert-NotElevated
New-Item -ItemType Directory -Force $stateRoot | Out-Null
$env:SIDELOADER_CONFIG_DIR = $stateRoot

Write-Host ""
Write-Host "============================================================"
Write-Host " Exp2011App - SAFE Hello iPhone installer"
Write-Host "============================================================"
Write-Host ""
Write-Host "Safety policy for this build:" -ForegroundColor Cyan
Write-Host "  - never runs as Administrator"
Write-Host "  - never installs/updates Windows software automatically"
Write-Host "  - never enables Developer Mode or reboots the iPhone automatically"
Write-Host "  - never erases, restores, updates, or resets the iPhone"
Write-Host "  - verifies packaged files with SHA256 before executing them"
Write-Host "  - verifies Apple's native-library download with TLS using Windows trusted roots"
Write-Host "  - installs only the development-signed Exp2011App IPA after explicit confirmation"
Write-Host "  - keeps its runtime state under: $stateRoot"
Write-Host ""

Verify-BundleIntegrity
Initialize-WindowsTlsTrust

$required = @(
    'sideloader.exe',
    'Exp2011App-unsigned.ipa',
    'idevice_id.exe',
    'idevicepair.exe',
    'idevicedevmodectl.exe',
    'New-WindowsTrustBundle.ps1'
)
foreach ($name in $required) {
    if (-not (Test-Path (Join-Path $root $name))) {
        Stop-Friendly "The release package is incomplete: missing $name" 3
    }
}

Write-Host "Connect the iPhone by USB/USB-C, unlock it, and leave it unlocked." -ForegroundColor Cyan
[void](Start-AppleDevicesApp)
$devices = @(Get-ConnectedDeviceArray)
if ($devices.Count -eq 0) {
    Require-AppleDeviceSupport
}

if ($devices.Count -gt 1) {
    Write-Host "More than one iOS device is connected:" -ForegroundColor Yellow
    $devices | ForEach-Object { Write-Host "  $_" }
    Stop-Friendly "For this test, connect only the iPhone you want to install to." 4
}

$udid = [string]$devices[0]
Write-Host "Detected iPhone: $udid" -ForegroundColor Green
Write-Host "Checking existing trust/pairing..."

& (Join-Path $root 'idevicepair.exe') validate *> $null
$paired = ($LASTEXITCODE -eq 0)

if (-not $paired) {
    Write-Host ""
    Write-Host "This PC is not yet trusted/paired with the iPhone." -ForegroundColor Yellow
    Write-Host "Pairing lets this Windows PC communicate with the unlocked iPhone while it remains trusted."
    $pairAnswer = Read-Host "Type PAIR to request pairing; anything else exits"
    if ($pairAnswer -cne 'PAIR') {
        Stop-Friendly "Pairing cancelled. Nothing was installed on the iPhone." 6
    }

    Write-Host "Keep the iPhone unlocked and tap Trust only if you recognize this PC." -ForegroundColor Cyan
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $pairOutput = & (Join-Path $root 'idevicepair.exe') pair 2>&1
        if ($LASTEXITCODE -eq 0) {
            $paired = $true
            break
        }
        Write-Host ($pairOutput | Out-String).Trim()
        if ($attempt -lt 4) {
            Start-Sleep -Seconds 3
        }
    }
}

if (-not $paired) {
    Stop-Friendly "Pairing did not complete. No app installation was attempted." 6
}

Write-Host "Pairing/trust OK." -ForegroundColor Green
Require-DeveloperMode $udid

Write-Host ""
Write-Host "The next operation WILL make only the changes required for sideloading:" -ForegroundColor Yellow
Write-Host "  1. authenticate to Apple's developer services with the Apple account you enter"
Write-Host "  2. register/use this device and create/download development signing material"
Write-Host "  3. sign Exp2011App-unsigned.ipa"
Write-Host "  4. install that app on this iPhone"
Write-Host "It does NOT request an erase, restore, iOS update, factory reset, jailbreak, or filesystem modification outside the app install."
Write-Host "A free Personal Team profile normally expires after 7 days."
Write-Host ""
$confirm = Read-Host "Type INSTALL to continue; anything else exits"
if ($confirm -cne 'INSTALL') {
    Stop-Friendly "Install cancelled. No app installation was attempted." 7
}

Write-Host ""
Write-Host "Starting Apple development signing + installation..." -ForegroundColor Cyan
Write-Host "Password input is hidden. User-facing TRACE mode is disabled to reduce the chance of sensitive authentication data appearing in logs."
Write-Host ""

& (Join-Path $root 'sideloader.exe') install (Join-Path $root 'Exp2011App-unsigned.ipa') -i
$installCode = $LASTEXITCODE
if ($installCode -ne 0) {
    if ($installCode -eq -1073741819) {
        Stop-Friendly "Sideloader hit Windows native access violation 0xC0000005. Stop here; do not repeatedly retry this binary." $installCode
    }
    Stop-Friendly "Sideloader could not complete the install. No erase/restore operation is part of this installer." $installCode
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " INSTALL COMPLETED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Look for 'exp2011app' on the iPhone and open it."
Write-Host "To remove the test later: delete exp2011app normally from the iPhone."
Write-Host "To restore the normal iPhone security posture after testing: turn Developer Mode off in Settings > Privacy & Security and restart as iOS requests."
exit 0
