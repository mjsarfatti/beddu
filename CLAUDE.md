# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Beddu is a small Bash library for interactive scripts with formatted output. Users source one file, `dist/beddu.sh`. It requires Bash 4+ (it uses `${var,,}` and `local -n` namerefs). The project keeps a minimal scope by design: do not add large features.

## Commands

- `make build` — clean and rebuild `dist/beddu.sh` from `src/`.
- `make` — rebuild only if a source file changed.
- `make demo` — build, then run `demo/demo.sh` (interactive; it downloads a 12 MB file).
- `make release-patch|release-minor|release-major` — bump the version, build, commit, tag, push, and create a GitHub release with `gh`. Use only on `main` with a clean tree. The recipe uses `sed -i ''`, so it works on macOS (BSD sed) only.

There is no test suite and no lint target. Run `shellcheck src/**/*.sh` to lint, if it is installed. To test a change, run `make build` and then `make demo`, or source `dist/beddu.sh` in a small script.

## Architecture

### Source layout and build

- `src/` contains one function (or one group of helpers) per file. The numeric prefix of each directory sets the concatenation order: `00.utils` → `01.core` → `02.ui` → `03.prompt`. Inside a directory, the order is alphabetical.
- Each source file can run on its own. It has a load guard (`[[ $BEDDU_X_LOADED ]] && return` + `readonly BEDDU_X_LOADED=true`) and it sources its dependencies with `SCRIPT_DIR=... ; source "$SCRIPT_DIR/..."`.
- The `$(OUTPUT)` rule in the `Makefile` concatenates the files into `dist/beddu.sh`. It removes these lines: full-line comments, `source ...`, `SCRIPT_DIR=...`, and the load guards. It also removes trailing `# words` comments that contain only letters, digits, and spaces. Thus, a dependency must come from an earlier directory (or an earlier file in the same directory) to exist in the built file. Keep `source`, `SCRIPT_DIR=`, and guard lines in these exact forms, or the build will not remove them.
- `dist/beddu.sh` is committed. Rebuild it after you change `src/`. The release step writes the version into its header and into the version strings in `README.md`.

### Runtime conventions

- `pen` (`01.core/pen.sh`) is the base output function. Most other functions call it. The last argument is the text. The arguments before it are style tokens: `-n`, `bold`, `italic`, `underline`, color names, or `0`–`255`. `repen`, `check`, `warn`, `throw`, and `spin` pass their arguments directly to `pen`.
- Symbols and spinner frames are `readonly` globals in `00.utils/_symbols.sh` (`_q`, `_a`, `_mark`, `_spinner`, ...). Callers use `${_mark:-✓}` fallbacks, so each file works without the symbols file.
- `00.utils/movements.sh` contains the ANSI cursor helpers (`up`, `bol`, `cl`, `upclear`, `line`, `show_cursor`, `hide_cursor`).
- Spinner state: `spin` starts a background subshell and stores its PID in the global `_spinner_pid`. `spop` stops it with `USR1`. `spinning` checks for the PID. `check`, `warn`, and `throw` stop an active spinner and overwrite its line (`spop` + `upclear`). This works only if the spinner line is the last output. `spin.sh` sets a global `trap "spop; show_cursor" EXIT INT TERM`.
- Functions that return values (`seek`, `request`, `choose`, `run --out/--err`) write to a variable name from the caller through `local -n` namerefs. `confirm` returns its result as the exit status.
- `spop` and `run` save `$-`, set `set +e`, and restore `errexit` at the end. Use the same method in new code that must not exit under `set -e`.
- Prompts set `trap "exit 130" INT` so that Ctrl+C exits with status 130. `choose` also restores the cursor on exit.

### Known issue

`03.prompt/seek.sh` and `03.prompt/request.sh` use the same guard variable, `BEDDU_ASK_LOADED`. When you source files from `src/` directly, only the first of the two loads. The built file is correct because the build removes the guards.

## Style

`.editorconfig`: 4-space indentation for `*.sh`. Each public function has a header comment with `Usage:`, `Options:`, and `Examples:` sections. When you add or change a public function, also update the "Function Reference" section in `README.md`.
