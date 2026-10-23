#!/usr/bin/env bash
# Shared Desktop Entry encoding; this file has no entry-time side effects.

_desktop_value() {
    # Desktop Entry string escaping happens before Exec argument parsing.
    local value="$1" out="" char i
    for ((i=0; i<${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            \\) out+='\\' ;;
            $'\n') out+='\n' ;;
            $'\r') out+='\r' ;;
            $'\t') out+='\t' ;;
            *) out+="$char" ;;
        esac
    done
    printf '%s' "$out"
}

_desktop_exec_arg() {
    local value="$1" out='"' char i
    # Control characters are not supported as executable paths. Refuse rather
    # than allowing a path to introduce another key or ambiguous argument.
    [[ "$value" == /* && "$value" != *[[:cntrl:]]* && "$value" != *=* ]] || return 1
    for ((i=0; i<${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            \\|'"'|'`'|'$') out+="\\$char" ;;
            '%') out+='%%' ;;
            *) out+="$char" ;;
        esac
    done
    out+='"'
    _desktop_value "$out"
}

render_desktop_entry() {
    local template="$1" binary="$2" icon="$3" line exec_value icon_value
    local exec_count=0 icon_count=0
    [[ -f "$template" && "$icon" != *[[:cntrl:]]* ]] || return 1
    exec_value="$(_desktop_exec_arg "$binary")" || return 1
    icon_value="$(_desktop_value "$icon")" || return 1
    # Match whole template lines, not regexp replacement strings. In particular,
    # '&', backslashes and Bash's patsub_replacement option have no special role.
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            Exec=__TOGLIT_EXEC__)
                # A fixed executable avoids parsers testing a literal '%%' path
                # before field-code expansion. env runs the quoted absolute path
                # as one argument; there is no shell or variable interpolation.
                printf 'Exec=/usr/bin/env %s\n' "$exec_value" || return 1
                exec_count=$((exec_count+1)) ;;
            Icon=__TOGLIT_ICON__)
                printf 'Icon=%s\n' "$icon_value" || return 1
                icon_count=$((icon_count+1)) ;;
            *) printf '%s\n' "$line" || return 1 ;;
        esac
    done < "$template"
    [[ "$exec_count" == 1 && "$icon_count" == 1 ]]
}
