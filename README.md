# exp2011app

Minimal native iPhone test app used to verify the complete GitHub -> iOS build -> IPA -> sideload path before adding any ML code.

## What it does

The app is intentionally simple. It launches to a SwiftUI screen that says **Hello from exp2011app** and confirms that the basic iOS app is running.

## Build an IPA on GitHub

1. Open the repository on GitHub.
2. Open **Actions**.
3. Run **Build iOS IPA** (or push a change to `main`).
4. When the workflow finishes, download the `Exp2011App-unsigned-ipa` artifact.
5. Extract the artifact ZIP to get `Exp2011App-unsigned.ipa`.

The GitHub workflow builds the app for a real iPhone with Xcode on a macOS runner. Code signing is deliberately disabled. A sideloading tool can re-sign the IPA with your Apple ID during installation.

## Sideload from Windows

The simplest test route is Sideloadly:

1. Install Sideloadly on Windows.
2. Connect the iPhone by USB and trust the computer.
3. Drag `Exp2011App-unsigned.ipa` into Sideloadly.
4. Select the iPhone and sign/install with your Apple ID.
5. If iOS asks you to trust the developer profile, use **Settings -> General -> VPN & Device Management**.

A free Apple developer account normally requires the app to be re-signed periodically.

## Project layout

- `App/` - the two SwiftUI source files.
- `project.yml` - minimal XcodeGen project definition.
- `.github/workflows/build-ios.yml` - generates the Xcode project, builds for `iphoneos`, packages `Payload/Exp2011App.app` into an unsigned IPA, and uploads it as a workflow artifact.

There is deliberately no MLX, model download, image picker, networking, database, or other application logic yet.
