#!/usr/bin/env bash
# shellcheck disable=SC1091
# request.sh - Get required text input from the user

[[ $BEDDU_ASK_LOADED ]] && return
readonly BEDDU_ASK_LOADED=true

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../00.utils/_symbols.sh"
source "$SCRIPT_DIR/../00.utils/movements.sh"
source "$SCRIPT_DIR/../01.core/pen.sh"
source "$SCRIPT_DIR/../02.ui/warn.sh"

# Ask a question and require a free text answer from the user
#
# Usage:
#   request outvar text
# Example:
#   request name "What is your name?"
#   echo "Hello, $name!"
request() {
    local -n outvar="$1" # Declare nameref
    local prompt
    local answer

    # Set prompt with default indicator
    prompt=$(
        pen -n blue "${_q:-?} "
        pen "${2}"
        pen -n blue "${_a:-❯} "
    )

    show_cursor
    
    trap "exit 130" INT # Exit on Ctrl+C

    # Get response
    while true; do
        read -r -p "$prompt" answer
        case "$answer" in
        "")
            echo
            warn "Please type your answer."
            ;;
        *) break ;;
        esac
    done

    # shellcheck disable=SC2034
    outvar="$answer"
}
