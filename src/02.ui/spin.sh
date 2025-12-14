#!/usr/bin/env bash
# shellcheck disable=SC1091
# spin.sh - Print a spinner with a message

[[ $BEDDU_SPIN_LOADED ]] && return
readonly BEDDU_SPIN_LOADED=true

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../00.utils/_symbols.sh"
source "$SCRIPT_DIR/../00.utils/movements.sh"
source "$SCRIPT_DIR/../01.core/pen.sh"

# Make sure the cursor is shown and the spinner stopped if the script exits abnormally
trap "spop; show_cursor" EXIT INT TERM

# Module state variables
_spinner_pid=""
_frame_duration="${_spinner_frame_duration:-0.1}"

# Print a message with a spinner at the beginning
#
# Usage:
#   spin [options] text
# Options:
#   [same as pen.sh]
# Examples:
#   spin "Installing dependencies..."
#   sleep 2
#   spop
#   pen "Let's do something else now..."
#   --or, better--
#   spin "Installing dependencies..."
#   sleep 2
#   check "Dependancies installed."
spin() {
    local message=("$@")
    local spinner="${_spinner:-⣷⣯⣟⡿⢿⣻⣽⣾}"

    # If there is already a spinner running, stop it
    if spinning; then
        spop --keep-cursor-hidden
    fi

    # Run the spinner in the background
    (
        hide_cursor

        # Use a trap to catch USR1 signal for clean shutdown
        trap "exit 0" USR1

        # Print the first frame of the spinner
        pen -n cyan "${spinner:0:1} "
        pen "${message[@]}"

        while true; do
            for ((i = 0; i < ${#spinner}; i++)); do
                frame="${spinner:$i:1}"
                up
                bol
                pen -n cyan "${frame} "
                pen "${message[@]}"
                sleep "$_frame_duration"
            done
        done
    ) &

    _spinner_pid=$!
}

# Stop the spinner
spop() {
    local old_settings=$- # Save current settings
    set +e # Don't immediately exit on error

    local keep_cursor_hidden=false
    [[ "$1" == "--keep-cursor-hidden" ]] && keep_cursor_hidden=true

    if spinning; then
        # Signal spinner to exit gracefully
        kill -USR1 "${_spinner_pid}" 2>/dev/null

        # Wait briefly for cleanup
        sleep "$_frame_duration"

        # Ensure it's really gone
        if ps -p "${_spinner_pid}" >/dev/null 2>&1; then
            kill "${_spinner_pid}" 2>/dev/null
        fi

        # Manually clean up display, unless asked not to do so
        if [[ "$keep_cursor_hidden" == false ]]; then
            show_cursor
        fi

        _spinner_pid=""
    fi
    
    # Restore errexit behavior
    if [[ $old_settings == *e* ]]; then set -e; else set +e; fi
}

# Check if a spinner is running
spinning() {
    [[ -n "${_spinner_pid}" ]]
}
