#!/usr/bin/env bash
# run.sh - Run the beddu tests
#
# Usage:
#   test/run.sh [path/to/beddu.sh]
# Environment:
#   BASH_BIN  The bash that runs each test (default: bash)
#
# Each test is a function with a name that starts with "test_".
# Each test runs beddu in a new shell. beddu and the tests need bash 4 or later.

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BEDDU="${1:-$ROOT/dist/beddu.sh}"
BASH_BIN="${BASH_BIN:-bash}"

# Run code in a new shell. "$B" is the path to beddu.sh.
# Sets $out (stdout and stderr) and $status.
run() {
    out="$(cd "$ROOT" && B="$BEDDU" "$BASH_BIN" -c "$1" 2>&1)"
    status=$?
}

fail() {
    printf '    %s\n' "$@"
    exit 1
}

expect_out() {
    [[ "$out" == "$1" ]] || fail "expected output: $1" "actual output:   $out"
}

expect_out_contains() {
    [[ "$out" == *"$1"* ]] || fail "expected output to contain: $1" "actual output: $out"
}

expect_out_not_contains() {
    [[ "$out" != *"$1"* ]] || fail "expected output not to contain: $1" "actual output: $out"
}

expect_status() {
    [[ "$status" -eq "$1" ]] || fail "expected exit status: $1" "actual exit status:   $status"
}

readonly SHOW_CURSOR=$'\033[?25h'

# Loading

test_source_prints_nothing() {
    run 'source "$B"; echo done'
    expect_out "done"
}

test_source_two_times_shows_no_errors() {
    run 'source "$B"; source "$B"; echo done'
    expect_out_contains "done"
    expect_out_not_contains "readonly"
}

test_execute_directly_prints_nothing() {
    run '"$0" "$B"'
    expect_status 0
    expect_out ""
}

test_seek_and_request_load_from_src() {
    run 'source src/03.prompt/seek.sh; source src/03.prompt/request.sh; type -t seek request'
    expect_out_contains "function
function"
}

# Traps

test_source_sets_no_traps() {
    run 'source "$B"; trap -p EXIT INT TERM'
    expect_out ""
}

test_interactive_shell_has_no_int_trap() {
    out="$(B="$BEDDU" "$BASH_BIN" --norc -ic 'source "$B"; echo "[$(trap -p INT)]"' 2>/dev/null)"
    expect_out "[]"
}

test_caller_exit_trap_runs_after_spop() {
    run 'trap "echo cleanup" EXIT; source "$B"; spin x >/dev/null; sleep 0.3; spop >/dev/null; echo done'
    expect_out_contains "done"
    expect_out_contains "cleanup"
}

test_spop_keep_cursor_hidden_keeps_caller_traps() {
    run 'trap "echo cleanup" EXIT; source "$B"; spin a >/dev/null; sleep 0.3; spop --keep-cursor-hidden
         spin b >/dev/null; sleep 0.3; spop >/dev/null; echo done'
    expect_out_contains "done"
    expect_out_contains "cleanup"
}

test_caller_trap_set_after_spin_runs() {
    run 'source "$B"; spin x >/dev/null; sleep 0.3; spop >/dev/null; trap "echo cleanup" EXIT
         hide_cursor; echo done'
    expect_out_contains "done"
    expect_out_contains "cleanup"
}

test_prompts_set_no_traps() {
    run 'source "$B"; { seek v Q; request w Q; confirm Q; } < <(printf "a\nb\ny\n") >/dev/null; echo "[$(trap -p EXIT INT TERM)]"'
    expect_out "[]"
}

test_caller_int_trap_runs_after_choose() {
    run 'trap "echo caller-int" INT; source "$B"; choose c Q a b <<< "" >/dev/null; kill -INT $$; echo continued'
    expect_status 0
    expect_out_contains "caller-int"
    expect_out_contains "continued"
}

# Signals

test_int_during_spin_stops_script() {
    run 'source "$B"; spin x >/dev/null; (sleep 0.3; kill -INT $$) & sleep 1; echo continued'
    expect_status 130
    expect_out_not_contains "continued"
}

test_term_during_spin_stops_script() {
    run 'source "$B"; spin x >/dev/null; (sleep 0.3; kill -TERM $$) & sleep 1; echo continued'
    expect_status 143
    expect_out_not_contains "continued"
}

test_caller_int_trap_runs_during_spin() {
    run 'trap "echo caller-int" INT; source "$B"; spin x >/dev/null
         (sleep 0.3; kill -INT $$) & sleep 1; echo continued; spop >/dev/null'
    expect_status 0
    expect_out_contains "caller-int"
    expect_out_contains "continued"
}

test_caller_int_trap_can_exit_during_spin() {
    run 'trap "exit 9" INT; source "$B"; spin x >/dev/null; (sleep 0.3; kill -INT $$) & sleep 1; echo continued'
    expect_status 9
    expect_out_not_contains "continued"
}

test_ignored_int_stays_ignored_during_spin() {
    run 'trap "" INT; source "$B"; spin x >/dev/null; (sleep 0.3; kill -INT $$) & sleep 1; echo continued; spop >/dev/null'
    expect_status 0
    expect_out_contains "continued"
}

test_caller_exit_trap_gets_exit_status() {
    run 'trap "echo cleanup \$?" EXIT; source "$B"; spin x >/dev/null; sleep 0.3; exit 4'
    expect_status 4
    expect_out_contains "cleanup 4"
}

test_caller_exit_trap_runs_with_set_e() {
    run 'set -e; trap "echo cleanup \$?" EXIT; source "$B"; spin x >/dev/null; sleep 0.3; false; echo continued'
    expect_status 1
    expect_out_contains "cleanup 1"
    expect_out_not_contains "continued"
}

test_caller_exit_trap_with_quotes() {
    run "trap 'echo \"it'\\''s here\"' EXIT; source \"\$B\"; spin x >/dev/null; sleep 0.3; exit 0"
    expect_status 0
    expect_out_contains "it's here"
}

test_caller_int_trap_keeps_spinner_running() {
    run 'trap "echo caller-int" INT; source "$B"; spin x >/dev/null
         (sleep 0.3; kill -INT $$) & sleep 0.8; spinning && echo still-spinning; spop >/dev/null'
    expect_status 0
    expect_out_contains "caller-int"
    expect_out_contains "still-spinning"
}

test_int_stops_parent_loop() {
    run 'child="$(mktemp)"; parent="$(mktemp)"
         printf "%s\n" "source \"\$B\"; spin x >/dev/null; sleep 2" > "$child"
         printf "%s\n" "for i in 1 2; do \"\$BASH\" \"\$1\"; echo child-\$i-done; done; echo parent-done" > "$parent"
         set -m; "$BASH" "$parent" "$child" & pid=$!
         sleep 0.5; kill -INT -"$pid"; wait "$pid"; echo "status $?"; rm -f "$child" "$parent"'
    expect_out_contains "status 130"
    expect_out_not_contains "child-1-done"
    expect_out_not_contains "parent-done"
}

# Cursor

test_exit_during_spin_shows_cursor() {
    run 'source "$B"; spin x; sleep 0.3; exit 3'
    expect_status 3
    [[ "$out" == *"$SHOW_CURSOR" ]] || fail "expected output to end with the show cursor code"
}

test_spop_shows_cursor() {
    run 'source "$B"; spin x; sleep 0.3; spop; echo done'
    expect_out_contains "${SHOW_CURSOR}done"
}

test_choose_keeps_cursor_hidden() {
    run 'source "$B"; choose c Q a b <<< ""; echo "[done]"'
    expect_out_contains "[done]"
    [[ "${out%%"[done]"*}" != *"$SHOW_CURSOR"* ]] || fail "expected no show cursor code before the end of the script"
}

test_exit_after_choose_shows_cursor() {
    run 'source "$B"; choose c Q a b <<< ""; exit 5'
    expect_status 5
    [[ "$out" == *"$SHOW_CURSOR" ]] || fail "expected output to end with the show cursor code"
}

test_int_after_choose_shows_cursor_and_stops_script() {
    run 'source "$B"; choose c Q a b <<< ""; kill -INT $$; echo continued'
    expect_status 130
    expect_out_not_contains "continued"
    [[ "$out" == *"$SHOW_CURSOR" ]] || fail "expected output to end with the show cursor code"
}

# Runner

if [[ ! -f "$BEDDU" ]]; then
    echo "File not found: $BEDDU (run \"make build\" first)" >&2
    exit 1
fi

echo "Testing $BEDDU with $("$BASH_BIN" -c 'echo "bash $BASH_VERSION"')"

passed=0
failed=0
for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if result="$("$t")"; then
        passed=$((passed + 1))
        echo "ok     $t"
    else
        failed=$((failed + 1))
        echo "FAIL   $t"
        echo "$result"
    fi
done

echo ""
echo "$passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
