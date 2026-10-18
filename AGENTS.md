# AGENTS.md

This file gives guidance to coding agents that work in this repository.

## Project

Beddu is a small Bash library for interactive scripts with formatted output. Users source one file, `dist/beddu.sh`. It requires Bash 4+ (it uses `${var,,}` and `local -n` namerefs). The project keeps a minimal scope by design: do not add large features.

## Commands

- `make build` — clean and rebuild `dist/beddu.sh` from `src/`.
- `make` — rebuild only if a source file changed.
- `make test` — build, then run `test/run.sh` against `dist/beddu.sh`.
- `make demo` — build, then run `demo/demo.sh` (interactive; it downloads a 12 MB file).
- `make release-patch|release-minor|release-major` — bump the version, build, commit, tag, push, and create a GitHub release with `gh`. Use only on `main` with a clean tree. The recipe uses `sed -i ''`, so it works on macOS (BSD sed) only.

There is no lint target. Run `shellcheck src/**/*.sh` to lint, if it is installed.

CI (`.github/workflows/test.yml`) runs `make test` on Ubuntu and macOS for each pull request and for each push to `main`.

## Tests

- Add one or more tests for each new feature and for each bug fix.
- Put the tests in `test/run.sh`. Each test is a function. The name of the function starts with `test_`.
- Each test runs beddu in a new shell through the `run` helper. `run` sets `$out` and `$status`. Use the `expect_*` helpers to check them.
- Run the tests with `make test`. To use a different bash, set `BASH_BIN`.
- beddu needs bash 4 or later. Do not use bash 5 features. On macOS, `/bin/bash` is bash 3.2, so use `make test BASH_BIN=$(brew --prefix)/bin/bash`.

## Architecture

### Source layout and build

- `src/` contains one function (or one group of helpers) per file. The numeric prefix of each directory sets the concatenation order: `00.utils` → `01.core` → `02.ui` → `03.prompt`. Inside a directory, the order is alphabetical.
- Each source file can run on its own. It has a load guard (`[[ $BEDDU_X_LOADED ]] && return` + `readonly BEDDU_X_LOADED=true`) and it sources its dependencies with `SCRIPT_DIR=... ; source "$SCRIPT_DIR/..."`.
- The `$(OUTPUT)` rule in the `Makefile` concatenates the files into `dist/beddu.sh`. It removes these lines: full-line comments, `source ...`, `SCRIPT_DIR=...`, and the load guards. It also removes trailing `# words` comments that contain only letters, digits, and spaces. Thus, a dependency must come from an earlier directory (or an earlier file in the same directory) to exist in the built file. Keep `source`, `SCRIPT_DIR=`, and guard lines in these exact forms, or the build will not remove them.
- The build adds a `BEDDU_LOADED` guard at the top of `dist/beddu.sh`. If a script sources the file two times, the second `source` does nothing.
- `dist/beddu.sh` is committed. Rebuild it after you change `src/`. The release step writes the version into its header and into the version strings in `README.md`.

### Runtime conventions

- `pen` (`01.core/pen.sh`) is the base output function. Most other functions call it. The last argument is the text. The arguments before it are style tokens: `-n`, `bold`, `italic`, `underline`, color names, or `0`–`255`. `repen`, `check`, `warn`, `throw`, and `spin` pass their arguments directly to `pen`.
- Symbols and spinner frames are `readonly` globals in `00.utils/_symbols.sh` (`_q`, `_a`, `_mark`, `_spinner`, ...). Callers use `${_mark:-✓}` fallbacks, so each file works without the symbols file.
- `00.utils/movements.sh` contains the ANSI cursor helpers (`up`, `bol`, `cl`, `upclear`, `line`, `show_cursor`, `hide_cursor`).
- Spinner state: `spin` starts a background subshell and stores its PID in the global `_spinner_pid`. `spop` stops it with `USR1`. `spinning` checks for the PID. `check`, `warn`, and `throw` stop an active spinner and overwrite its line (`spop` + `upclear`). This works only if the spinner line is the last output.
- Spinner traps: sourcing beddu sets no traps. `spin` saves the traps of the caller and sets `EXIT`, `INT`, and `TERM` traps only while a spinner runs. `spop` restores the traps of the caller (but not with `--keep-cursor-hidden`, which `spin` uses when a new spinner follows). On a signal, `_spin_on_signal` stops the spinner and then runs the trap of the caller. If the caller has no trap, `INT` exits with 130 and `TERM` exits with 143.
- Functions that return values (`seek`, `request`, `choose`, `run --out/--err`) write to a variable name from the caller through `local -n` namerefs. `confirm` returns its result as the exit status.
- `spop` and `run` save `$-`, set `set +e`, and restore `errexit` at the end. Use the same method in new code that must not exit under `set -e`.
- Prompts set `trap "exit 130" INT` so that Ctrl+C exits with status 130. `choose` also restores the cursor on exit.

## Style

`.editorconfig`: 4-space indentation for `*.sh`. Each public function has a header comment with `Usage:`, `Options:`, and `Examples:` sections. When you add or change a public function, also update the "Function Reference" section in `README.md`.
