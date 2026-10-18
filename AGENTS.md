# AGENTS.md

This file gives guidance to coding agents that work in this repository.

## Project

Beddu is a small Bash library for interactive scripts with formatted output. Users source one file, `dist/beddu.sh`. It requires Bash 4.3 or later (it uses `${var,,}` and `local -n` namerefs). The project keeps a minimal scope by design: do not add large features.

## Commands

- `make build` — clean and rebuild `dist/beddu.sh` from `src/`.
- `make` — rebuild only if a source file changed.
- `make test` — build, then run `test/run.sh` against `dist/beddu.sh`.
- `make demo` — build, then run `demo/demo.sh` (interactive; it downloads a 12 MB file).
- `make release-patch|release-minor|release-major` — bump the version, build, commit, tag, push, and create a GitHub release with `gh`. Use only on `main` with a clean tree. The recipe uses `sed -i ''`, so it works on macOS (BSD sed) only.

There is no lint target. Run `shellcheck src/**/*.sh` to lint, if it is installed.

CI (`.github/workflows/test.yml`) runs `make test` on Ubuntu, on macOS, and with bash 4.3 in a container, for each pull request and for each push to `main`.

## Tests

- Add one or more tests for each new feature and for each bug fix.
- Put the tests in `test/run.sh`. Each test is a function. The name of the function starts with `test_`.
- Each test runs beddu in a new shell through the `run` helper. `run` sets `$out` and `$status`. Use the `expect_*` helpers to check them.
- Run the tests with `make test`. To use a different bash, set `BASH_BIN`.
- beddu needs bash 4.3 or later. Do not use features of later versions. CI tests bash 4.3. On macOS, `/bin/bash` is bash 3.2, so use `make test BASH_BIN=$(brew --prefix)/bin/bash`.

## Workflow

1. Create a branch from `main`, one branch for each change. Name the branch `<type>/<slug>`:
   - `<type>` is the kind of change: `feat`, `fix`, `test`, `docs`, `build`, `refactor`, or `chore`.
   - `<slug>` is a short description that a person can read: lowercase words with hyphens (for example, `fix/double-load`).
   - Do not use generated or random names.
2. Open a pull request to `main`. CI runs the tests on the pull request.
3. Merge the pull request when CI passes. Use a squash merge.
4. To release, run `make release-patch`, `make release-minor`, or `make release-major` on `main`. This step builds `dist/beddu.sh`, makes the release commit and the tag, pushes them, and creates the GitHub release. Do not make the release commit manually.

The squash commit title is the pull request title. It must follow Conventional Commits (`feat:`, `fix:`, `refactor:`, `perf:`, ...). The release notes come from these titles: `feat` goes to "Added", `fix` to "Fixed", `refactor` and `perf` to "Changed". All other types (`docs`, `test`, `build`, `chore`, ...) go to "Misc". Mark a breaking change with `!` after the type (`feat!:`) or with a `BREAKING CHANGE: <text>` line in the commit body. A breaking change goes to "Breaking changes" only. Write `Fixes #N` in the commit body to link a solved issue. Write `Refs #N` to link a related issue.

Do not use a long-lived integration branch. If a change needs another change that is not merged, set the base of its pull request to the branch of the other change. When the first pull request merges, GitHub changes the base of the second pull request to `main`.

## Architecture

### Source layout and build

- `src/` contains one function (or one group of helpers) per file. The numeric prefix of each directory sets the concatenation order: `00.utils` → `01.core` → `02.ui` → `03.prompt`. Inside a directory, the order is alphabetical.
- Each source file can run on its own. It has a load guard (`[[ $BEDDU_X_LOADED ]] && return` + `readonly BEDDU_X_LOADED=true`) and it sources its dependencies with `SCRIPT_DIR=... ; source "$SCRIPT_DIR/..."`.
- The `$(OUTPUT)` rule in the `Makefile` concatenates the files into `dist/beddu.sh`. It removes these lines: full-line comments, `source ...`, `SCRIPT_DIR=...`, and the load guards. It also removes trailing `# words` comments that contain only letters, digits, and spaces. Thus, a dependency must come from an earlier directory (or an earlier file in the same directory) to exist in the built file. Keep `source`, `SCRIPT_DIR=`, and guard lines in these exact forms, or the build will not remove them.
- The build adds a `BEDDU_LOADED` guard at the top of `dist/beddu.sh`. If a script sources the file two times, the second `source` does nothing.
- `dist/beddu.sh` is committed, but only the release step updates it. `make build` and `make test` rebuild it locally. Do not commit these changes. Between releases, `dist/beddu.sh` on `main` stays at the last release. Users download it from a release tag.
- The release step writes the version into the header of `dist/beddu.sh` and into the version strings in `README.md`.

### Runtime conventions

- `pen` (`01.core/pen.sh`) is the base output function. Most other functions call it. The last argument is the text. The arguments before it are style tokens: `-n`, `bold`, `italic`, `underline`, color names, or `0`–`255`. `repen`, `check`, `warn`, `throw`, and `spin` pass their arguments directly to `pen`.
- Symbols and spinner frames are `readonly` globals in `00.utils/_symbols.sh` (`_q`, `_a`, `_mark`, `_spinner`, ...). Callers use `${_mark:-✓}` fallbacks, so each file works without the symbols file.
- `00.utils/movements.sh` contains the ANSI cursor helpers (`up`, `bol`, `cl`, `upclear`, `line`, `show_cursor`, `hide_cursor`).
- Spinner state: `spin` starts a background subshell and stores its PID in the global `_spinner_pid`. `spop` stops it with `USR1`. `spinning` checks for the PID. `check`, `warn`, and `throw` stop an active spinner and overwrite its line (`spop` + `upclear`). This works only if the spinner line is the last output.
- Cursor state: each function sets the cursor to the state that it needs, and does not restore the previous state. `spin` and `choose` hide the cursor. `seek`, `request`, and `confirm` show it. `spop` shows it, but not with `--keep-cursor-hidden`. Thus, the cursor state after a function is the state that the function needs. Do not add code that restores the cursor when a function returns. Do not change the default of `spop` (this is a breaking change).
- Traps: `hide_cursor` calls `_beddu_set_traps` (`00.utils/movements.sh`). It sets `EXIT`, `INT`, and `TERM` traps, which stay until the script stops. The trap (`_beddu_on_signal`) runs the trap of the caller for that signal. On `EXIT`, it first stops the spinner and shows the cursor. On `INT` and `TERM`, it does not clean up, because each exit runs the `EXIT` trap. If the caller has no `INT` or `TERM` trap, the script stops with the signal (`kill -INT $BASHPID`), not with `exit 130`. Then a parent process (a loop, `make`, `xargs`) also stops. Sourcing beddu sets no traps, and a script that does not hide the cursor gets no traps.
- Trap rules for new code: to hide the cursor, call `hide_cursor` in the main shell, not in a subshell (`spin` calls it before it starts the background shell). Do not set `EXIT`, `INT`, or `TERM` traps in other functions. A caller trap must always run.
- Functions that return values (`seek`, `request`, `choose`, `run --out/--err`) write to a variable name from the caller through `local -n` namerefs. `confirm` returns its result as the exit status.
- `spop` and `run` save `$-`, set `set +e`, and restore `errexit` at the end. Use the same method in new code that must not exit under `set -e`.

## Style

`.editorconfig`: 4-space indentation for `*.sh`. Each public function has a header comment with `Usage:`, `Options:`, and `Examples:` sections. When you add or change a public function, also update the "Function Reference" section in `README.md`.
