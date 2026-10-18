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

# Loading

test_source_two_times_shows_no_errors() {
    run 'source "$B"; source "$B"; echo done'
    expect_out_contains "done"
    expect_out_not_contains "readonly"
}

test_seek_and_request_load_from_src() {
    run 'source src/03.prompt/seek.sh; source src/03.prompt/request.sh; type -t seek request'
    expect_out_contains "function
function"
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
