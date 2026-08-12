from __future__ import annotations

import json
import pathlib
import sys

EXPECTED_PROVISION_COMMIT = "645d56d8e8c86c057893321843db00b21f1aaeb2"
EXPECTED_PROVISION_REPOSITORY = "git+https://github.com/Dadoum/Provision.git"
EXPECTED_NATIVES_URL = "https://apps.mzstatic.com/content/android-apple-music-apk/applemusic.apk"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def verify_provision_pin(root: pathlib.Path) -> None:
    checks = (
        (root / "dub.json", ("dependencies", "provision")),
        (root / "dub.selections.json", ("versions", "provision")),
    )

    for path, keys in checks:
        payload = json.loads(path.read_text(encoding="utf-8"))
        value = payload
        for key in keys:
            value = value[key]
        if not isinstance(value, dict):
            raise RuntimeError(f"{path}: Provision entry is not a pinned repository dependency")

        version = value.get("version")
        repository = value.get("repository")
        if version != EXPECTED_PROVISION_COMMIT:
            raise RuntimeError(
                f"{path}: upstream Provision pin changed: {version!r}; "
                f"expected {EXPECTED_PROVISION_COMMIT}"
            )
        if repository != EXPECTED_PROVISION_REPOSITORY:
            raise RuntimeError(
                f"{path}: upstream Provision repository changed: {repository!r}; "
                f"expected {EXPECTED_PROVISION_REPOSITORY!r}"
            )

    print(
        "Verified Dadoum/Sideloader upstream Provision pin: "
        f"{EXPECTED_PROVISION_COMMIT}"
    )


def verify_apple_natives_url(root: pathlib.Path) -> None:
    constants = root / "source" / "constants.d"
    text = constants.read_text(encoding="utf-8")
    expected = f'enum nativesUrl = "{EXPECTED_NATIVES_URL}";'
    if expected not in text:
        raise RuntimeError(
            f"{constants}: Apple native-library URL changed; refusing to build. "
            f"Expected exactly {EXPECTED_NATIVES_URL}"
        )
    print(f"Verified Apple natives URL: {EXPECTED_NATIVES_URL}")


def patch_tls_verification(root: pathlib.Path) -> None:
    app_file = root / "source" / "app" / "package.d"
    text = app_file.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "    request.sslSetVerifyPeer(false);",
        "    // exp2011app safety hardening: never disable TLS peer verification for executable native code.\n"
        "    request.sslSetVerifyPeer(true);",
        "Apple Music APK TLS verification patch",
    )
    app_file.write_text(text, encoding="utf-8")
    print(f"Enabled TLS peer verification for Apple Music APK download: {app_file}")


def patch_hidden_password(root: pathlib.Path) -> None:
    cli = root / "frontends" / "cli" / "source" / "cli_frontend.d"
    text = cli.read_text(encoding="utf-8")

    old = r'''string readPasswordLine(string prompt) {
    version (Windows) {
        write(prompt.toStringz(), " [/!\\ The password will appear in clear text in the terminal]: ");
        return readln().chomp();
    } else {
        return fromStringz(cast(immutable) getpass(prompt.toStringz()));
    }
}'''

    new = r'''string readPasswordLine(string prompt) {
    version (Windows) {
        import core.sys.windows.windows :
            DWORD, ENABLE_ECHO_INPUT, GetConsoleMode, GetStdHandle,
            SetConsoleMode, STD_INPUT_HANDLE;

        write(prompt.toStringz(), ": ");
        stdout.flush();

        auto inputHandle = GetStdHandle(STD_INPUT_HANDLE);
        DWORD originalMode = 0;
        if (inputHandle && GetConsoleMode(inputHandle, &originalMode)) {
            SetConsoleMode(inputHandle, originalMode & ~ENABLE_ECHO_INPUT);
            scope(exit) {
                SetConsoleMode(inputHandle, originalMode);
                writeln();
            }
            return readln().chomp();
        }

        return readln().chomp();
    } else {
        return fromStringz(cast(immutable) getpass(prompt.toStringz()));
    }
}'''

    text = replace_once(text, old, new, "Windows hidden-password patch")
    cli.write_text(text, encoding="utf-8")
    print(f"Patched hidden password input: {cli}")


def patch_stage_markers(root: pathlib.Path) -> None:
    # INFO markers identify the exact provisioning phase reached without
    # changing the Provision dependency or the CoreADI ABI implementation.
    app_file = root / "source" / "app" / "package.d"
    text = app_file.read_text(encoding="utf-8")
    old = '''        log.info("Provisioning device...");\n\n        ProvisioningSession provisioningSession = new ProvisioningSession(adi, device);\n        provisioningSession.provision(-2);\n        log.info("Device provisioned successfully.");'''
    new = '''        log.info("Provisioning device...");\n        log.info("PROVISION-STAGE 1/3: creating provisioning session");\n        ProvisioningSession provisioningSession = new ProvisioningSession(adi, device);\n        log.info("PROVISION-STAGE 2/3: entering Apple ADI provisioning protocol");\n        provisioningSession.provision(-2);\n        log.info("PROVISION-STAGE 3/3: Apple ADI provisioning protocol returned");\n        log.info("Device provisioned successfully.");'''
    text = replace_once(text, old, new, "provision stage marker patch")
    app_file.write_text(text, encoding="utf-8")
    print(f"Added provisioning stage markers: {app_file}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_sideloader.py <Sideloader source root>")

    root = pathlib.Path(sys.argv[1]).resolve()

    # Fail closed if the audited upstream dependency graph or Apple-hosted
    # native-library source changes unexpectedly.
    verify_provision_pin(root)
    verify_apple_natives_url(root)

    # Security-only/local-observability changes. Do not alter Provision or the
    # CoreADI ABI bridge itself.
    patch_tls_verification(root)
    patch_hidden_password(root)
    patch_stage_markers(root)

    verify_provision_pin(root)
    verify_apple_natives_url(root)


if __name__ == "__main__":
    main()
