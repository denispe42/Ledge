#!/bin/zsh
# Lint + unit tests. Run before every "done". Exit code 0 = all green.
cd "${0:A:h}/.."
./tools/lint-rules.sh && swift build 2>&1 | tail -3 && swift test 2>&1 | tail -5
