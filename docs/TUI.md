# Building and testing the TOGLIT TUI

This document records the constraints and lessons behind TOGLIT's Bash TUI.
It describes the current implementation in `tui_menu`, not a future design.

## Why it is custom

Stock SteamOS does not include `dialog`, and `whiptail` does not provide the
per-item live help used by TOGLIT. Installing another system package would add
setup and read-only-filesystem work. The menu is therefore rendered directly
with Bash, `tput`, ANSI colors, and UTF-8 box characters.

The custom renderer owns four jobs:

- layout and truncation
- full-screen redraws
- keyboard and Steam Deck button input
- compact guidance when the terminal is too small

## Supported geometry

The minimum usable terminal is 40 columns by 20 rows. Below either boundary,
the menu pauses and shows a short resize screen. No hidden menu action is
accepted while paused.

The drawn box is two columns narrower than the terminal and is capped at 62
columns. The two-column margin is deliberate. Drawing through the terminal's
last column can trigger auto-wrap, add an unexpected row, and push the control
legend below the viewport.

The layout has three instruction variants:

- Full: detailed Steam Deck and keyboard help when width and height allow it.
- Medium: two short lines for a wide but vertically limited terminal.
- Compact: one combined line at the 40x20 boundary.

Help height also drops from three lines to two and then one as the terminal
gets shorter. Labels are truncated with an ellipsis. Help text is word-wrapped
and long unbroken words are hard-split.

When changing row counts, count every rendered row. Include borders, section
gaps, help rows, blank rows, and the control legend. A layout that writes one
extra newline may look correct in a transcript but lose its final row in a
real terminal.

## Resize behavior

Terminal resize signals are not reliable enough as the only trigger. A shell
may miss `SIGWINCH`, or a blocking `read` may not resume consistently across
terminal emulators.

TOGLIT uses a 200 ms timed input read. Each loop checks `tput cols` and
`tput lines`. When either value changes, the menu:

1. clears the screen;
2. recalculates width, wrapping, help height, and control instructions;
3. redraws the whole interface;
4. preserves the highlighted item.

The screen is not redrawn when geometry and selection are unchanged. This
avoids idle flicker and needless terminal output.

Some terminals briefly report empty or invalid dimensions during resize.
Dimensions are validated before Bash arithmetic. Invalid values become zero,
which safely selects the paused resize screen until valid dimensions return.

## Input behavior

The menu supports:

- Up/Down arrows and `k`/`j` for navigation
- Enter or Space for selection
- number keys for direct selection
- Escape or Backspace for cancel

Steam Deck controls normally map A to Enter and B to Backspace. Section header
rows are skipped during navigation. Up and Down wrap at the ends.

Escape handling reads two additional bytes briefly so arrow-key escape
sequences are not mistaken for a bare Escape. Unknown escape sequences and
unmapped keys are ignored.

While the terminal is below the minimum size, input is consumed but does not
activate menu items. This prevents a buffered A/Enter press from selecting a
hidden item. The previous selection remains highlighted after the menu returns.

EOF on non-interactive input cancels the menu. Timed-out reads on a real TTY
continue the resize polling loop.

## Text and terminal assumptions

TOGLIT sets a UTF-8 locale so Bash character slicing and `${#value}` treat the
box glyphs and arrows as characters instead of raw bytes. This is enough for
the current text, which uses mostly single-cell glyphs.

Do not assume every Unicode character occupies one cell. Emoji, combining
marks, and East Asian wide characters can still break alignment because Bash
does not calculate display width. Keep labels and help text to plain text and
known single-cell symbols unless a display-width helper is added.

ANSI color bytes must never be included in padding calculations. Fit and pad
plain text first, then add color sequences around it.

## Rendering rules

- Clear before a geometry-driven reload to remove wrapped remnants.
- Move to row 0, column 0 before every draw.
- Erase to the end of the screen after drawing to remove leftovers from a
  previously larger layout.
- Hide the cursor while the menu is active and restore it on every exit path.
- Keep the selected row and help text in one redraw transaction.
- Do not print a box when below the minimum size. Use short, width-bounded
  guidance instead.
- Never use the terminal's final column.

## Test strategy

Plain redirected input is not enough for TUI testing. TTY detection, timed
reads, terminal dimensions, and resize behavior need a pseudo-terminal.

`tests/test.sh` uses util-linux `script` to run the real menu under a PTY. It
changes geometry with `stty -F <tty>` and captures the terminal stream. Current
regressions cover:

- 32x28 paused guidance
- the 40x20 minimum layout
- 62x24 medium controls
- 80x28 full layout
- complete main-menu labels and section headers
- arrow navigation and help updates
- `k` wraparound
- numeric shortcuts
- Space selection
- Backspace cancellation
- full reload after live resize
- a 38-character box inside a 40-column terminal

For manual stress testing, cycle repeatedly through valid and invalid sizes,
then select an item after returning to a valid size. Test both directions:
large to small to large, and small to large to small. Include widths around 40,
50, 62, and 64 columns and heights around 19, 20, 22, 24, and 25 rows because
those are layout transition points.

## Change checklist

Before merging a TUI change:

- run `bash tests/test.sh`;
- parse-check every shell file;
- run ShellCheck through CI or locally when installed;
- run `git diff --check`;
- verify 40x20 with the real main-menu shape, not a two-item fixture;
- verify controls are visible on the initial draw and after resize;
- verify no rendered line reaches the terminal's final column;
- verify selection survives a pause and reload;
- verify cursor restoration on select, cancel, EOF, and process exit;
- inspect both compact and full help text for clipping and stale rows.

The main lesson is simple: terminal responsiveness is geometry plus timing.
Static width checks are not enough. Test the real renderer in a real PTY, use
the real menu shape, and treat every resize as a complete layout transition.
