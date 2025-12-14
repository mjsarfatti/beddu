#!/usr/bin/env bash
# shellcheck disable=SC1091
# seek.sh - Get free text input from the user

[[ $BEDDU_ASK_LOADED ]] && return
readonly BEDDU_ASK_LOADED=true

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../00.utils/_symbols.sh"
source "$SCRIPT_DIR/../00.utils/movements.sh"
source "$SCRIPT_DIR/../01.core/pen.sh"
source "$SCRIPT_DIR/../02.ui/warn.sh"

# Ask a question and get a free text answer from the user
#
# Usage:
#   seek outvar text
# Example:
#   seek name "What is your name?"
#   echo "Hello, $name!"
seek() {
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
    read -r -p "$prompt" answer

    # shellcheck disable=SC2034
    outvar="$answer"
}
