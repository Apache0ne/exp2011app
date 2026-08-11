from __future__ import annotations

import pathlib
import sys


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: patch_sideloader.py <Sideloader source root>")

    root = pathlib.Path(sys.argv[1]).resolve()
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
    print(f"Patched {cli}")


if __name__ == "__main__":
    main()
