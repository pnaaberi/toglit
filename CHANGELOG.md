# Changelog

## v1.3.0 — onboarding wizard + persistent autologin fix

### Features

- **First-launch onboarding wizard.** New users are walked through four
  steps on first run: autologin repair, boot target selection, password
  safety check, and desktop shortcut creation. Every step detects its
  own state and skips itself if already correct. Guarded by
  `~/.config/toglit/onboarding_done` so it only appears once.

### Bug fixes

- **Autologin toggle now survives SteamOS updates.** `/etc` on SteamOS is
  a volatile overlayfs — edits via plain `pkexec sed` land in the upper
  layer and are wiped by updates or a `steamos-readonly reset`. The
  autologin enable/disable paths now bracket every write with
  `pkexec steamos-readonly disable / enable`, landing the change in the
  real lower-layer filesystem. polkit's `auth_admin_keep` means users
  still see only one password prompt per operation.
- **Handles "no `#User=deck` line to uncomment" gracefully.** On some
  SteamOS images the commented placeholder is absent entirely. The new
  `_autologin_write_persistent` helper falls back to inserting
  `User=<user>` after `[Autologin]` if the uncomment pass found nothing.

### Improvements

- `_autologin_is_broken` detects the "User=steamos placeholder active"
  state that causes autologin to silently fail after a clean install or
  update, surfacing a fix prompt in the onboarding wizard.
- Autologin logic extracted into reusable
  `_autologin_write_persistent` / `_autologin_comment_persistent`
  helpers; `toggle_autologin` is now a thin wrapper around them.

## v1.2.0 — security audit + CI

### Security

- **Autologin toggle no longer interpolates raw `$USER` into a `pkexec`'d
  sed regex.** Switched to `id -un` with strict POSIX shape validation
  (`^[a-z_][a-z0-9_-]{0,31}$`) and a dedicated `_sed_regex_escape` helper
  that escapes every non-alphanumeric character. A username containing
  regex metachars or sed delimiters can no longer bend the pattern.
  If the login can't be resolved safely, TOGLIT refuses the edit with a
  visible error instead of proceeding on a tainted value.
- **`get_autologin_state` switched from grep-with-interpolation to
  `awk -v` field comparison** — the captured `User=` value is compared
  as a literal string, eliminating the regex surface on the username.
- **`_restore_backup_files`**: quoted the prefix-strip pattern so glob
  metachars in `$HOME` can't mis-strip and land a backup file outside
  `~/.config/`. Pre-unlinks any symlink at the destination before `cp`,
  so a planted symlink can't redirect the write to an arbitrary path.
- **`normalize_kdeglobals_fonts`**: pointsize parsed from `kdeglobals`
  is now validated as a plain positive integer before being rewritten.
  A corrupted or exotic config no longer gets laundered through
  `kwriteconfig6` unchanged.
- **Plasma `evaluateScript` helpers (`_plasma_set_panel_height`,
  `_plasma_set_desktop_icon_size`)**: every value interpolated into a
  JavaScript blob is validated against a narrow integer range (16..256
  / 0..6). The scripting surface is now bounded to "integers we chose
  ourselves" at the type level.
- **Desktop shortcut uses an absolute `Icon=` path** (both in `install.sh`
  and the in-script `install_shortcut`). `Icon=toglit` (bare theme
  lookup) was brittle when the hicolor cache was stale.

### Install

- `bootstrap.sh` supports `TOGLIT_REF` for reproducible installs —
  pin to a tag or commit SHA:
  `curl ... | TOGLIT_REF=v1.2.0 bash`.
  Clones full history (not `--depth=1`), prints the resolved 12-char
  commit SHA before running `install.sh`, and reports whether a
  version tag is GPG-signed (soft-fail, informational).

### Engineering

- `.github/workflows/ci.yml` runs `bash -n` parse, `shellcheck`, and a
  helper test suite on every push / PR.
- `tests/test.sh` exercises the security helpers (`_sed_regex_escape`,
  `_safe_login_user`, plasma arg clamps) against both legitimate and
  hostile inputs. 22 assertions.
- `TOGLIT_SOURCE_ONLY=1` env guard lets the test harness source the
  script for function definitions without triggering splash / menu /
  config writes.
- Top-level `check_deps` / `migrate_state` calls moved into the entry
  block (below the source-only guard) — unit-testing safe.

### Icon

- Redesigned to match SteamOS's Gaming Mode icon style (same palette,
  rim-shadow treatment, chunky silhouette) with a toggle-switch motif.
  Installer always renders the absolute icon path into both
  `.desktop` files at install time.

## v1.1.2 — defensive hardening

All of these are real bugs that don't fire on stock SteamOS (username `deck`,
normal `$HOME`, stable Plasma 6 tooling), but they're now fixed for wider
users and future-proofing:

- `install.sh` now renders the `.desktop` file via `awk -v` instead of
  `sed` with a `|` delimiter. Paths containing `|`, `&`, or `\` no longer
  break the substitution.
- `toglit` `create_backup` strips the `$HOME/.config/` prefix by offset
  (character count) instead of `${f#$HOME/.config/}` parameter expansion.
  Exotic `$HOME` values containing `[`, `*`, `?` no longer cause the
  prefix strip to silently miss, which previously could have written
  backup files outside `$BACKUP_DIR`.
- `toglit` QDBUS resolver: if neither `qdbus6` nor `qdbus` is installed,
  `$QDBUS` is now empty rather than the literal string `"qdbus"`. The
  existing `check_deps` gate catches this and exits with a clear
  message instead of soft-failing silently on every D-Bus call.
- `toglit` `_tui_wrap` (word-wrap for the menu's help area) hard-breaks
  words longer than the box width. No current help string triggers this,
  but a future 70-char URL in a help line can no longer overflow the
  TUI frame.
- `toglit` autologin detection + toggle are now scoped to the current
  user (`$USER`). On a single-user Deck (the common case) the behaviour
  is identical; on multi-user systems, TOGLIT no longer claims
  autologin is "on" for a different account and no longer comments out
  other users' `User=` lines when disabling.

## v1.1.1 — icon + docs

- Ship the TOGLIT icon in the repo (`icons/toglit.svg`); `install.sh` drops
  it into `~/.local/share/icons/hicolor/scalable/apps/` and refreshes the
  icon cache, so fresh installs get a themed icon instead of the generic
  fallback.
- `.desktop` entries now reference `Icon=toglit` (was `Icon=touch-toggle`,
  a legacy name from before the rename that only resolved on machines with
  the prior app installed).
- `uninstall.sh` also removes the installed icon + refreshes the cache.
- README: fix stale troubleshooting step that referred to a "Restart panel?"
  prompt that no longer exists.
- `toglit` `check_deps`: drop `kquitapp6` (never called by the script), and
  accept either `qdbus6` or legacy `qdbus`.

## v1.1.0 — autologin toggle

- **Boot Settings** submenu now has an autologin toggle: enable/disable SDDM's
  autologin from inside TOGLIT. Turning it off makes SDDM show a proper login
  screen on every power-on; turning it back on restores the stock behaviour.
  Works by commenting / uncommenting the `User=` line in both
  `/etc/sddm.conf.d/steamos.conf` and `/etc/sddm.conf.d/kde_settings.conf`
  (SDDM merges drops alphabetically, so both need to match). Elevation via
  `pkexec` — no sudo is cached.
- **Lockout guard** when disabling autologin, driven by `passwd -S`:
  - `NP` / `L` (confirmed no usable password) → **hard block**. Blinking
    red-on-white terminal banner, then a msgbox telling the user to run
    `passwd` first. No override path — the toggle simply refuses.
  - `passwd -S` unavailable or an unrecognised code → **soft warn**.
    Same blinking banner, then a `--defaultno` whiptail yesno that lets
    the user proceed at their own risk.
  - `P` (password set) → silent, proceeds straight to the normal confirm.
- User-facing strings say "login screen" / "login settings" instead of
  "SDDM" / "greeter" — jargon stays in the code comments.
- Boot Settings title bar now shows `autologin: on/off` alongside the default
  boot target.
- **Current Status** dialog gained an "Autologin" line.

## v1.0.0 — initial release

Tagline: **"Toggle it. Touch · Desktop · Reboot."**

- Touch / Desktop mode toggle (ported from earlier `touch-toggle.sh`).
- New **Boot Settings** submenu:
  - Reboot to Desktop now — just this once (one-shot; next boot reverts to Gaming).
  - Reboot to Gaming mode now.
  - Always boot to Desktop from now on (persistent default).
  - Always boot to Gaming (restore Deck's factory default).
- Animated dithered ASCII block splash at launch (row-by-row reveal, ~1.5s
  + 3s hold). Logo rendered with figlet's "Pagga" font (half-block + shade).
- **First-launch backup** of KDE config files — captures untouched state
  before TOGLIT can modify anything. Desktop Mode and Restore Backup both
  roll back to this snapshot.
- No plasmashell restart during mode switches — preserves any inhibitor
  locks the user has set (e.g. manual "prevent screen sleep").
- **No bundled virtual keyboard** — SteamOS already ships one (Steam+X
  overlay), so TOGLIT doesn't set up `qt6-virtualkeyboard`. Any env
  drop-in from a prior version is scrubbed on every launch.
- State directory auto-migration from `~/.config/touch-toggle/` (and any
  earlier pre-release paths) to `~/.config/toglit/` on first run.
- In-app **Create Desktop Shortcut** option + `toglit --create-shortcut`
  CLI flag: places (or re-places) the Desktop + app-menu icons.
- `qdbus6` preferred over `qdbus` for Plasma 6 compatibility.
- Robust `detect_mode` using awk field extraction.
- Dependency check at entry.
- Sub-menu cancel returns to parent instead of exiting the app.
- Installer / uninstaller, `.desktop` entry, README, LICENSE.
- Custom TUI for main + boot menus with a reserved 3-line ELI5 help area that
  updates as the highlight moves. Whiptail still handles yes/no + msgbox.
- Controls: Steam Deck D-pad + A (select) / B (back); or keyboard arrows +
  Enter/Space (select) / Esc/Backspace (back). Number keys 1–N jump.
  Stray keys (right/left arrow, F-keys, letters) are ignored — only the
  documented exit keys or the menu "Exit" item close the app.
- Menus are grouped with labelled ASCII section separators
  (`── session ──`, `── boot ──`, `── system ──`, `── app ──`).
- Hardened first-launch: backup + state migration are soft-failing, so a
  quirky `$HOME` never prevents the menu from opening.
