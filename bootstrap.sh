#!/usr/bin/env bash
# TOGLIT bootstrap — one-line installer.
#
# Usage (paste into Konsole on your Deck):
#
#   # latest main (default)
#   curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh | bash
#
#   # pin to a signed tag or commit SHA (reproducible install)
#   curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh \
#     | TOGLIT_REF=v1.2.0 bash
#
# Clones the repo to ~/Projects/toglit (or updates it if already present),
# checks out TOGLIT_REF (default: main), prints the resolved commit SHA so
# you can verify what you're running, then runs install.sh. Stays inside
# $HOME. No sudo.

set -euo pipefail

REPO="https://github.com/pnaaberi/toglit.git"
DEST="$HOME/Projects/toglit"
LEGACY_DEST="$HOME/toglit"
REF="${TOGLIT_REF:-main}"

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

mkdir -p "$(dirname "$DEST")"

# Migrate a legacy clone from the old $HOME/toglit location.
if [[ -d "$LEGACY_DEST/.git" && ! -e "$DEST" ]]; then
    say "migrating legacy clone $LEGACY_DEST → $DEST"
    mv "$LEGACY_DEST" "$DEST"
    ok "moved (install.sh will re-point the symlink and .desktop entries)"
elif [[ -d "$LEGACY_DEST" && -d "$DEST" ]]; then
    warn "legacy directory $LEGACY_DEST exists alongside $DEST — remove it manually if unwanted"
fi

# Clone full history (no --depth=1) so TOGLIT_REF can resolve to any tag
# or commit SHA. A shallow clone would only know about HEAD on the
# default branch.
if [[ -d "$DEST/.git" ]]; then
    say "found existing clone at $DEST — fetching"
    if ! git -C "$DEST" fetch --tags --prune --quiet origin; then
        err "'git fetch' failed in $DEST"
        exit 1
    fi
    ok "fetch complete"
elif [[ -e "$DEST" ]]; then
    err "$DEST exists but is not a git clone"
    err "move it out of the way, then retry"
    exit 1
else
    say "cloning into $DEST"
    git clone --quiet "$REPO" "$DEST"
    ok "cloned"
fi

# Resolve TOGLIT_REF. --verify ensures $REF actually names something in
# the repo; --detach is explicit so we don't silently leave the user on a
# detached HEAD they didn't realise.
if ! git -C "$DEST" rev-parse --verify --quiet "$REF^{commit}" >/dev/null; then
    err "ref '$REF' not found in $DEST"
    err "check spelling, or use 'main' for the latest"
    exit 1
fi

if ! git -C "$DEST" checkout --quiet --detach "$REF"; then
    err "couldn't check out $REF in $DEST"
    exit 1
fi

resolved="$(git -C "$DEST" rev-parse --short=12 HEAD)"
ok "installing toglit @ $REF ($resolved)"

# If TOGLIT_REF looks like a version tag (v1.2.0 etc.), report whether
# it's GPG-signed. Soft-check only: an unsigned tag or missing gpg is a
# note, not a failure.
if [[ "$REF" =~ ^v[0-9] ]]; then
    if git -C "$DEST" verify-tag "$REF" 2>/dev/null; then
        ok "tag signature verified"
    else
        warn "tag '$REF' is not GPG-signed (or gpg is unavailable)"
    fi
fi

echo
exec bash "$DEST/install.sh"
