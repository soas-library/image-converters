#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────┐
# │  JP2 → JPG Converter                                 │
# │  Convert JP2 images → JPG (configurable quality)     │
# │  Non-JP2 files are ignored                           │
# │                                                      │
# │  Idempotent — skips files where output is newer      │
# │  than source, like make would.                       │
# │                                                      │
# │  Usage:  ./jp2-to-jpg.sh [-j N] [-q N] <SRC> <DST>   │
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
    echo "Usage: $0 [-j N] [-q N] [-h] <SRC_DIR> <DST_DIR>"
    echo ""
    echo "  SRC_DIR   Path to the source directory containing JP2 files"
    echo "  DST_DIR   Path to the output directory for JPG files"
    echo ""
    echo "Options:"
    echo "  -j N   Parallel jobs (default: number of CPU cores)"
    echo "  -q N   JPEG quality 1-100 (default: 95)"
    echo "  -h     Show this help"
    echo ""
    echo "Converts JP2 images to JPG. Non-JP2 files are ignored."
    echo "Idempotent: skips files where the output is newer than the source."
    exit 1
}

# ── Options ──────────────────────────────────────────────

JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
QUALITY=95

while getopts ":j:q:h" opt; do
    case $opt in
        j) JOBS="$OPTARG" ;;
        q) QUALITY="$OPTARG" ;;
        h) usage ;;
        :) echo "Error: -$OPTARG requires an argument" >&2; exit 1 ;;
        *) echo "Error: unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 1 ] || [ "$QUALITY" -gt 100 ]; then
    echo "Error: quality must be 1-100, got: $QUALITY" >&2
    exit 1
fi

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
echo "Quality: $QUALITY"
echo ""

while IFS= read -r -d '' file; do
    relative="${file#"$SRC_DIR"/}"

    # Strip .jp2 extension (case-insensitive), replace with .jpg
    base="${relative%.[jJ][pP]2}"
    out_file="$DST_DIR/${base}.jpg"

    if needs_update "$file" "$out_file"; then
        TO_CONVERT+=("$file")
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$SRC_DIR" -type f -iname '*.jp2' -not -path '*/.git/*' -not -name '.DS_Store' -print0)

# ── Convert in parallel ─────────────────────────────────

convert_one() {
    local file="$1"
    local relative="${file#"$SRC_DIR"/}"
    local base="${relative%.[jJ][pP]2}"
    local out_file="$DST_DIR/${base}.jpg"
    mkdir -p "$(dirname "$out_file")"
    magick "$file" -quality "$QUALITY" "$out_file"
    echo "  CONVERT  $relative"
}
export -f convert_one
export SRC_DIR DST_DIR QUALITY

CONVERTED=0
if [ ${#TO_CONVERT[@]} -gt 0 ]; then
    printf '%s\0' "${TO_CONVERT[@]}" | xargs -0 -P"$JOBS" -I{} bash -c 'convert_one "$@"' _ {}
    CONVERTED=${#TO_CONVERT[@]}
fi

# ── Summary ────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Converted: $CONVERTED JP2 → JPG"
echo "  Skipped:   $SKIPPED (up to date)"
echo "  Quality:   $QUALITY"
echo "  Jobs:      $JOBS"
echo "────────────────────────────────"
echo ""
