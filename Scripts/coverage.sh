#!/bin/bash
#
# Per-module code-coverage floors for ZPLKit.
#
# Usage:
#   swift test --enable-code-coverage
#   Scripts/coverage.sh            # report + enforce floors
#   Scripts/coverage.sh --report   # report only, never fails
#
# WHY FLOORS PER MODULE, AND NOT A TEST COUNT
#
# CI used to assert a total test count to catch a test target that silently
# stopped running. That is a weak proxy: it says tests EXECUTED, not that they
# exercise anything. Coverage catches the same failure far more meaningfully --
# if a target stops running, its module's coverage collapses toward zero -- and
# it measures something worth caring about on its own.
#
# The floors are a RATCHET: each is the value measured when it was last raised.
# Coverage may rise freely; a drop below the floor fails. Raise a floor
# deliberately when you want to lock in an improvement. Do NOT lower one to make
# CI pass without saying why in the commit message.
#
# Line coverage is the gate. Region coverage is reported because it is the
# stricter number and useful to watch, but it is noisier across toolchains, so
# it is not enforced.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

REPORT_ONLY=0
[ "${1:-}" = "--report" ] && REPORT_ONLY=1

# module:minimum-line-coverage
FLOORS="
ZPLKit:88.0
ZPLKitRenderer:87.0
ZPLKitPrinter:79.0
ZPLKitVerifier:95.0
"

# --- locate llvm-cov -------------------------------------------------------
if command -v xcrun >/dev/null 2>&1; then
    COV=(xcrun llvm-cov)
elif command -v llvm-cov >/dev/null 2>&1; then
    COV=(llvm-cov)
else
    echo "error: llvm-cov not found" >&2; exit 1
fi

# --- locate the profile ----------------------------------------------------
# The path moved with the build system: swiftbuild writes under
# .build/out/Products/<config>/codecov, the native system under
# .build/<triple>/<config>/codecov. Probe rather than assume.
PROF="$(find .build -name 'default.profdata' -print 2>/dev/null | head -1)"
if [ -z "$PROF" ]; then
    echo "error: no default.profdata found. Run: swift test --enable-code-coverage" >&2
    exit 1
fi

# --- locate the test binaries ----------------------------------------------
# Search ONLY the products directory that owns this profile. Both build-system
# layouts can be present under .build at once (swiftbuild writes
# .build/out/Products/<config>, the native system .build/<triple>/<config>), and
# mixing binaries from one with a profile from the other makes llvm-cov emit
# nothing at all. The profile lives at <products>/codecov/default.profdata.
PRODUCTS="$(dirname "$(dirname "$PROF")")"

BINS=()
while IFS= read -r t; do
    [ -z "$t" ] && continue
    n="$(basename "$t" .xctest)"
    if [ -f "$t/Contents/MacOS/$n" ]; then
        BINS+=("$t/Contents/MacOS/$n")   # Apple: bundle
    elif [ -f "$t" ]; then
        BINS+=("$t")                      # Linux: bare executable
    fi
done < <(find "$PRODUCTS" -maxdepth 2 -name '*.xctest' -print 2>/dev/null)

# Linux SwiftPM emits a single <Package>PackageTests.xctest executable.
if [ ${#BINS[@]} -eq 0 ]; then
    while IFS= read -r t; do
        [ -n "$t" ] && BINS+=("$t")
    done < <(find "$PRODUCTS" -maxdepth 2 -name '*PackageTests*' -type f -perm -u+x 2>/dev/null)
fi

if [ ${#BINS[@]} -eq 0 ]; then
    echo "error: no test binaries found under .build" >&2; exit 1
fi

OBJ_ARGS=()
for b in "${BINS[@]:1}"; do OBJ_ARGS+=(-object "$b"); done

REPORT="$(mktemp)"
"${COV[@]}" report "${BINS[0]}" "${OBJ_ARGS[@]}" \
    -instr-profile="$PROF" \
    -ignore-filename-regex='(Tests|\.build|Tools)/' 2>/dev/null > "$REPORT"

if [ ! -s "$REPORT" ]; then
    echo "error: llvm-cov produced no report" >&2; exit 1
fi

# --- aggregate per module ---------------------------------------------------
# llvm-cov report columns:
#   1 filename, 2 regions, 3 missed regions, 4 cover%,
#   5 functions, 6 missed functions, 7 executed%,
#   8 lines, 9 missed lines, 10 cover%
echo ""
printf "%-18s %10s %12s   %s\n" "module" "line cov" "region cov" "covered/total"
printf -- "---------------------------------------------------------------\n"

SUMMARY="$(awk '
    NF>=10 && $1 ~ /\// {
        mod=$1; sub(/\/.*/,"",mod)
        lt[mod]+=$8; lm[mod]+=$9; rt[mod]+=$2; rm[mod]+=$3
    }
    END {
        for (m in lt)
            printf "%s %.2f %.2f %d %d\n", m, (lt[m]-lm[m])/lt[m]*100, (rt[m]-rm[m])/rt[m]*100, lt[m]-lm[m], lt[m]
    }
' "$REPORT" | sort)"

fail=0
while read -r mod line region covered total; do
    [ -z "$mod" ] && continue
    floor="$(echo "$FLOORS" | awk -F: -v m="$mod" '$1==m {print $2}')"
    status=""
    if [ -n "$floor" ]; then
        below="$(awk -v a="$line" -v b="$floor" 'BEGIN{print (a<b) ? 1 : 0}')"
        if [ "$below" = "1" ]; then
            status="  BELOW FLOOR ($floor%)"
            fail=1
        else
            status="  (floor $floor%)"
        fi
    else
        status="  (no floor set)"
    fi
    printf "%-18s %9s%% %11s%%   %s/%s%s\n" "$mod" "$line" "$region" "$covered" "$total" "$status"
done <<< "$SUMMARY"

printf -- "---------------------------------------------------------------\n"
tail -1 "$REPORT" | awk '{printf "%-18s %9s %11s\n", "TOTAL", $10, $4}'
echo ""

if [ "$REPORT_ONLY" = "1" ]; then
    echo "(--report: floors not enforced)"
    exit 0
fi

if [ "$fail" = "1" ]; then
    echo "::error::Code coverage dropped below a module floor. Either add tests, or raise/lower the floor in Scripts/coverage.sh deliberately and say why."
    exit 1
fi

echo "All modules at or above their coverage floors."
