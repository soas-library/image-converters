#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────┐
# │  JP2 → TIF Converter                                 │
# │  Convert JP2 images → TIFF (LZW compression)         │
# │  Non-JP2 files are ignored                           │
# │                                                      │
# │  Idempotent — skips files where output is newer      │
# │  than source, like make would.                       │
# │                                                      │
# │  Usage:  ./jp2-to-tif.sh [-j N] <SRC_DIR> <DST_DIR>  │
# │                                                      │
# │  Requires: ImageMagick (magick)                      │
# │                                                      │
# │  Created: May 2026                                   │
# │  Origin:  Human + Claude, iteratively developed      │
# │  License: CC0                                        │
# └──────────────────────────────────────────────────────┘

set -euo pipefail

# ── Usage ──────────────────────────────────────────────

usage() {
    echo "Usage: $0 [-j N] [-h] <SRC_DIR> <DST_DIR>"
    echo ""
    echo "  SRC_DIR   Path to the source directory containing JP2 files"
    echo "  DST_DIR   Path to the output directory for TIFF files"
    echo ""
    echo "Options:"
    echo "  -j N   Parallel jobs (default: number of CPU cores)"
    echo "  -h     Show this help"
    echo ""
    echo "Converts JP2 images to TIFF (LZW compression). Non-JP2 files are ignored."
    echo "Idempotent: skips files where the output is newer than the source."
    exit 1
}

# ── Options ──────────────────────────────────────────────

JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

while getopts ":j:h" opt; do
    case $opt in
        j) JOBS="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument" >&2; exit 1 ;;
        *) echo "Error: unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if [ $# -ne 2 ]; then
    usage
fi

SRC_DIR="$1"
DST_DIR="$2"

if [ ! -d "$SRC_DIR" ]; then
    echo "Error: source directory does not exist: $SRC_DIR" >&2
    exit 1
fi

# Resolve to absolute paths for safety
SRC_DIR="$(cd "$SRC_DIR" && pwd)"
DST_DIR="$(mkdir -p "$DST_DIR" && cd "$DST_DIR" && pwd)"

# ── Helpers ────────────────────────────────────────────

# Check if source is newer than destination (or dest doesn't exist)
needs_update() {
    local src="$1" dst="$2"
    [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]
}

# ── Collect files needing conversion ─────────────────────

TO_CONVERT=()
SKIPPED=0

echo ""
echo "SRC: $SRC_DIR"
echo "DST: $DST_DIR"
echo ""

while IFS= read -r -d '' file; do
    relative="${file#"$SRC_DIR"/}"

    # Strip .jp2 extension (case-insensitive), replace with .tif
    base="${relative%.[jJ][pP]2}"
    out_file="$DST_DIR/${base}.tif"

    if needs_update "$file" "$out_file"; then
        TO_CONVERT+=("$file")
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$SRC_DIR" -type f -iname '*.jp2' -not -path '*/.git/*' -not -name '.DS_Store' -print0)

# ── Convert in parallel ─────────────────────────────────

FAIL_LOG="$(mktemp)"
trap 'rm -f "$FAIL_LOG"' EXIT

convert_one() {
    local file="$1"
    local relative="${file#"$SRC_DIR"/}"
    local base="${relative%.[jJ][pP]2}"
    local out_file="$DST_DIR/${base}.tif"
    mkdir -p "$(dirname "$out_file")"
    if magick "$file" -compress LZW "$out_file" 2>&1; then
        echo "  CONVERT  $relative"
    else
        echo "  FAIL     $relative" >&2
        echo "$file" >> "$FAIL_LOG"
    fi
}
export -f convert_one
export SRC_DIR DST_DIR FAIL_LOG

CONVERTED=0
FAILED=0
if [ ${#TO_CONVERT[@]} -gt 0 ]; then
    printf '%s\0' "${TO_CONVERT[@]}" | xargs -0 -P"$JOBS" -I{} bash -c 'convert_one "$@"' _ {} || true
    FAILED=$(wc -l < "$FAIL_LOG" | tr -d ' ')
    CONVERTED=$(( ${#TO_CONVERT[@]} - FAILED ))
fi

# ── Summary ────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Converted: $CONVERTED JP2 → TIF"
echo "  Failed:    $FAILED"
echo "  Skipped:   $SKIPPED (up to date)"
echo "  Jobs:      $JOBS"
echo "────────────────────────────────"
echo ""

[ "$FAILED" -eq 0 ]
