# TOGLIT

[![CI](https://github.com/pnaaberi/toglit/actions/workflows/ci.yml/badge.svg)](https://github.com/pnaaberi/toglit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

```
           ░▀█▀░█▀█░█▀▀░█░░░▀█▀░▀█▀
           ░░█░░█░█░█░█░█░░░░█░░░█░
           ░░▀░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░░▀░

     Toggle it.  Touch · Desktop · Reboot.
```

Rendered with the **Pagga** figlet font (half-block + dither shading).

**Designed specifically for the Steam Deck's SteamOS Desktop Mode.**
_Not intended for any other environment — TOGLIT makes hard assumptions
about KDE Plasma 6, Qt 6, and SteamOS's `steamos-session-select` mechanism._

TOGLIT is a tiny TUI that flips your Steam Deck's Plasma desktop between a
finger-friendly **Touch Mode** (bigger fonts, larger icons, wider scrollbars,
chunky window buttons) and the stock **Desktop Mode** — and lets you **reboot
back into Desktop Mode just this once** instead of Gaming Mode.

For on-screen typing, use SteamOS's built-in keyboard (**Steam + X** in Gaming
Mode, or the Steam overlay in Desktop Mode). TOGLIT deliberately does not
ship its own Qt virtual keyboard — the Steam one already covers it.

## What it solves

### Touch-friendliness

- **Plasma Desktop is unusable with fingers on the Deck's 7" screen.**
  Touch Mode enlarges fonts, icons, scrollbars, window buttons, and the
  panel in one shot — KDE makes you fix these in ~8 separate settings.

### Safety & reversibility

- **Reverting your KDE tweaks is guesswork.** TOGLIT snapshots your config
  on first launch and *Restore Backup* rolls back to that exact state.

### Boot & session control

- **"Reboot to Desktop just this once" is quietly broken on SteamOS.**
  Every time Plasma starts, `/usr/bin/startplasma-steamos-oneshot` runs
  `steamos-session-select gamescope --no-restart`, which rewrites
  `/etc/sddm.conf.d/zz-steamos-autologin.conf` back to the gamescope
  session. A plain "Restart" from the desktop menu therefore always lands
  you in Gaming. TOGLIT uses the one-shot `plasma-wayland` variant
  deliberately, so one-shot actually means one-shot.

- **No UI to pin Desktop or Gaming as the default.** You'd need to know
  `steamos-session-select` exists. TOGLIT gives you two labelled buttons
  that change the persistent default without rebooting.

- **No way to turn off autologin.** SteamOS boots straight in with no
  login prompt. TOGLIT adds a toggle — with a hard-block if the calling
  user has no password set (checked via `passwd -S`), so you can't
  accidentally lock yourself out at the login screen.

### Implementation polish

- **Live panel resize without killing plasmashell.** Most "resize my
  panel" scripts `kquitapp6 plasmashell` and lose whatever inhibitor locks
  you had (e.g. a manual "prevent sleep"). TOGLIT uses the plasmashell
  scripting D-Bus instead — inhibitors survive.

- **Small Deck-specific hazards handled silently** — normalises font
  strings to dodge a Qt 6.8 stack-smash, scrubs stray `qt6-virtualkeyboard`
  env drop-ins (Steam+X already covers OSK), migrates legacy
  `touch-toggle` / `flux` state dirs.

**One line:** TOGLIT turns SteamOS's undocumented single-purpose levers
into a TUI, with a safety net so you can undo everything.

## Requirements

- A **Steam Deck** running **SteamOS** in **Desktop Mode** (KDE Plasma 6,
  Qt 6, SDDM, whiptail, `steamos-session-select`). All stock.
- No other dependencies. No pip, no pacman, no AUR.
- Tested only on Steam Deck hardware in Desktop Mode. Running on a
  non-Deck SteamOS install or a generic Plasma desktop might work for the
  touch/desktop toggle pieces but the Boot Settings features depend on
  Valve's `/usr/bin/steamos-session-select` being present and wired to
  SDDM's `zz-steamos-autologin.conf`.

## Install

One line. Paste into Konsole on your Deck:

```sh
curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh | bash
```

That clones the repo to `~/Projects/toglit/` (or updates it if already there)
and runs `install.sh`. If you have a legacy clone at `~/toglit/` from an older
install, bootstrap moves it to the new location. Nothing leaves `$HOME`. No sudo.

### Reproducible install

Pin to a tag or commit SHA with `TOGLIT_REF` so you know exactly what's
landing on your Deck:

```sh
curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh \
  | TOGLIT_REF=v1.2.0 bash
```

Bootstrap prints the resolved 12-char commit SHA before running
`install.sh`, and reports whether a version tag is GPG-signed (currently
an informational warning, not a hard gate).

<details>
<summary>Manual install</summary>

```sh
git clone https://github.com/pnaaberi/toglit.git
cd toglit
./install.sh
```

</details>

The installer:

- Makes the scripts executable.
- Symlinks `~/.local/bin/toglit → ./toglit`.
- Writes `toglit.desktop` to `~/.local/share/applications/` and `~/Desktop/`
  (with `metadata::trusted` so KDE launches it without the usual warning).
- Offers to remove any legacy `touch-toggle.sh` / `Touch.desktop` on the
  desktop (the TOGLIT entry replaces them).
- Never touches anything outside `$HOME`.

Reboot is **not** required.

## Use

Double-click **TOGLIT** on the desktop, or run `toglit` in a terminal.

```
┌────────────────────────────────────────────────────────────┐
│  TOGLIT  ·  v1.0.0                                         │
│  session: Desktop   ·   boot: gaming                       │
├────────────────────────────────────────────────────────────┤
│ ── session ─────────────────────────────────────────────── │
│ ▸ 1  Touch Mode                                            │
│   2  Desktop Mode                                          │
│ ── boot ────────────────────────────────────────────────── │
│   3  Boot Settings                                         │
│ ── system ──────────────────────────────────────────────── │
│   4  Current Status                                        │
│   5  Restore Backup                                        │
│   6  Create Desktop Shortcut                               │
│ ── app ─────────────────────────────────────────────────── │
│   7  Exit                                                  │
│                                                            │
├────────────────────────────────────────────────────────────┤
│ Makes everything finger-sized: bigger fonts, larger icons, │
│ wider scrollbars, and chunky window buttons. Good for      │
│ handheld or tablet use.                                    │
└────────────────────────────────────────────────────────────┘

  Steam Deck:  D-pad ↑↓ (move)  ·  A (select)  ·  B (back)

  Keyboard:    ↑↓ (move)  ·  Enter / Space (select)  ·
               Esc / Backspace (back)
```

The **title bar** shows two independent facts: the *in-session* mode
(`session: Touch` / `Desktop`) and the *boot target* (`boot: gaming` /
`desktop`). Moving the highlight with ↑/↓ updates a reserved **3-line help
area** with an ELI5 explanation for each option — the layout never shifts.

### Controls

```
  Steam Deck:  D-pad ↑↓ move  ·  A select  ·  B back
  Keyboard:    ↑↓ (j/k) move  ·  Enter / Space select  ·  Esc / q / Backspace back  ·  1–N
```

The main and boot menus share the same control set. On the Steam Deck in
Desktop Mode, the D-pad and face buttons work through Steam Input's default
desktop profile (arrow keys / Enter / Escape). If the buttons don't respond,
open Steam and check the desktop controller layout.

### Boot Settings submenu

Same layout, same 3-line help area. Six options:

```
  ── reboot now ──────────────
    1  Reboot to Desktop · just this once
    2  Reboot to Gaming · just this once
  ── set persistent default ──
    3  Default boot target: Desktop
    4  Default boot target: Gaming
  ── autologin ───────────────
    5  Enable / Disable autologin
  ────────────────────────────
    6  Back
```

Symmetric pairs:

- **Options 1 and 2** reboot immediately. Option 1 is a true one-shot — it
  uses SteamOS's one-shot Plasma session (`steamos-session-select
  plasma-wayland`), so the boot after that auto-returns to your default.
  Option 2 reboots back into Gaming and, as a side effect, sets Gaming as
  your default if it wasn't already.
- **Options 3 and 4** change the persistent default without rebooting.
  The change applies on the next boot.
- **Option 5** flips SDDM's autologin. When autologin is ON (stock SteamOS
  behaviour), the Deck boots straight into your default session. When OFF,
  SDDM shows a login screen on every power-on — pick the user, enter the
  password, pick the session. The label updates to show whether the next
  action will Enable or Disable, and the title bar shows the current state.

Changing the boot target calls `steamos-session-select` under `pkexec`. On a
stock Deck where the `deck` user has no password, this is silent. If you have
set a password, expect a single prompt. The autologin toggle also uses
`pkexec` (to edit `/etc/sddm.conf.d/`), so it always prompts.

## How it works

- **Touch/Desktop Mode** writes to the usual KDE config files (`kdeglobals`,
  `kwinrc`, `oxygenrc`, `breezerc`, `dolphinrc`, `kcminputrc`, `gtk-3.0`,
  `gtk-4.0`) and nudges the running session via D-Bus
  (`KGlobalSettings.notifyChange`, `KWin.reconfigure`) plus a couple of
  `PlasmaShell.evaluateScript` calls for the panel and desktop-icon sizes.
- **Boot target** is a single line in `/etc/sddm.conf.d/zz-steamos-autologin.conf`.
  TOGLIT writes it via `steamos-session-select`, which handles elevation via
  `pkexec` itself — no sudo is stored or cached by TOGLIT.
- **Autologin** is controlled by `User=deck` under `[Autologin]` in the
  SteamOS/KDE drops in `/etc/sddm.conf.d/` (`steamos.conf`,
  `kde_settings.conf`). SDDM merges every drop alphabetically, so TOGLIT
  comments the line in both at once with a single `pkexec sed`. Re-enabling
  uncomments the same lines. No config is created or deleted, only a leading
  `#` is added or removed.
- **Backup** is taken the **first time you launch TOGLIT**, before the app has
  touched anything. It snapshots `kdeglobals`, `kwinrc`, `oxygenrc`, `breezerc`,
  `dolphinrc`, `kcminputrc`, `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`,
  and `plasmashellrc` into `~/.config/toglit/backup/`. *Desktop Mode* and
  *Restore Backup* both roll back to this exact snapshot — TOGLIT never
  imposes its own "default" values on you. Font strings are normalised to
  the 10-field format on restore to sidestep a Qt 6.8 stack-smash bug.
- TOGLIT never restarts `plasmashell`. That means any inhibitor locks
  plasmashell holds (e.g. a manual "prevent screen sleep" toggle) survive
  a mode switch. Panel height and desktop-icon size are updated live via
  the plasmashell scripting interface instead.

## Troubleshooting

- **Panel didn't resize** — the live plasmashell scripting call may have
  failed silently. As a fallback, run
  `kquitapp6 plasmashell && setsid plasmashell &` in a terminal. The panel
  size also updates correctly on the next login regardless.
- **pkexec says "Not authorized"** — the `deck` user needs either no password
  or a password you know. Set one with `passwd` in a terminal.
- **GTK apps still look default-size** — GTK apps only read font settings at
  launch. Quit and reopen them.
- **I messed something up** — `toglit` → *Restore Backup* puts things back
  exactly as they were before your first Touch Mode toggle.
- **I accidentally deleted the desktop icon** — inside TOGLIT pick
  *Create Desktop Shortcut*, or run `toglit --create-shortcut` in a
  terminal. The app-menu entry at
  `~/.local/share/applications/toglit.desktop` stays installed
  regardless, so KRunner (Alt+Space) can always find "TOGLIT".

## Uninstall

```sh
./uninstall.sh
```

Removes the launcher entries and the `~/.local/bin/toglit` symlink. Prompts
before removing `~/.config/toglit/` (your backup lives there). Your KDE settings
are left alone — if you want defaults back, run *Restore Backup* inside TOGLIT
before uninstalling.

## CLI flags

```
  toglit                    interactive menu
  toglit --splash           print banner only
  toglit --create-shortcut  place icon on Desktop + app menu
  toglit --version          print version
  toglit --help             this help
```

## Development

```sh
bash tests/test.sh          # run the helper tests (22 assertions)
bash -n toglit              # parse the main script
shellcheck -S warning toglit install.sh uninstall.sh bootstrap.sh
```

CI (`.github/workflows/ci.yml`) runs all three on every push and PR.

The test harness works by sourcing `toglit` with `TOGLIT_SOURCE_ONLY=1`,
which loads every helper definition without triggering the splash, menu,
dependency check, or config writes — so the security-sensitive helpers
(`_sed_regex_escape`, `_safe_login_user`, the plasma arg clamps) can be
exercised as pure functions.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Written by pnaaberi. ASCII logo rendered with the **Pagga** figlet font; TUI
text uses the **Hack** font.
