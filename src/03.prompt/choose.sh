#!/usr/bin/env bash
# shellcheck disable=SC1091
# choose.sh - Choose from a menu of options

[[ $BEDDU_CHOOSE_LOADED ]] && return
readonly BEDDU_CHOOSE_LOADED=true

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../00.utils/_symbols.sh"
source "$SCRIPT_DIR/../00.utils/movements.sh"
source "$SCRIPT_DIR/../01.core/pen.sh"

# Print an interactive menu of options and return the selected option
#
# Usage:
#   choose outvar text [choices...]
# Example:
#   choose color "What is your favorite color?" "Red" "Blue" "Green"
#   pen "You chose $color!"
choose() {
    local -n outvar="$1"
    local prompt
    local options=("${@:3}") # Get options from third argument onwards

    local current=0
    local count=${#options[@]}

    # Set prompt with default indicator
    prompt=$(
        pen -n blue "${_q:-?} "
        pen -n "${2} "
        pen gray "[↑↓]"
    )

    # Hide cursor for cleaner UI
    hide_cursor
    
    # Resore cursor on:
    # - Normal exit
    # - Ctrl+C (with proper exit code 130)
    # - SIGTERM
    # - Any error that causes exit
    trap 'show_cursor' EXIT TERM
    trap "show_cursor; exit 130" INT # Exit on Ctrl+C

    # Display initial prompt
    pen "$prompt"

    # Main loop
    while true; do
        local index=0
        for item in "${options[@]}"; do
            if ((index == current)); then
                pen -n blue "${_O:-●} "
                pen "${item}"
            else
                pen gray "${_o:-◌} ${item}"
            fi
            ((++index))
        done

        # Read a single key press
        read -s -r -n1 key

        # Handle arrow/enter keys
        if [[ $key == $'\e' ]]; then
            read -s -r -n2 -t 0.0001 escape
            key+="$escape"
        fi

        case "$key" in
        $'\e[A' | 'k') # Up arrow or k
            ((--current))
            [[ $current -lt 0 ]] && current=$((count - 1))
            ;;
        $'\e[B' | 'j') # Down arrow or j
            ((++current))
            [[ $current -ge "$count" ]] && current=0
            ;;
        '') # Enter
            break
            ;;
        esac

        # Clear screen and repeat
        echo -en "\e[${count}A\e[J"
    done

    # Pass selected option back to caller
    # shellcheck disable=SC2034
    outvar="${options[$current]}"
}
