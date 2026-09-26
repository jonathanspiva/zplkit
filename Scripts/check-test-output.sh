#!/usr/bin/env bash
# Checks a captured `swift test` log, because `swift test`'s exit code proves
# nothing on its own.
#
#   Scripts/check-test-output.sh <log> [min-tests]
#
# Fails when:
#   * any target reported failures. A bundle that fails to dlopen
#     Testing.framework (seen with only the Command Line Tools selected)
#     reports failures and `swift test` STILL exits 0. That is a real bug, and
#     this grep is what catches it.
#   * the total is zero, or below <min-tests> when one is given.
#
# The total is SUMMED over every "Test run with N tests" line. SwiftPM's
# default build system (swiftbuild) prints one summary per test target, so
# `tail -1` reads only the last target. That misreading is what once looked
# like a toolchain running part of the suite; nothing was ever skipped.
set -euo pipefail

log="${1:?usage: $0 <log> [min-tests]}"
min="${2:-1}"

if grep -q 'Some test targets reported failures' "$log"; then
  echo "::error::A test target reported failures ('swift test' still exited 0)"
  exit 1
fi

total="$(grep -oE 'Test run with [0-9]+ test' "$log" | grep -oE '[0-9]+' | awk '{s+=$1} END {print s+0}' || true)"
if [ -z "$total" ] || [ "$total" = "0" ]; then
  echo "::error::Could not determine the test count from 'swift test' output"
  exit 1
fi
echo "Total tests run: $total"

if [ "$total" -lt "$min" ]; then
  echo "::error::Only $total tests ran; expected at least $min"
  exit 1
fi
