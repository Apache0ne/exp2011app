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
4. If Windows does not yet have Apple's USB/device support, the launcher attempts to install the official **Apple Devices** app from the Microsoft Store automatically and then retries the phone.
5. Tap **Trust** on the iPhone when iOS asks.
6. If Developer Mode is disabled, the launcher detects that and offers to enable/reveal it using the bundled open-source `idevicedevmodectl` helper. iOS may require a reboot/on-device confirmation.
7. Enter the Apple development-account credentials and 2FA code requested by the bundled open-source Sideloader.
8. When it finishes, open **exp2011app** on the iPhone.

A free Apple developer identity is enough for this test. Free provisioning normally expires after 7 days, so the app has to be signed again after that.

## What the release contains

- `Exp2011App-unsigned.ipa` - the real ARM64 `iphoneos` build made by Xcode on GitHub's macOS runner.
- `Exp2011App-OneClick-Windows.zip` - Windows bootstrap package containing the IPA, Dadoum Sideloader built from pinned source, Windows libimobiledevice pairing/device tools and runtime, and the guided installer.
- `SHA256SUMS.txt` - checksums for both downloads.

The Windows package also contains the exact Sideloader source ZIP used to build its binary. Sideloader is GPL-3.0 licensed; the device communication runtime comes from the open-source libimobiledevice ecosystem.

## Direct download on the iPhone later

The raw IPA is deliberately published on every Release. After an on-device sideload manager such as SideStore has been bootstrapped once, the intended later workflow is:

`GitHub Releases on iPhone -> download Exp2011App-unsigned.ipa -> import/open it in the on-device sideload manager -> sign/install`

Plain iOS does not install an arbitrary unsigned IPA merely by tapping the download; it still needs a valid development signature/provisioning profile.

## Build/release automation

`.github/workflows/build-ios.yml` runs on every normal push to `main` and on manual dispatch. It:

1. builds the native SwiftUI app for `iphoneos` with Xcode,
2. packages the unsigned IPA,
3. builds Dadoum Sideloader for Windows from a pinned open-source commit,
4. bundles the Windows libimobiledevice runtime and pairing tools,
5. creates the Windows one-click ZIP,
6. publishes the IPA, Windows ZIP and SHA256 checksums to a new GitHub Release,
7. writes the final CI result to `build-status.json` on `main` so the exact release pipeline can be verified.

All experimental project changes are committed directly to `main`; no PR/branch workflow is used for this test repository.
