#!/usr/bin/env bash
# Exercise the actual repair CLI and the installer's shared pure renderer.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$HERE/.." && pwd)"
# shellcheck source=../desktop-entry.sh
source "$ROOT/desktop-entry.sh"
FIXTURE="$(mktemp -d)"
trap 'rm -rf -- "$FIXTURE"' EXIT
export HOME="$FIXTURE/home"
mkdir -p "$HOME" "$FIXTURE/stubs"
# Do not contact the live desktop metadata service.
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE/stubs/gio"
chmod +x "$FIXTURE/stubs/gio"
export PATH="$FIXTURE/stubs:$PATH"
export TOGLIT_LAUNCH_RESULT="$FIXTURE/launched-path"

for name in 'Power & Tools' 'quote"dir' 'slash\dir' 'cash$dir' 'percent%dir' 'literal%f%Udir' 'tick`dir' 'all & "\$%` chars'; do
    dir="$FIXTURE/$name"
    mkdir -p "$dir/icons"
    cp "$ROOT/toglit" "$ROOT/desktop-entry.sh" "$ROOT/toglit.desktop" "$dir/"
    cp "$ROOT/icons/toglit.svg" "$dir/icons/"
    bash "$dir/toglit" --create-shortcut > "$FIXTURE/output"
    entry="$HOME/Desktop/toglit.desktop"
    # Installer and repair must use identical encoding, with no gsub semantics.
    render_desktop_entry "$ROOT/toglit.desktop" "$dir/toglit" "$dir/icons/toglit.svg" > "$FIXTURE/installer.desktop"
    cmp "$FIXTURE/installer.desktop" "$entry"
    cmp "$entry" "$HOME/.local/share/applications/toglit.desktop"
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$entry"
    fi
    # Only a harmless fixture executable is launched, never the product TUI.
    printf '%s\n' '#!/bin/sh' 'printf "%s" "$0" > "$TOGLIT_LAUNCH_RESULT"' > "$dir/toglit"
    chmod +x "$dir/toglit"
    if /usr/bin/python3 -c 'import gi' >/dev/null 2>&1; then
        /usr/bin/python3 "$HERE/parse-launcher.py" "$entry" "$dir/toglit" "$dir/icons/toglit.svg"
    else
        echo 'UNVERIFIED: Gio parser smoke requires python3-gi' >&2
    fi
done
if render_desktop_entry "$ROOT/toglit.desktop" $'/tmp/newline\nExec=bad' icon >/dev/null; then
    echo 'FAIL: newline executable accepted' >&2; exit 1
fi
printf '[Desktop Entry]\nExec=wrong\n' > "$FIXTURE/bad-template"
if render_desktop_entry "$FIXTURE/bad-template" /tmp/toglit icon >/dev/null; then
    echo 'FAIL: malformed template accepted' >&2; exit 1
fi
printf 'Launcher fixtures passed: literal renderer/repair CLI; spaces, &, quotes, backslashes, $, %%, backticks; invalid input refused.\n'
