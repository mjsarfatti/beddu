#!/usr/bin/env bash
# movements.sh - Cursor helper functions

[[ $BEDDU_MOVEMENTS_LOADED ]] && return
readonly BEDDU_MOVEMENTS_LOADED=true

# Move cursor up one line
up() {
    printf "\033[A"
}

# Move cursor down one line
down() {
    printf "\033[B"
}

# Move cursor to beginning of line
bol() {
    printf "\r"
}

# Move cursor to end of line
eol() {
    printf "\033[999C"
}

# Clear entire line
cl() {
    printf "\033[2K"
}

# Clear line above
upclear() {
    up; bol; cl
}

# Print a single newline
line() {
    printf "\n"
}

# Show cursor
show_cursor() {
    printf "\033[?25h"
}

# Hide cursor, and make sure that it comes back when the script exits
hide_cursor() {
    printf "\033[?25l"
    _beddu_set_traps
}

# Set the EXIT, INT and TERM traps of beddu. Keep the trap of the caller
# for each signal, so that the beddu trap can run it. Do nothing for a
# signal that already has the beddu trap.
_beddu_set_traps() {
    local signal current
    for signal in EXIT INT TERM; do
        current="$(trap -p "$signal")"
        [[ "$current" == *_beddu_on_signal* ]] && continue
        if [[ -n "$current" ]]; then
            # "trap -- 'command' SIGNAL" becomes $1=command, $2=SIGNAL
            eval "set -- ${current#trap -- }"
            printf -v "_beddu_trap_${signal}" '%s' "$1"
        else
            unset "_beddu_trap_${signal}"
        fi
    done
    trap '_beddu_on_signal EXIT "$?"' EXIT
    trap '_beddu_on_signal INT' INT
    trap '_beddu_on_signal TERM' TERM
}

# Run the trap of the caller for this signal. If the caller has no trap
# for INT or TERM, stop the script with the signal. On EXIT, first stop
# the spinner and show the cursor. Each exit runs the EXIT trap, also an
# exit on INT or TERM, so the clean-up is only necessary there.
_beddu_on_signal() {
    local signal="$1" status="$2"
    local saved="_beddu_trap_${signal}"

    if [[ "$signal" == EXIT ]]; then
        if declare -F spinning >/dev/null && spinning; then
            spop
        else
            show_cursor
        fi
    fi

    if [[ -n "${!saved+set}" ]]; then
        # Give the original $? to the caller trap. "||" prevents an exit by set -e.
        if [[ "${status:-0}" -eq 0 ]]; then
            eval "${!saved}"
        else
            _beddu_return "$status" || eval "${!saved}"
        fi
    elif [[ "$signal" != EXIT ]]; then
        # Stop with the signal, not with "exit 130". Then a parent process
        # (a loop, make, xargs) knows that the script stopped on the signal.
        # $BASHPID is this shell, also in a subshell.
        trap - "$signal"
        kill -"$signal" "$BASHPID"
    fi
}

# Set $? to the given value
_beddu_return() {
    return "$1"
}
