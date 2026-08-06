#!/usr/bin/env bash
# Small, sourceable reference primitives used by docs/TUI.md.
# Text passed to the table helpers must already be sanitized and must contain
# only known single-cell characters. Production Unicode needs wcwidth support.

tui_fit_cell() {
    local text="$1" width="$2"
    (( width > 0 )) || return 0
    if (( ${#text} <= width )); then
        printf '%s%*s' "$text" "$((width - ${#text}))" ''
    elif (( width == 1 )); then
        printf '…'
    else
        printf '%s…' "${text:0:$((width - 1))}"
    fi
}

# Usage: tui_table_row COL1_WIDTH COL1_TEXT [COL2_WIDTH COL2_TEXT ...]
tui_table_row() {
    local output='│' width text
    while (( $# >= 2 )); do
        width="$1"
        text="$2"
        shift 2
        [[ "$width" =~ ^[1-9][0-9]*$ ]] || return 2
        output+=" $(tui_fit_cell "$text" "$width") │"
    done
    (( $# == 0 )) || return 2
    printf '%s\n' "$output"
}

# Enable click reporting and the unambiguous SGR coordinate format. Enable
# 1002 as well only when drag reporting is needed.
tui_mouse_enable()  { printf '\e[?1000h\e[?1006h'; }
tui_mouse_disable() { printf '\e[?1006l\e[?1000l'; }

# Parse xterm SGR mouse input: ESC [ < Cb ; Cx ; Cy M/m
# Results are returned in MOUSE_* globals. X and Y become zero-based.
# shellcheck disable=SC2034 # MOUSE_* values are the function's sourceable outputs.
tui_parse_sgr_mouse() {
    local sequence="$1" code_text x_text y_text code suffix raw_button
    [[ "$sequence" =~ ^$'\e'\[\<([0-9]{1,6})\;([0-9]{1,6})\;([0-9]{1,6})([Mm])$ ]] || return 1

    code_text=${BASH_REMATCH[1]}
    x_text=${BASH_REMATCH[2]}
    y_text=${BASH_REMATCH[3]}
    suffix=${BASH_REMATCH[4]}
    code=$((10#$code_text))
    MOUSE_X=$((10#$x_text - 1))
    MOUSE_Y=$((10#$y_text - 1))
    (( code <= 255 && MOUSE_X < 100000 && MOUSE_Y < 100000 )) || return 1
    (( MOUSE_X >= 0 && MOUSE_Y >= 0 )) || return 1

    MOUSE_SHIFT=$(( (code & 4) != 0 ))
    MOUSE_ALT=$(( (code & 8) != 0 ))
    MOUSE_CTRL=$(( (code & 16) != 0 ))
    MOUSE_MOTION=$(( (code & 32) != 0 ))
    MOUSE_WHEEL=$(( (code & 64) != 0 ))
    raw_button=$((code & 3))
    MOUSE_BUTTON=$((raw_button + 1))

    if (( MOUSE_WHEEL )); then
        MOUSE_ACTION=wheel
        (( raw_button == 0 )) && MOUSE_BUTTON=4 || MOUSE_BUTTON=5
    elif [[ "$suffix" == m || "$raw_button" == 3 ]]; then
        MOUSE_ACTION=release
        MOUSE_BUTTON=0
    elif (( MOUSE_MOTION )); then
        MOUSE_ACTION=drag
    else
        MOUSE_ACTION=press
    fi
}
