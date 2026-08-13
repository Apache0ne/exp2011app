param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Read the same trusted-root certificate stores Windows uses for the current
# user and local machine. This script never adds, removes, imports, or changes
# certificates. It only writes a PEM copy to OutputPath for OpenSSL.
$storePaths = @(
    'Cert:\CurrentUser\Root',
    'Cert:\LocalMachine\Root'
)

$certByThumbprint = @{}
foreach ($storePath in $storePaths) {
    if (-not (Test-Path $storePath)) {
        continue
    }

    foreach ($cert in @(Get-ChildItem -Path $storePath -ErrorAction Stop)) {
        if ($null -eq $cert -or $null -eq $cert.RawData -or $cert.RawData.Length -eq 0) {
            continue
        }

        $thumbprint = [string]$cert.Thumbprint
        if ([string]::IsNullOrWhiteSpace($thumbprint)) {
            $thumbprint = [Convert]::ToBase64String(
                [Security.Cryptography.SHA256]::Create().ComputeHash($cert.RawData)
            )
        }

        if (-not $certByThumbprint.ContainsKey($thumbprint)) {
            $certByThumbprint[$thumbprint] = $cert
        }
    }
}

$certificates = @($certByThumbprint.Values | Sort-Object Subject, Thumbprint)
if ($certificates.Count -lt 10) {
    throw "Windows trusted-root export returned only $($certificates.Count) certificates; refusing to create an incomplete TLS trust bundle."
}

$parent = Split-Path -Parent $OutputPath
if ([string]::IsNullOrWhiteSpace($parent)) {
    throw 'OutputPath must include a parent directory.'
}
New-Item -ItemType Directory -Force $parent | Out-Null

$lines = New-Object 'System.Collections.Generic.List[string]'
foreach ($cert in $certificates) {
    [void]$lines.Add('-----BEGIN CERTIFICATE-----')
    $base64 = [Convert]::ToBase64String($cert.RawData)
    for ($offset = 0; $offset -lt $base64.Length; $offset += 64) {
        $length = [Math]::Min(64, $base64.Length - $offset)
        [void]$lines.Add($base64.Substring($offset, $length))
    }
    [void]$lines.Add('-----END CERTIFICATE-----')
}

# PEM is ASCII by definition. Set-Content on Windows PowerShell 5.1 writes this
# without changing the system certificate stores.
$lines | Set-Content -Path $OutputPath -Encoding ASCII

if (-not (Test-Path $OutputPath -PathType Leaf)) {
    throw 'Failed to create the Windows TLS trust bundle.'
}

$writtenText = Get-Content -Path $OutputPath -Raw
$beginCount = ([regex]::Matches($writtenText, '-----BEGIN CERTIFICATE-----')).Count
$endCount = ([regex]::Matches($writtenText, '-----END CERTIFICATE-----')).Count
if ($beginCount -ne $certificates.Count -or $endCount -ne $certificates.Count) {
    throw "TLS trust bundle validation failed: expected $($certificates.Count) certificates, found BEGIN=$beginCount END=$endCount."
}

$hash = (Get-FileHash $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Windows trusted-root PEM export: PASS ($($certificates.Count) certificates, SHA256 $hash)" -ForegroundColor Green
