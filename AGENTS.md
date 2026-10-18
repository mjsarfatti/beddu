# AGENTS.md

## Tests

- Add one or more tests for each new feature and for each bug fix.
- Put the tests in `test/run.sh`. Each test is a function. The name of the function starts with `test_`.
- Run the tests with `make test`. To use a different bash, set `BASH_BIN`.
- beddu needs bash 4 or later. Do not use bash 5 features. On macOS, `/bin/bash` is bash 3.2, so use `make test BASH_BIN=$(brew --prefix)/bin/bash`.
