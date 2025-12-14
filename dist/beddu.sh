#!/usr/bin/env bash
# shellcheck disable=all
#
# beddu.sh - A lightweight bash framework for interactive scripts and pretty output
# Version: v1.2.0
#
# Copyright © 2025 Manuele Sarfatti
# Licensed under the MIT license
# See https://github.com/mjsarfatti/beddu

readonly _q='?'
readonly _a='❯'
readonly _o='◌'
readonly _O='●'
readonly _mark='✓'
readonly _warn='!'
readonly _cross='✗'
readonly _spinner='⣷⣯⣟⡿⢿⣻⣽⣾' # See for alternatives: https://antofthy.gitlab.io/info/ascii/Spinners.txt
readonly _spinner_frame_duration=0.1

up() {
    printf "\033[A"
}
down() {
    printf "\033[B"
}
bol() {
    printf "\r"
}
eol() {
    printf "\033[999C"
}
cl() {
    printf "\033[2K"
}
upclear() {
    up; bol; cl
}
line() {
    printf "\n"
}
show_cursor() {
    printf "\033[?25h"
}
hide_cursor() {
    printf "\033[?25l"
}

pen() {
    local new_line="\n"
    local text="${*: -1}"      
    local args=("${@:1:$#-1}") 
    local format_code=""
    local reset_code="\033[0m"
    for arg in "${args[@]}"; do
        arg=${arg,,} 
        case "$arg" in
        -n) new_line="" ;;
        bold) format_code+="\033[1m" ;;
        italic) format_code+="\033[3m" ;;
        underline) format_code+="\033[4m" ;;
        black) format_code+="\033[30m" ;;
        red) format_code+="\033[31m" ;;
        green) format_code+="\033[32m" ;;
        yellow) format_code+="\033[33m" ;;
        blue) format_code+="\033[34m" ;;
        purple) format_code+="\033[35m" ;;
        cyan) format_code+="\033[36m" ;;
        white) format_code+="\033[37m" ;;
        grey | gray) format_code+="\033[90m" ;;
        [0-9]*)
            if [[ "$arg" =~ ^[0-9]+$ ]] && [ "$arg" -ge 0 ] && [ "$arg" -le 255 ]; then
                format_code+="\033[38;5;${arg}m"
            fi
            ;;
        *) ;; 
        esac
    done
    printf "%b%s%b%b" "${format_code}" "${text}" "${reset_code}" "${new_line}"
}

run() {
    local outvar_name errvar_name
    local -n outvar errvar # Declare namerefs (will be assigned below if needed)
    local cmd
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --out)
            outvar_name="$2"
            shift 2
            ;;
        --err)
            errvar_name="$2"
            shift 2
            ;;
        *)
            cmd=("$@")
            break
            ;;
        esac
    done
    [[ -n "${outvar_name}" ]] && local -n outvar="${outvar_name}"
    [[ -n "${errvar_name}" ]] && local -n errvar="${errvar_name}"
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)
    local old_settings=$- 
    set +e # Don't immediately exit on error
    "${cmd[@]}" >"${stdout_file}" 2>"${stderr_file}"
    local exit_code=$?
    [[ -n "${outvar_name}" ]] && outvar="$(<"$stdout_file")"
    [[ -n "${errvar_name}" ]] && errvar="$(<"$stderr_file")"
    if [ $exit_code -ne 0 ] && [[ -z "${errvar_name}" ]]; then
        cleaned_errvar=$(sed 's/^[^:]\{1,\}:\( line [0-9]\{1,\}:\)\{0,1\} \(.*\)/\2/' "$stderr_file")
        line
        throw "Command \`$(pen 245 "${cmd[*]}")\` failed with error:"
        pen 245 "  ${cleaned_errvar}"
        pen "  called from: $(pen 245 "${BASH_SOURCE[1]}:${BASH_LINENO[0]}") in $(pen 245 "${FUNCNAME[1]:-main}")"
        line
    fi
    rm -f "${stdout_file}" "${stderr_file}"
    if [[ $old_settings == *e* ]]; then set -e; else set +e; fi
    return $exit_code
}

check() {
    if spinning; then
        spop
        upclear
    fi
    pen -n green "${_mark:-✓} "
    pen "$@"
}

repen() {
    upclear
    pen "$@"
}

trap "spop; show_cursor" EXIT INT TERM
_spinner_pid=""
_frame_duration="${_spinner_frame_duration:-0.1}"
spin() {
    local message=("$@")
    local spinner="${_spinner:-⣷⣯⣟⡿⢿⣻⣽⣾}"
    if spinning; then
        spop --keep-cursor-hidden
    fi
    (
        hide_cursor
        trap "exit 0" USR1
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
spop() {
    local old_settings=$- 
    set +e # Don't immediately exit on error
    local keep_cursor_hidden=false
    [[ "$1" == "--keep-cursor-hidden" ]] && keep_cursor_hidden=true
    if spinning; then
        kill -USR1 "${_spinner_pid}" 2>/dev/null
        sleep "$_frame_duration"
        if ps -p "${_spinner_pid}" >/dev/null 2>&1; then
            kill "${_spinner_pid}" 2>/dev/null
        fi
        if [[ "$keep_cursor_hidden" == false ]]; then
            show_cursor
        fi
        _spinner_pid=""
    fi
    if [[ $old_settings == *e* ]]; then set -e; else set +e; fi
}
spinning() {
    [[ -n "${_spinner_pid}" ]]
}

throw() {
    if spinning; then
        spop
        upclear
    fi
    pen -n red "${_cross:-✗} "
    pen "$@"
}

warn() {
    if spinning; then
        spop
        upclear
    fi
    pen -n yellow bold italic "${_warn:-!} "
    pen italic "$@"
}

choose() {
    local -n outvar="$1"
    local prompt
    local options=("${@:3}") 
    local current=0
    local count=${#options[@]}
    prompt=$(
        pen -n blue "${_q:-?} "
        pen -n "${2} "
        pen gray "[↑↓]"
    )
    hide_cursor
    trap 'show_cursor; return' INT TERM
    pen "$prompt"
    while true; do
        local index=0
        for item in "${options[@]}"; do
            if ((index == current)); then
                pen -n blue "${_O:-●} "
                pen "${item}"
            else
                pen gray "${_o:-◌} ${item}"
            fi
            ((index++))
        done
        read -s -r -n1 key
        if [[ $key == $'\e' ]]; then
            read -s -r -n2 -t 0.0001 escape
            key+="$escape"
        fi
        case "$key" in
        $'\e[A' | 'k') 
            ((current--))
            [[ $current -lt 0 ]] && current=$((count - 1))
            ;;
        $'\e[B' | 'j') 
            ((current++))
            [[ $current -ge "$count" ]] && current=0
            ;;
        '') 
            break
            ;;
        esac
        echo -en "\e[${count}A\e[J"
    done
    outvar="${options[$current]}"
}

confirm() {
    local default="y"
    local hint="[Y/n]"
    local prompt
    local response
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
    prompt=$(
        pen -n blue "${_q:-?} "
        pen -n "$1"
        pen gray " $hint"
        pen -n blue "${_a:-❯} "
    )
    show_cursor
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

request() {
    local -n outvar="$1" 
    local prompt
    local answer
    prompt=$(
        pen -n blue "${_q:-?} "
        pen "${2}"
        pen -n blue "${_a:-❯} "
    )
    show_cursor
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
    outvar="$answer"
}

seek() {
    local -n outvar="$1" 
    local prompt
    local answer
    prompt=$(
        pen -n blue "${_q:-?} "
        pen "${2}"
        pen -n blue "${_a:-❯} "
    )
    show_cursor
    read -r -p "$prompt" answer
    outvar="$answer"
}
