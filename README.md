# exp2011app

Minimal native iPhone test app used to prove the full path from **GitHub source -> Xcode device build -> GitHub Release -> Windows signing -> physical iPhone install** before adding any ML code.

## What the app does

It is intentionally tiny. The SwiftUI screen only says:

- **Hello from exp2011app**
- **This basic iOS app is running on your iPhone.**

No MLX, model download, networking, image editing, database, analytics, or other application logic is included yet.

## Easiest first install from a GitHub Release

Open this repository's **Releases** page on the Windows PC and use the release marked **Latest**. Download:

`Exp2011App-OneClick-Windows.zip`

Then:

1. Extract the ZIP.
2. Connect the iPhone by USB and unlock it.
3. Double-click `Install-Hello-App.cmd`.
4. The launcher attempts to start Apple's **Apple Devices** app automatically so its USB/mobile-device service is available.
5. Tap **Trust** on the iPhone when iOS asks.
6. If Developer Mode is disabled, the launcher detects that and offers to enable/reveal it using the bundled open-source `idevicedevmodectl` helper. iOS may require a reboot/on-device confirmation.
7. Enter the Apple development-account credentials and 2FA code requested by the bundled open-source Sideloader.
8. When it finishes, open **exp2011app** on the iPhone.

A free Apple developer identity is enough for this test. Free provisioning normally expires after 7 days, so the app has to be signed again after that.

The Windows launcher is regression-tested under Windows PowerShell 5.1, including the exact **one connected iPhone** case that previously caused scalar `.Count` failures.

The Release is blocked until a GitHub **Windows** runner executes the same Apple Music/CoreADI provisioning path used by Sideloader, successfully provisions a fresh ADI identity, and reaches the login stage without a native Windows access violation. This catches provisioning crashes before using a physical iPhone as the test machine.

## Sideloader build parity

The Windows Sideloader executable is no longer compiled natively on the Windows runner. It now follows Dadoum/Sideloader's own Windows CI strategy for the audited source revision:

- Sideloader commit: `a589cf11a3ac7c1c26b2f18aa5acdc8afb6dc915`
- Provision commit: `645d56d8e8c86c057893321843db00b21f1aaeb2` — the pin already present in that Sideloader revision
- compiler: `ldc-1.34.0`
- build host: `ubuntu-22.04`
- target: `x86_64-windows-msvc`
- build mode: `release-debug`
- linker/target setup: Dadoum's LDC Windows cross-target configuration, including the Windows multilib runtime

This matters because Provision/CoreADI crosses the Windows x64 and SysV x86-64 ABIs. The previous pipeline changed both the Provision revision and compiler/build path while debugging an `0xC0000005` access violation.

Our source patcher now **refuses to rewrite the Provision dependency**. It verifies Dadoum's exact upstream pin before and after applying only two local changes:

1. hidden password input on Windows,
2. diagnostic provisioning stage markers.

The exact cross-built `sideloader.exe` is then downloaded by the Windows job and used for the live CoreADI preflight. The installer is not published unless that binary passes the preflight.

## What the release contains

- `Exp2011App-unsigned.ipa` - the real ARM64 `iphoneos` build made by Xcode on GitHub's macOS runner.
- `Exp2011App-OneClick-Windows.zip` - Windows bootstrap package containing the IPA, Dadoum Sideloader built from pinned source, Windows libimobiledevice pairing/device tools and runtime, and the guided installer.
- `SHA256SUMS.txt` - checksums for both downloads.

The Windows package also contains `sideloader-build-metadata.txt` plus the exact patched Sideloader source ZIP corresponding to the executable. Sideloader is GPL-3.0 licensed; the device communication runtime comes from the open-source libimobiledevice ecosystem.

## Direct download on the iPhone later

The raw IPA is deliberately published on every Release. After an on-device sideload manager such as SideStore has been bootstrapped once, the intended later workflow is:

`GitHub Releases on iPhone -> download Exp2011App-unsigned.ipa -> import/open it in the on-device sideload manager -> sign/install`

Plain iOS does not install an arbitrary unsigned IPA merely by tapping the download; it still needs a valid development signature/provisioning profile.

## Build/release automation

`.github/workflows/build-ios.yml` runs on every normal push to `main` and on manual dispatch. It:

1. builds the native SwiftUI app for `iphoneos` with Xcode,
2. packages the unsigned IPA,
3. cross-builds Sideloader on Ubuntu with LDC 1.34.0 for `x86_64-windows-msvc` using Dadoum's target configuration,
4. verifies the upstream Provision pin instead of replacing it,
5. transfers that exact Windows executable to a Windows runner,
6. performs a fresh real Apple ADI/CoreADI provisioning preflight there,
7. bundles the Windows libimobiledevice runtime and pairing tools,
8. regression-tests the Windows launcher and smoke-tests the packaged executables,
9. creates the Windows one-click ZIP,
10. publishes the IPA, Windows ZIP and SHA256 checksums only after all gates pass,
11. writes the final CI result to `build-status.json` on `main` so the exact release pipeline can be verified.

All experimental project changes are committed directly to `main`; no PR/branch workflow is used for this test repository.
