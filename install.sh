#!/usr/bin/env bash
# TOGLIT installer — idempotent, no sudo required, stays inside $HOME.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOGLIT_BIN="$SCRIPT_DIR/toglit"
DESKTOP_TEMPLATE="$SCRIPT_DIR/toglit.desktop"
ICON_SRC="$SCRIPT_DIR/icons/toglit.svg"

LOCAL_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$HOME/Desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_DEST="$ICON_DIR/toglit.svg"

LEGACY_SCRIPT="$HOME/touch-toggle.sh"
LEGACY_DESKTOP="$DESKTOP_DIR/Touch.desktop"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

echo
echo "  Installing TOGLIT..."
echo

# ---- Sanity ----
[[ -f "$TOGLIT_BIN" ]]         || { err "toglit script not found next to installer"; exit 1; }
[[ -f "$DESKTOP_TEMPLATE" ]] || { err "toglit.desktop template not found";         exit 1; }
[[ -f "$ICON_SRC" ]]          || { err "icon not found at $ICON_SRC";               exit 1; }

# ---- Make scripts executable ----
chmod +x "$TOGLIT_BIN" "$SCRIPT_DIR/install.sh"
[[ -f "$SCRIPT_DIR/uninstall.sh" ]] && chmod +x "$SCRIPT_DIR/uninstall.sh"
ok "scripts are executable"

# ---- Symlink into ~/.local/bin ----
mkdir -p "$LOCAL_BIN"
ln -sfn "$TOGLIT_BIN" "$LOCAL_BIN/toglit"
ok "linked $LOCAL_BIN/toglit → $TOGLIT_BIN"

# ---- Install the icon (must run before desktop rendering so the
#      absolute path we bake into Icon= exists at launch time) ----
mkdir -p "$ICON_DIR"
cp "$ICON_SRC" "$ICON_DEST"
gtk-update-icon-cache -q -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
ok "installed $ICON_DEST"

# ---- Render .desktop files (substitute absolute Exec + Icon paths) ----
mkdir -p "$APPS_DIR" "$DESKTOP_DIR"
render_desktop() {
    # awk with `-v` passes replacements as literal strings, so paths
    # containing `|`, `&`, `\` (which would break a sed replacement) are
    # substituted verbatim.
    local dest="$1"
    awk -v bin="$TOGLIT_BIN" -v icon="$ICON_DEST" '
        { gsub(/__TOGLIT_EXEC__/, bin); gsub(/__TOGLIT_ICON__/, icon); print }
    ' "$DESKTOP_TEMPLATE" > "$dest"
    chmod +x "$dest"
}
render_desktop "$APPS_DIR/toglit.desktop"
render_desktop "$DESKTOP_DIR/toglit.desktop"
gio set -t string "$DESKTOP_DIR/toglit.desktop" metadata::trusted true 2>/dev/null || true
ok "installed $APPS_DIR/toglit.desktop"
ok "installed $DESKTOP_DIR/toglit.desktop (trusted)"

# ---- Offer to remove legacy files ----
have_legacy=0
[[ -f "$LEGACY_SCRIPT"  ]] && have_legacy=1
[[ -f "$LEGACY_DESKTOP" ]] && have_legacy=1

if (( have_legacy )); then
    echo
    say "Legacy 'touch-toggle' files detected:"
    [[ -f "$LEGACY_SCRIPT"  ]] && say "  $LEGACY_SCRIPT"
    [[ -f "$LEGACY_DESKTOP" ]] && say "  $LEGACY_DESKTOP"
    echo
    read -rp "  Remove them? [y/N] " reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        rm -f "$LEGACY_SCRIPT" "$LEGACY_DESKTOP"
        ok "legacy files removed"
    else
        warn "legacy files left in place"
    fi
fi

# ---- Dependency summary ----
echo
say "Dependency check:"
deps=(whiptail kreadconfig6 kwriteconfig6 steamos-session-select
      dbus-send xrdb pkexec systemctl qdbus6)
missing=()
for c in "${deps[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then
        printf '    \033[32m✓\033[0m %s\n' "$c"
    else
        printf '    \033[31m✗\033[0m %s\n' "$c"
        missing+=("$c")
    fi
done

if (( ${#missing[@]} > 0 )); then
    echo
    warn "Missing: ${missing[*]}"
    warn "On SteamOS: 'sudo steamos-readonly disable && sudo pacman -S <pkg>'."
    warn "Most missing entries on a stock Deck mean a non-Plasma-6 environment — TOGLIT may not work."
fi

echo
ok "TOGLIT installed."
say "Launch from the Desktop icon, or run 'toglit' in a terminal."
say "(You may need to open a new shell for ~/.local/bin to be on PATH.)"
echo
