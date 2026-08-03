#!/usr/bin/env bash
# TOGLIT helper tests.
#
# Sources the main script in TOGLIT_SOURCE_ONLY=1 mode so every helper
# definition is loaded without side effects (no splash, no menu, no config
# writes). Tests focus on the security-sensitive helpers: regex escape,
# login-name validation, plasma script argument clamping.

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOGLIT="$HERE/../toglit"
ORIGINAL_PATH="$PATH"

# PATH shim: empty stubs for every binary the dep check requires. The
# dep check isn't invoked in source-only mode, but sourcing may still
# hit `command -v` early (e.g. the QDBUS resolver at file top), so we
# make sure those lookups don't fail the test host.
STUBDIR="$(mktemp -d)"
trap 'rm -rf "$STUBDIR"' EXIT

for c in whiptail kreadconfig6 kwriteconfig6 \
         dbus-send xrdb systemctl pgrep pkill qdbus6 \
         plasmashell tput dbus-update-activation-environment gio setsid; do
    printf '#!/bin/sh\nexit 0\n' > "$STUBDIR/$c"
    chmod +x "$STUBDIR/$c"
done
export PATH="$STUBDIR:$PATH"

export TOGLIT_SOURCE_ONLY=1
# shellcheck disable=SC1090
source "$TOGLIT"

fail=0
pass=0

assert_eq() {
    local got="$1" want="$2" msg="$3"
    if [[ "$got" == "$want" ]]; then
        pass=$((pass+1))
        printf '  [ok]   %s\n' "$msg"
    else
        fail=$((fail+1))
        printf '  [FAIL] %s\n    got:  %q\n    want: %q\n' "$msg" "$got" "$want"
    fi
}

assert_rc() {
    local want="$1" got="$2" msg="$3"
    if [[ "$got" == "$want" ]]; then
        pass=$((pass+1))
        printf '  [ok]   %s\n' "$msg"
    else
        fail=$((fail+1))
        printf '  [FAIL] %s (rc: got %s, want %s)\n' "$msg" "$got" "$want"
    fi
}

echo
echo "  _sed_regex_escape"
# Single-quoted literals are deliberate: we want the raw character
# sequences (incl. `$`, `\`, `*`), not shell-expanded values.
# shellcheck disable=SC2016
{
assert_eq "$(_sed_regex_escape 'deck')"   'deck'        'plain word passes through'
assert_eq "$(_sed_regex_escape 'a.b')"    'a\.b'        'escapes dot'
assert_eq "$(_sed_regex_escape 'a/b')"    'a\/b'        'escapes forward slash (sed delimiter)'
assert_eq "$(_sed_regex_escape '$evil')"  '\$evil'      'escapes dollar'
assert_eq "$(_sed_regex_escape 'a*b[c]')" 'a\*b\[c\]'   'escapes glob + bracket'
assert_eq "$(_sed_regex_escape 'a\b')"    'a\\b'        'escapes backslash'
assert_eq "$(_sed_regex_escape '')"       ''            'empty input → empty output'
}
# A representative hostile string a malicious $USER could hold. Verify
# that every metachar lands escaped, so after embedding into a sed expr
# the string cannot alter the pattern semantics or terminate delimiters.
hostile='.*/;w /etc/passwd'
escaped="$(_sed_regex_escape "$hostile")"
assert_eq "$escaped" '\.\*\/\;w\ \/etc\/passwd' 'hostile username is fully neutered'

echo
echo "  _safe_login_user"
# Positive: whatever user we're running as should pass the shape check.
# We don't hardcode 'deck' — this runs on CI too, where the user differs.
u="$(_safe_login_user 2>/dev/null || true)"
if [[ -n "$u" && "$u" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    pass=$((pass+1))
    printf '  [ok]   resolves current login (%s)\n' "$u"
else
    fail=$((fail+1))
    printf '  [FAIL] current login rejected or malformed: %q\n' "$u"
fi

echo
echo "  check_terminal_size"
check_terminal_size 62 28
assert_rc 0 $? 'accepts the former full-size layout'
check_terminal_size 80 40
assert_rc 0 $? 'accepts a standard terminal size'
check_terminal_size 40 20
assert_rc 0 $? 'accepts the compact layout boundary'
set +e
check_terminal_size 39 20 2>/dev/null
assert_rc 1 $? 'rejects insufficient width'
check_terminal_size 40 19 2>/dev/null
assert_rc 1 $? 'rejects insufficient height'
check_terminal_size bad 40 2>/dev/null
assert_rc 1 $? 'rejects invalid dimensions'
set -e

echo
echo "  _plasma_set_panel_height (input clamp)"
set +e
_plasma_set_panel_height 64;         assert_rc 0 $? 'accepts 64'
_plasma_set_panel_height 16;         assert_rc 0 $? 'accepts lower bound (16)'
_plasma_set_panel_height 256;        assert_rc 0 $? 'accepts upper bound (256)'
_plasma_set_panel_height 15         2>/dev/null; assert_rc 1 $? 'rejects below range (15)'
_plasma_set_panel_height 257        2>/dev/null; assert_rc 1 $? 'rejects above range (257)'
_plasma_set_panel_height abc        2>/dev/null; assert_rc 1 $? 'rejects non-numeric'
_plasma_set_panel_height ''         2>/dev/null; assert_rc 1 $? 'rejects empty'
_plasma_set_panel_height '64;rm -rf' 2>/dev/null; assert_rc 1 $? 'rejects injection attempt'
set -e

echo
echo "  _plasma_set_desktop_icon_size (input clamp)"
set +e
_plasma_set_desktop_icon_size 0;           assert_rc 0 $? 'accepts 0'
_plasma_set_desktop_icon_size 6;           assert_rc 0 $? 'accepts 6'
_plasma_set_desktop_icon_size 7  2>/dev/null; assert_rc 1 $? 'rejects 7 (out of range)'
_plasma_set_desktop_icon_size -1 2>/dev/null; assert_rc 1 $? 'rejects negative'
_plasma_set_desktop_icon_size x  2>/dev/null; assert_rc 1 $? 'rejects non-numeric'
set -e

echo
echo "  tui_menu live resize"
resize_capture="$STUBDIR/resize.typescript"
set +e
(
    sleep 1.5
    printf '\033'
) | TOGLIT_TEST_TARGET="$TOGLIT" PATH="$ORIGINAL_PATH" TERM=xterm \
    script -qfec 'bash -lc '\''
        tty_path=$(tty)
        stty cols 32 rows 28
        export TOGLIT_SOURCE_ONLY=1
        source "$TOGLIT_TEST_TARGET"
        (
            sleep 0.4
            stty -F "$tty_path" cols 40 rows 20
            sleep 0.4
            stty -F "$tty_path" cols 62 rows 24
            sleep 0.4
            stty -F "$tty_path" cols 80 rows 28
        ) &
        tui_menu Test Sub \
            "@header:session" "" \
            "1  Touch Mode" "Touch help" \
            "2  Restore Desktop Settings" "Restore help" \
            "@header:system" "" \
            "3  Current Status" "Status help" \
            "4  Repair Desktop Shortcut" "Shortcut help" \
            "@header:app" "" \
            "5  Exit" "Exit help"
    '\''' "$resize_capture" >/dev/null 2>&1
resize_rc=$?
set -e
assert_rc 1 "$resize_rc" 'Esc cancels after a live resize'
compact_border="┌$(printf '─%.0s' $(seq 1 36))┐"
if grep -aqF 'TOGLIT paused' "$resize_capture" &&
   grep -aqF 'Window: 32x28' "$resize_capture" &&
   grep -aqF 'Resize to continue' "$resize_capture" &&
   grep -aqF "$compact_border" "$resize_capture" &&
   grep -aqF 'A/Enter' "$resize_capture" &&
   grep -aqF 'B/Esc back' "$resize_capture" &&
   grep -aqF 'Deck: D-pad' "$resize_capture" &&
   grep -aqF 'Repair Desktop Shortcut' "$resize_capture"; then
    pass=$((pass+1))
    printf '  [ok]   keeps controls visible at 32x28, 40x20, 62x24, and 80x28\n'
else
    fail=$((fail+1))
    printf '  [FAIL] resize capture did not contain compact guidance and full layout\n'
fi

_test_tui_input() {
    local name="$1" input="$2" expected="$3" expected_help="${4:-}"
    local capture="$STUBDIR/input-${name}.typescript"
    (
        sleep 0.3
        printf '%b' "$input"
    ) | TOGLIT_TEST_TARGET="$TOGLIT" PATH="$ORIGINAL_PATH" TERM=xterm \
        script -qfec 'bash -lc '\''
            stty cols 80 rows 28
            export TOGLIT_SOURCE_ONLY=1
            source "$TOGLIT_TEST_TARGET"
            set +e
            tui_menu Test Sub \
                "@header:session" "" \
                "1  Touch Mode" "Touch help" \
                "2  Restore Desktop Settings" "Restore help" \
                "@header:system" "" \
                "3  Current Status" "Status help" \
                "4  Repair Desktop Shortcut" "Shortcut help" \
                "@header:app" "" \
                "5  Exit" "Exit help"
            rc=$?
            printf "RESULT=%s:%s\n" "$rc" "${REPLY:-none}"
        '\''' "$capture" >/dev/null 2>&1

    if grep -aqF "RESULT=$expected" "$capture" &&
       { [[ -z "$expected_help" ]] || grep -aqF "$expected_help" "$capture"; }; then
        pass=$((pass+1))
        printf '  [ok]   %s\n' "$name"
    else
        fail=$((fail+1))
        printf '  [FAIL] %s\n' "$name"
    fi
}

echo
echo "  tui_menu controls"
_test_tui_input 'down arrow + Enter selects item 2' '\e[B\r' '0:2' 'Restore help'
_test_tui_input 'k wraps from item 1 to item 5' 'k\r' '0:5' 'Exit help'
_test_tui_input 'number 4 selects item 4 directly' '4' '0:4'
_test_tui_input 'Space selects the highlighted item' ' ' '0:1'
_test_tui_input 'Backspace cancels like Deck B' '\177' '1:none'

echo
if (( fail == 0 )); then
    printf '  %d passed, 0 failed\n' "$pass"
    exit 0
else
    printf '  %d passed, %d FAILED\n' "$pass" "$fail"
    exit 1
fi
