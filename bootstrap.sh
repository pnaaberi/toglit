#!/usr/bin/env bash
# TOGLIT bootstrap — one-line installer.
#
# Usage (paste into Konsole on your Deck):
#   curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh | bash
#
# Clones the repo to ~/toglit (or updates it if already present) and runs
# install.sh. Stays inside $HOME. No sudo.

set -euo pipefail

REPO="https://github.com/pnaaberi/toglit.git"
DEST="$HOME/toglit"

say()  { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

for c in git bash; do
    command -v "$c" >/dev/null 2>&1 || { err "missing '$c' — can't bootstrap"; exit 1; }
done

echo
echo "  TOGLIT bootstrap"
echo

if [[ -d "$DEST/.git" ]]; then
    say "found existing clone at $DEST — updating"
    if ! git -C "$DEST" pull --ff-only; then
        err "'git pull' failed in $DEST"
        err "resolve manually, then run:  $DEST/install.sh"
        exit 1
    fi
    ok "up to date"
elif [[ -e "$DEST" ]]; then
    err "$DEST exists but is not a git clone"
    err "move it out of the way, then retry"
    exit 1
else
    say "cloning into $DEST"
    git clone --depth=1 "$REPO" "$DEST"
    ok "cloned"
fi

echo
exec bash "$DEST/install.sh"
