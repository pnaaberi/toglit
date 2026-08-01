# TOGLIT

TOGLIT is a Steam Deck SteamOS Desktop Mode TUI for switching between
finger-friendly Touch Mode and the original KDE Desktop Mode.

## Scope

TOGLIT manages only the KDE desktop presentation:

- larger fonts, icons, scrollbars, and window controls in Touch Mode
- restoration of the first-launch KDE configuration snapshot
- live Plasma panel and desktop-icon sizing
- a Desktop shortcut and local application launcher

Boot settings, autologin settings, SDDM edits, reboot actions, and session
selection are intentionally not part of TOGLIT. SteamOS updates can overwrite
those settings, so they are outside this tool's scope.

## Requirements

- Steam Deck running SteamOS in Desktop Mode
- KDE Plasma 6 and the stock SteamOS utilities
- `whiptail`, KDE config tools, D-Bus, and `qdbus6`

TOGLIT adapts to terminal size. It uses up to 62 columns, truncates long menu
labels safely, and reduces help/instruction space in compact windows. The
minimum usable size is **40 columns wide and 20 rows high**. Smaller terminals
show a clear resize message instead of drawing a clipped interface.

## Install

Clone the repository, review the installer, and run it:

```sh
git clone https://github.com/pnaaberi/toglit.git
cd toglit
./install.sh
```

The installer stays inside `$HOME` and does not require sudo. The optional
bootstrap helper can be downloaded and inspected before execution:

```sh
curl -fsSL https://raw.githubusercontent.com/pnaaberi/toglit/main/bootstrap.sh \
  -o /tmp/toglit-bootstrap.sh
less /tmp/toglit-bootstrap.sh
TOGLIT_REF=v1.2.0 bash /tmp/toglit-bootstrap.sh
```

## Use

```sh
toglit
```

The main menu provides Touch Mode, Restore Desktop Settings, Current Status,
Repair Desktop Shortcut, and Exit.

The backup is created before TOGLIT changes KDE settings. Restore Desktop
Settings puts the saved files back and removes TOGLIT's virtual-keyboard
environment drop-in.

## Safety

- No root access is required.
- No SDDM or `/etc` files are modified.
- No boot or autologin settings are changed.
- Restore removes destination symlinks before copying backup files.
- Uninstall leaves KDE settings alone and asks before deleting the backup.

## Development and tests

```sh
bash tests/test.sh
for f in bootstrap.sh install.sh uninstall.sh toglit tests/*.sh; do bash -n "$f"; done
git diff --check
```

The tests cover hostile input escaping, safe numeric bounds, privileged boot
editing removal, and terminal-size boundaries.

## License

MIT. See [LICENSE](LICENSE).
