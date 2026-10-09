#!/bin/zsh
# Exports every base (each size, labeled 1–4 and blank) and the slot test piece to stl/, as binary STL.
# The exports run in parallel, because the rounded body is slow to render.
set -euo pipefail

openscad="${OPENSCAD:-/Applications/OpenSCAD-2021.01.app/Contents/MacOS/OpenSCAD}"
cd "${0:A:h}"
mkdir -p stl

export_stl() {
    local output="$1"; shift
    "$openscad" "$@" -o "$output" 2>/dev/null
    [[ -s "$output" ]] || { echo "export failed: $output is empty" >&2; return 1; }
    ./stl_to_binary.py "$output"
    echo "exported $output"
}

pids=()
for size in medium large huge gargantuan; do
    for label in 1 2 3 4 ""; do
        name=${label:-blank}
        export_stl "stl/pawn-base-$size-$name.stl" -D "size=\"$size\"" -D "label=\"$label\"" pawn_base.scad &
        pids+=($!)
    done
done
export_stl stl/slot-test.stl slot_test.scad &
pids+=($!)

failures=0
for pid in $pids; do
    wait $pid || failures=$((failures + 1))
done
(( failures == 0 )) || { echo "$failures exports failed" >&2; exit 1; }
