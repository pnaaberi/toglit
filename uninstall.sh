#!/usr/bin/env bash
# TOGLIT uninstaller — removes launcher entries. Your KDE settings are untouched;
# run TOGLIT's 'Restore Backup' before uninstalling if you want defaults back.

set -euo pipefail

LOCAL_BIN="$HOME/.local/bin/toglit"
APPS_ENTRY="$HOME/.local/share/applications/toglit.desktop"
DESKTOP_ENTRY="$HOME/Desktop/toglit.desktop"
STATE_DIR="$HOME/.config/toglit"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
say()  { printf '  %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

echo
echo "  Uninstalling TOGLIT..."
echo

for f in "$LOCAL_BIN" "$APPS_ENTRY" "$DESKTOP_ENTRY"; do
    if [[ -e "$f" || -L "$f" ]]; then
        rm -f "$f"
        ok "removed $f"
    fi
done

echo
if [[ -d "$STATE_DIR" ]]; then
    read -rp "  Also remove state directory ($STATE_DIR — includes backups)? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        rm -rf "$STATE_DIR"
        ok "removed $STATE_DIR"
    else
        warn "state kept at $STATE_DIR"
    fi
fi

echo
say "KDE settings are unchanged. If you want defaults restored,"
say "re-run TOGLIT first and choose 'Restore Backup' before uninstalling."
echo
ok "TOGLIT uninstalled."
echo
