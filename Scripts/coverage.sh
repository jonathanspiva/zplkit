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
# exercise anything. Coverage catches the same failure far more meaningfully,
# and it measures something worth caring about on its own.
#
# It only catches it because the check below iterates THIS list of floors, not
# the modules llvm-cov reports. A module's coverage does not sink toward zero
# when its test target stops running: a module linked only by that target (which
# is true of ZPLKitPrinter) drops out of the report altogether, and a loop over
# the report would sail past it. A module named here and missing from the report
# is a hard failure.
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
# Pick the NEWEST profile, not an arbitrary one. Both build-system layouts can
# coexist under .build (.build/<triple>/<config> and .build/out/Products/<config>),
# so "first found" could silently report stale numbers from an older run.
PROF="$(find .build -name 'default.profdata' -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -1)"
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

# Bash 3.2 (macOS /bin/bash) treats "${arr[@]}" on an EMPTY array as an unbound
# variable under `set -u`, so both expansions below are guarded. This matters
# because the number of test binaries depends on the build system: swiftbuild
# emits one .xctest per test target, the native build system emits a single
# <Package>PackageTests.xctest. With one binary there are no extra -object args.
OBJ_ARGS=()
if [ ${#BINS[@]} -gt 1 ]; then
    for b in "${BINS[@]:1}"; do OBJ_ARGS+=(-object "$b"); done
fi

# --- collect the per-file summaries -----------------------------------------
# `export -summary-only`, not `report`, deliberately. The text report strips the
# longest common path prefix from its filename column, so the module name is
# only in there by luck: over the whole suite the rows read
# "ZPLKit/Elements/Aztec.swift", but over a single test target they read
# "Aztec.swift" and every module silently becomes unrecognised. The JSON carries
# absolute paths, which cannot be misread.
REPORT="$(mktemp)"
"${COV[@]}" export -summary-only "${BINS[0]}" ${OBJ_ARGS[@]+"${OBJ_ARGS[@]}"} \
    -instr-profile="$PROF" \
    -ignore-filename-regex='(Tests|\.build|Tools)/' 2>/dev/null > "$REPORT"

if [ ! -s "$REPORT" ]; then
    echo "error: llvm-cov produced no report" >&2; exit 1
fi

# --- aggregate per module ---------------------------------------------------
# The export is one long line. Put each file record on its own line first, so
# the parser can stay line-oriented: a multi-character RS is not portable across
# the awks in play (BSD awk on macOS, mawk in the Swift Linux images).
#
# Each record:
#   {"filename":"<abs>/Sources/<Module>/<...>.swift","summary":{...
#     "lines":{"count":N,"covered":M,...} ... "regions":{"count":N,"covered":M,...}}}
RECORDS="$(mktemp)"
awk '{ gsub(/\{"filename":/, "\n&"); print }' "$REPORT" > "$RECORDS"

SUMMARY="$(awk '
    # Pull "<key>":{"count":N,"covered":M out of a record. Returns "N M".
    function counts(rec, key,   s, n, a) {
        if (!match(rec, "\"" key "\":\\{\"count\":[0-9]+,\"covered\":[0-9]+"))
            return ""
        s = substr(rec, RSTART, RLENGTH)
        n = split(s, a, /[^0-9]+/)
        return a[n - 1] " " a[n]
    }
    /^\{"filename":"/ {
        rest = substr($0, length("{\"filename\":\"") + 1)
        fn = substr(rest, 1, index(rest, "\"") - 1)

        # The module is the path component under the LAST "Sources/".
        p = fn
        if (match(p, /.*\/Sources\//)) p = substr(p, RSTART + RLENGTH)
        mod = p
        sub(/\/.*/, "", mod)
        if (mod == "" || mod == fn) next

        split(counts($0, "lines"), l, " ")
        split(counts($0, "regions"), r, " ")
        lt[mod] += l[1]; lc[mod] += l[2]
        rt[mod] += r[1]; rc[mod] += r[2]
        seen[mod] = 1
    }
    END {
        for (m in seen) {
            lp = lt[m] > 0 ? lc[m] / lt[m] * 100 : 0
            rp = rt[m] > 0 ? rc[m] / rt[m] * 100 : 0
            printf "%s %.2f %.2f %d %d %d %d\n", m, lp, rp, lc[m], lt[m], rc[m], rt[m]
        }
    }
' "$RECORDS" | sort)"

if [ -z "$SUMMARY" ]; then
    echo "error: no module could be read out of the coverage report" >&2
    echo "       (expected source paths under Sources/<Module>/)" >&2
    exit 1
fi

echo ""
printf "%-18s %10s %12s   %s\n" "module" "line cov" "region cov" "covered/total"
printf -- "---------------------------------------------------------------\n"

# --- enforce ----------------------------------------------------------------
# Iterate FLOORS, NOT the modules llvm-cov happened to report. A module linked
# only by its own test bundle (ZPLKitPrinter) does not sink toward zero when
# that bundle stops running: it disappears from the report entirely. A loop over
# the report would then find nothing to complain about and pass, which is
# exactly the failure this gate exists to catch.
fail=0
checked=""
while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    mod="${entry%%:*}"
    floor="${entry#*:}"
    checked="$checked $mod"

    row="$(echo "$SUMMARY" | awk -v m="$mod" '$1 == m {print; exit}')"
    if [ -z "$row" ]; then
        printf "%-18s %9s  %10s   %s\n" "$mod" "-" "-" "  MISSING from the coverage report"
        fail=1
        continue
    fi

    set -- $row
    line="$2"; region="$3"; covered="$4"; total="$5"
    below="$(awk -v a="$line" -v b="$floor" 'BEGIN{print (a<b) ? 1 : 0}')"
    if [ "$below" = "1" ]; then
        status="  BELOW FLOOR ($floor%)"
        fail=1
    else
        status="  (floor $floor%)"
    fi
    printf "%-18s %9s%% %11s%%   %s/%s%s\n" "$mod" "$line" "$region" "$covered" "$total" "$status"
done <<< "$FLOORS"

# Anything covered but without a floor: reported, never enforced. A new module
# shows up here until someone sets its floor.
while read -r mod line region covered total rcovered rtotal; do
    [ -z "$mod" ] && continue
    case " $checked " in
        *" $mod "*) continue ;;
    esac
    printf "%-18s %9s%% %11s%%   %s/%s%s\n" "$mod" "$line" "$region" "$covered" "$total" "  (no floor set)"
done <<< "$SUMMARY"

printf -- "---------------------------------------------------------------\n"
echo "$SUMMARY" | awk '
    { lc += $4; lt += $5; rc += $6; rt += $7 }
    END {
        printf "%-18s %9.2f%% %11.2f%%\n", "TOTAL",
            (lt > 0 ? lc / lt * 100 : 0), (rt > 0 ? rc / rt * 100 : 0)
    }'
echo ""

if [ "$REPORT_ONLY" = "1" ]; then
    echo "(--report: floors not enforced)"
    exit 0
fi

if [ "$fail" = "1" ]; then
    echo "::error::A module is below its coverage floor, or missing from the report entirely. A missing module means its test target did not run (or the module was renamed). Add tests, restore the target, or change the floor in Scripts/coverage.sh deliberately and say why."
    exit 1
fi

echo "All modules with floors are at or above them."
