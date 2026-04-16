# Changelog

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
