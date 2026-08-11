# exp2011app

Minimal native iPhone test app used to prove the full path from **GitHub source -> Xcode device build -> GitHub Release -> Windows signing -> physical iPhone install** before adding any ML code.

## What the app does

It is intentionally tiny. The SwiftUI screen only says:

- **Hello from exp2011app**
- **This basic iOS app is running on your iPhone.**

No MLX, model download, networking, image editing, database, analytics, or other application logic is included yet.

## Easiest first install from a GitHub Release

Open this repository's **Releases** page on the Windows PC and download the newest:

`Exp2011App-OneClick-Windows.zip`

Then:

1. Extract the ZIP.
2. Connect the iPhone by USB and unlock it.
3. Tap **Trust** on the iPhone if iOS asks whether to trust the computer.
4. Double-click `Install-Hello-App.cmd`.
5. Enter the Apple development-account credentials and 2FA code requested by the bundled open-source Sideloader.
6. When it finishes, look for **exp2011app** on the iPhone.

If iOS blocks the first launch, enable **Settings -> Privacy & Security -> Developer Mode** if requested and trust the developer identity under **Settings -> General -> VPN & Device Management** if iOS shows it.

A free Apple developer identity is enough for this test, but free provisioning normally expires after 7 days and the app must then be signed again.

## What the release contains

- `Exp2011App-unsigned.ipa` - the real `iphoneos` build made by Xcode on GitHub's macOS runner.
- `Exp2011App-OneClick-Windows.zip` - Windows bootstrap package containing the IPA, Dadoum Sideloader built from pinned source, current Windows libimobiledevice tools/runtime, and a guided install script.
- `SHA256SUMS.txt` - checksums for both downloads.

The Windows package includes the exact Sideloader source ZIP used for its binary build. Sideloader is GPL-3.0 licensed; the device communication runtime comes from the open-source libimobiledevice ecosystem.

## Direct download on the iPhone later

The raw IPA is deliberately published on every Release. After an on-device sideload manager such as SideStore has been bootstrapped once, the intended later workflow is:

`GitHub Releases on iPhone -> download Exp2011App-unsigned.ipa -> import/open it in the on-device sideload manager -> sign/install`

Plain iOS does not install an arbitrary unsigned IPA merely by tapping the download; it still needs a valid development signature/provisioning profile.

## Build/release automation

`.github/workflows/build-ios.yml` runs on every push to `main` and on manual dispatch. It:

1. builds the native SwiftUI app for `iphoneos` with Xcode,
2. packages the unsigned IPA,
3. builds Dadoum Sideloader for Windows from pinned open-source source,
4. bundles the current Windows libimobiledevice runtime and pairing tools,
5. creates the Windows one-click ZIP,
6. publishes both files to a new GitHub Release.

All project changes are made directly on `main`; this repository does not require a PR/branch workflow for these experiments.
