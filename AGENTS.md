# AGENTS.md

## Tests

- Add one or more tests for each new feature and for each bug fix.
- Put the tests in `test/run.sh`. Each test is a function. The name of the function starts with `test_`.
- Run the tests with `make test`. To use a different bash, set `BASH_BIN` (for example, `make test BASH_BIN=/bin/bash`).
- Make sure that the tests and the source work with bash 3.2 (the default on macOS) and with bash 5.
