# Building and testing the TOGLIT TUI

This document records the constraints and lessons behind TOGLIT's Bash TUI and
serves as a reference for future terminal interfaces. Sections marked as
current describe `tui_menu`. Optional features such as mouse input and tables
include tested primitives but are not enabled in the TOGLIT menu today.

There is no universally perfect terminal UI. Terminal capability databases,
emulators, fonts, multiplexers, locales, remote links, and accessibility needs
differ. A production TUI must declare its support contract, degrade safely,
restore terminal state, and test the combinations it claims to support.

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

## Architecture

Keep state, layout, rendering, and input separate even in a small shell TUI.
The event loop should be the only place that joins them.

| Layer | Owns | Must not own |
| --- | --- | --- |
| Model | selected item, data, scroll offset, mode | terminal escape output |
| Layout | rectangles, row counts, breakpoints, hit regions | business actions |
| Renderer | terminal writes for one frame | blocking reads |
| Decoder | bytes to key, paste, focus, or mouse event | screen drawing |
| Controller | model transitions and action dispatch | width arithmetic |
| Lifecycle | enter, suspend, resume, cleanup | application decisions |

A useful frame cycle is:

1. sample terminal geometry;
2. derive a complete immutable layout from model plus geometry;
3. render only if model or geometry changed;
4. read one logical event with a bounded wait;
5. update model or dispatch an action;
6. repeat.

Never mutate selection while rendering. Never execute an action directly from
an incomplete escape sequence. Keep the last valid model when layout becomes
temporarily impossible.

## Terminal capabilities and modes

Prefer terminfo capabilities through `tput` over hard-coded control sequences
for cursor movement, clearing, colors, cursor visibility, and alternate-screen
entry. ECMA-48 defines the general control-function model, but terminals
implement different subsets and private extensions. `TERM=dumb`, missing
terminfo data, redirected output, and failed capability calls need a plain-text
fallback or a clear refusal before terminal state changes.

For a larger full-screen program, the usual lifecycle is:

1. verify stdin and stdout are TTYs;
2. save the original `stty -g` value;
3. enter the alternate screen when supported;
4. disable canonical input and echo;
5. hide the cursor;
6. enable only required optional protocols;
7. run the event loop;
8. disable optional protocols in reverse order;
9. show the cursor;
10. leave the alternate screen;
11. restore the exact saved terminal mode.

Install cleanup traps before changing modes. Cover normal return, `EXIT`,
`INT`, `TERM`, and `HUP`. If suspend/resume is supported, restore normal state
before `TSTP`, then re-enter and force a full redraw after `CONT`. Cleanup must
be idempotent because several paths may call it.

TOGLIT currently avoids raw-mode ownership and alternate-screen switching. It
uses silent timed Bash reads and the normal screen. That smaller lifecycle is
appropriate for its menu, but the same cleanup rules apply to cursor state and
optional protocols.

## Input decoding

Terminal input is a byte stream, not a stream of keys. One physical action can
produce one byte, several bytes, or an emulator-specific sequence. Multiple
events can arrive in one read, and one event can be split across reads.

Use a decoder with a persistent buffer and these states:

| Prefix | Possible event | Decoder action |
| --- | --- | --- |
| printable UTF-8 | text/key | decode one complete UTF-8 sequence |
| `CR`, `LF`, Space | selection keys | normalize to logical actions |
| `ESC` alone | Escape | wait briefly for a possible continuation |
| `ESC [` | CSI key, mouse, paste, focus | read to a valid final byte |
| `ESC O` | SS3 key | decode terminal key variant |
| paste start | bracketed paste | collect until exact paste end marker |
| unknown/incomplete | unsupported | wait if incomplete; otherwise ignore |

Do not assume every arrow is exactly three bytes. Modified arrows, Home/End,
function keys, application cursor mode, and modern keyboard protocols can use
longer sequences. Use terminfo key capabilities or a real parser when the
supported key set grows beyond a few known controls.

Set an upper bound on escape-sequence and paste buffers. Treat control bytes in
untrusted labels as data to strip or visibly escape; otherwise data can move
the cursor, change colors, forge output, set a terminal title, or inject a
clickable link. Never replay unknown input bytes to the terminal.

Bracketed paste uses private mode 2004 in supporting terminals. Enable it only
when the UI accepts text, recognize paste start/end as framing, and disable it
during cleanup. Focus events use private mode 1004. Ignore them unless the UI
has a defined focus policy.

## Mouse support

Mouse support is optional. Every operation must remain reachable by keyboard.
Do not enable mouse reporting merely because parsing code exists: while it is
enabled, the terminal sends click sequences to the application instead of
performing normal selection behavior.

For xterm-compatible terminals, use basic click tracking plus SGR coordinates:

```bash
printf '\e[?1000h\e[?1006h' # enable clicks, then SGR encoding
printf '\e[?1006l\e[?1000l' # disable in reverse order
```

Mode 1000 reports press and release. Mode 1002 adds button-motion reports for
dragging. Avoid mode 1003 unless continuous pointer motion is essential; it can
create a large event stream. Mode 1006 avoids the coordinate and encoding
limits of the older `ESC [ M` protocol.

An SGR report has this shape:

```text
ESC [ < Cb ; Cx ; Cy M    press, motion, or wheel
ESC [ < Cb ; Cx ; Cy m    release
```

Coordinates are one-based. Convert to zero-based once in the decoder. `Cb`
contains the base button plus modifier, motion, and wheel bits. Validate every
numeric field and reject negative, missing, oversized, or trailing data.

`docs/examples/tui-primitives.sh` contains the tested `tui_parse_sgr_mouse`,
`tui_mouse_enable`, and `tui_mouse_disable` reference functions. The parser
normalizes press, release, drag, wheel, modifiers, and coordinates.

### Mouse hit testing

Rendering must produce a hit map from the same rectangles it draws. Do not
reconstruct positions later from labels.

| Region | Click | Wheel | Drag |
| --- | --- | --- | --- |
| selectable row | focus; second click or release activates | scroll list | optional reorder only |
| scrollbar | page or jump by documented rule | scroll | move thumb |
| button | activate on release inside same button | none | cancel if pointer leaves |
| help/text | no action; preserve selection | scroll help if scrollable | terminal selection if mouse mode off |
| outside UI | ignore | ignore | ignore |

Clamp coordinates after every resize. A queued click from the old geometry
must not activate a new control at the same coordinates. Associate hit regions
with a layout generation and discard mouse events decoded for an older frame.

Good mouse UX also handles double-click timing deliberately, never activates
on both press and release, gives visible hover only when motion reporting is
enabled, and documents how users can temporarily regain terminal text
selection. Keyboard focus must remain visible after mouse use.

## Building tables

A terminal table is a width-allocation problem. Build it from cell data, not
from preformatted colored strings.

Each column needs:

| Property | Meaning |
| --- | --- |
| minimum | smallest useful content width |
| preferred | width before truncation or wrapping |
| maximum | upper bound for low-value whitespace |
| flex weight | share of remaining or removed width |
| alignment | left, right, decimal, or centered |
| overflow | wrap, ellipsize, clip, or hide column |
| priority | order in which optional columns disappear |

Account for borders and padding before distributing content width:

```text
available content = box width - border cells - separator cells - cell padding
```

Use this allocation order:

1. validate the table schema and terminal budget;
2. reserve borders, separators, and padding;
3. assign every visible column its minimum;
4. if minima do not fit, hide optional columns by priority;
5. if required minima still do not fit, switch to stacked records or a
   horizontal-scroll view;
6. distribute remaining cells toward preferred widths using flex weights;
7. measure and wrap each cell to its final width;
8. make the row as tall as its tallest wrapped cell;
9. fill missing cell lines with spaces;
10. apply alignment, then color, then borders.

Never truncate numeric signs, status icons that carry the only meaning, or the
focused cell marker. Right-align integers. For decimal alignment, split values
around the locale-defined decimal marker and reserve left/right widths. Keep
headers visible while vertically scrolling when possible.

For narrow screens, a stacked record is usually clearer than a crushed table:

```text
Name:   Desktop mode
State:  Active
Owner:  deck
```

The tested `tui_fit_cell` and `tui_table_row` examples demonstrate fixed-width
padding and ellipsis for known single-cell text. They intentionally reject
invalid widths. They are not a replacement for grapheme-aware display-width
measurement.

### Table accessibility

Do not encode state using color alone. Include text, a stable symbol, or both.
Keep column order stable across refreshes. Announce sorting in the header and
make the active sort direction visible. Preserve row identity rather than raw
row number when data refreshes. Provide a plain-text/export path for screen
readers and logs.

## Unicode and display width

Bytes, Unicode code points, grapheme clusters, and terminal cells are four
different units. Bash `${#text}` in a UTF-8 locale counts characters according
to its locale handling, but it does not implement grapheme segmentation or
terminal cell width.

A robust text pipeline should:

1. validate or replace malformed UTF-8;
2. segment extended grapheme clusters;
3. calculate terminal width with a maintained `wcwidth` implementation;
4. never split a grapheme cluster while truncating;
5. apply the same ambiguous-width policy as the target terminal;
6. cache measurements within a frame.

Emoji ZWJ sequences, variation selectors, combining marks, regional-indicator
flags, and East Asian ambiguous characters need explicit tests. Unicode East
Asian Width is useful input but is not by itself a complete terminal rendering
algorithm. Font fallback and emulator policy can still differ.

Bidirectional text requires more than reversing strings. If full RTL support is
required, use a library and test cursor placement, truncation, selection, and
mixed-direction data. Otherwise declare the limitation and avoid corrupting
the underlying text.

## Color, themes, and accessibility

- Detect color capability instead of assuming 256 colors or true color.
- Provide a monochrome path and honor project policy for disabling color.
- Reset attributes at every component boundary so styles cannot leak.
- Never use blink as the only warning signal.
- Keep focus visible without relying only on hue.
- Use concise labels and stable shortcuts.
- Avoid rapid full-screen flashes during resize.
- Do not steal mouse selection unless mouse features are active and useful.
- Make destructive actions explicit and require confirmation outside the
  navigation event itself.
- Preserve meaningful output or provide a summary when stdout is redirected.

Screen readers often work better with linear output than a constantly redrawn
screen. A serious general-purpose TUI should offer a non-interactive command,
plain mode, or structured output for the same core actions.

## Scrolling, focus, and dynamic data

Separate selected item identity from viewport offset. On resize or refresh:

- preserve the selected stable ID if it still exists;
- clamp the index if the item disappeared;
- scroll just enough to keep focus visible;
- keep headers and controls outside the scroll viewport;
- show position or overflow affordances when content is hidden;
- discard stale asynchronous results by generation or request ID.

For lists, Page Up/Down should move by the visible page minus context, Home/End
should have documented semantics, and wheel movement should use a stable number
of rows. Do not let a data refresh unexpectedly activate a row that moved under
the pointer.

## Performance and output integrity

Build a complete frame in memory and write it in as few operations as practical.
Partial writes make tearing more visible over SSH. Full redraws are simple and
safe for small menus; larger dashboards should diff rows or cells while still
forcing a full redraw after resize, resume, terminal clear, or detected output
corruption.

Rate-limit high-frequency resize, mouse-motion, and data events. Coalesce them
to the newest state before rendering. Never let rendering block indefinitely
on a subprocess. Bound queues, buffers, line lengths, and captured output.

Treat displayed external data as hostile. Remove C0/C1 controls except allowed
whitespace, strip or escape CSI/OSC sequences, and decide how to render tabs,
newlines, carriage returns, bidi controls, and zero-width characters. OSC 8
links, clipboard controls, title changes, and device queries must never come
from untrusted cell content.

## Compatibility contract

Document a matrix rather than claiming “all terminals.” A useful contract lists:

| Dimension | Examples to test |
| --- | --- |
| emulator | Konsole, xterm, kitty, WezTerm, GNOME Terminal |
| transport | local PTY, SSH, serial/high latency |
| multiplexer | none, tmux, screen |
| `TERM` | native entry, `xterm-256color`, `screen`, `tmux`, `dumb` |
| locale | UTF-8, `C`, missing preferred locale |
| color | monochrome, 8/16, 256, true color |
| geometry | below minimum, exact minimum, breakpoints, very large |
| input | keyboard, Deck mapping, paste, mouse, touch-to-mouse |
| lifecycle | success, cancel, signal, suspend/resume, subprocess |
| content | empty, long words, controls, combining text, wide text, RTL |

TOGLIT's tested contract is narrower: Bash on SteamOS Desktop Mode, a UTF-8
locale, terminfo-backed `tput`, keyboard/Deck input, and the documented size
boundaries. Mouse primitives are documented and tested but are not enabled in
the product menu.

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
- documented fixed-width table primitives
- SGR mouse press, release, wheel, drag, modifiers, and malformed reports

For manual stress testing, cycle repeatedly through valid and invalid sizes,
then select an item after returning to a valid size. Test both directions:
large to small to large, and small to large to small. Include widths around 40,
50, 62, and 64 columns and heights around 19, 20, 22, 24, and 25 rows because
those are layout transition points.

PTY transcripts are raw byte logs, not screenshots. They contain cursor moves,
erases, carriage returns, and possibly input. Assertions should check protocol
and state transitions, while a terminal-state emulator or screenshot test is
needed to prove final cell placement. Never capture secrets with `script` input
logging; util-linux explicitly warns that input logs include passwords even
when terminal echo is disabled.

Use layered testing:

| Layer | Proves |
| --- | --- |
| pure unit | width allocation, wrapping, parsers, state transitions |
| byte-stream | exact enable/disable and decoded control sequences |
| PTY integration | TTY branches, timed reads, `stty`, resize, EOF |
| terminal-state model | final cells, styles, cursor, stale-row removal |
| emulator smoke | actual font widths, mouse, paste, multiplexer behavior |
| hostile/fuzz | bounded parsing, malformed input, control injection |
| accessibility | keyboard-only flow, monochrome, plain output, screen reader |

Every lifecycle test should assert cleanup bytes or restored `stty` state after
normal selection, cancel, EOF, `INT`, `TERM`, and failure during initialization.

## Primary references

- [ECMA-48 control functions](https://ecma-international.org/publications-and-standards/standards/ecma-48/)
- [ncurses terminfo interface](https://invisible-island.net/ncurses/man/curs_terminfo.3x.html)
- [xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html)
- [ncurses mouse interface](https://invisible-island.net/ncurses/man/curs_mouse.3x.html)
- [GNU Bash `read` and `trap`](https://www.gnu.org/software/bash/manual/bash.html)
- [Linux terminal window-size ioctls](https://www.man7.org/linux/man-pages/man2/TIOCSWINSZ.2const.html)
- [POSIX `stty`](https://pubs.opengroup.org/onlinepubs/009695099/utilities/stty.html)
- [Unicode text segmentation](https://unicode.org/reports/tr29/)
- [Unicode East Asian Width](https://www.unicode.org/reports/tr11/)
- [util-linux `script`](https://man7.org/linux/man-pages/man1/script.1.html)

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
- verify optional mouse, paste, focus, and alternate-screen modes are disabled
  after every exit path;
- fuzz input decoders with incomplete, oversized, and malformed sequences;
- verify tables at minimum widths, with hidden columns, wrapped rows, empty
  data, large numbers, and hostile control bytes;
- test keyboard-only and monochrome operation;
- record untested emulators, multiplexers, Unicode classes, and protocols.

The main lesson is simple: terminal responsiveness is geometry plus timing.
Static width checks are not enough. Test the real renderer in a real PTY, use
the real menu shape, and treat every resize as a complete layout transition.
