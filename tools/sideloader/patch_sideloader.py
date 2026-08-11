from __future__ import annotations

import json
import pathlib
import sys

PROVISION_COMMIT = "7717ce1f7b3c9779fe9982005d07b6665071a239"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


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


def patch_provision_pin(root: pathlib.Path) -> None:
    dub_json = root / "dub.json"
    dub = json.loads(dub_json.read_text(encoding="utf-8"))
    provision = dub["dependencies"]["provision"]
    old = provision.get("version")
    provision["version"] = PROVISION_COMMIT
    dub_json.write_text(json.dumps(dub, indent=4) + "\n", encoding="utf-8")
    print(f"Provision dependency: {old} -> {PROVISION_COMMIT}")

    selections_path = root / "dub.selections.json"
    selections = json.loads(selections_path.read_text(encoding="utf-8"))
    selected = selections["versions"]["provision"]
    if isinstance(selected, dict):
        selected["version"] = PROVISION_COMMIT
    else:
        selections["versions"]["provision"] = {
            "version": PROVISION_COMMIT,
            "repository": "git+https://github.com/Dadoum/Provision.git",
        }
    selections_path.write_text(json.dumps(selections, indent=4) + "\n", encoding="utf-8")
    print(f"Pinned dub selection to Provision {PROVISION_COMMIT}")


def patch_stage_markers(root: pathlib.Path) -> None:
    # These INFO markers survive even if the native Android library access-violates,
    # allowing a physical Windows/iPhone run to identify the exact phase reached.
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
    patch_hidden_password(root)
    patch_provision_pin(root)
    patch_stage_markers(root)


if __name__ == "__main__":
    main()
