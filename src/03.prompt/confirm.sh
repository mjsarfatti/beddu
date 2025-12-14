#!/usr/bin/env bash
# shellcheck disable=SC1091
# confirm.sh - Read a yes/no confirmation from the user

[[ $BEDDU_CONFIRM_LOADED ]] && return
readonly BEDDU_CONFIRM_LOADED=true

SCRIPT_DIR="$(dirname -- "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../00.utils/_symbols.sh"
source "$SCRIPT_DIR/../00.utils/movements.sh"
source "$SCRIPT_DIR/../01.core/pen.sh"
source "$SCRIPT_DIR/../02.ui/warn.sh"

# Ask a question and get a yes/no answer from the user
#
# Usage:
#   confirm text
# Options:
#   --default-yes: Answer 'yes' on ENTER (default)
#   --default-no: Answer 'no' on ENTER
# Example:
#   if confirm "Would you like to continue?"; then
#     pen "Great!"
#   else
#     pen "Ok, bye!"
#   fi
confirm() {
    local default="y"
    local hint="[Y/n]"
    local prompt
    local response

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --default-no)
            default="n"
            hint="[y/N]"
            shift
            ;;
        --default-yes)
            shift
            ;;
        *) break ;;
        esac
    done

    # Set prompt with default indicator
    prompt=$(
        pen -n blue "${_q:-?} "
        pen -n "$1"
        pen gray " $hint"
        pen -n blue "${_a:-❯} "
    )

    show_cursor
    
    trap "exit 130" INT # Exit on Ctrl+C

    # Get response
    while true; do
        read -r -p "$prompt" response
        response="${response:-$default}"
        case "$response" in
        [Yy] | [Yy][Ee][Ss])
            upclear
            pen -n blue "${_a:-❯} "
            pen "yes"
            return 0
            ;;
        [Nn] | [Nn][Oo])
            upclear
            pen -n blue "${_a:-❯} "
            pen "no"
            return 1
            ;;
        *)
            echo
            warn "Please answer yes or no."
            ;;
        esac
    done
}
