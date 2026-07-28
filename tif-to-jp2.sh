#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────┐
# │  TIF → JP2 Converter                                 │
# │  Convert TIFF images → JP2 (lossless)                │
# │  Non-TIFF files are ignored                          │
# │                                                      │
# │  Idempotent — skips files where output is newer      │
# │  than source, like make would.                       │
# │                                                      │
# │  Usage:  ./tif-to-jp2.sh <SRC_DIR> <DST_DIR>         │
# │                                                      │
# │  Requires: ImageMagick (magick)                      │
# │                                                      │
# │  Created: July 2026                                  │
# │  Origin:  Human + Claude, iteratively developed      │
# │  License: CC0                                        │
# └──────────────────────────────────────────────────────┘

set -euo pipefail

# ── Usage ──────────────────────────────────────────────

usage() {
    echo "Usage: $0 <SRC_DIR> <DST_DIR>"
    echo ""
    echo "  SRC_DIR   Path to the source directory containing TIFF files"
    echo "  DST_DIR   Path to the output directory for JP2 files"
    echo ""
    echo "Converts TIFF images to JP2 (lossless). Non-TIFF files are ignored."
    echo "Idempotent: skips files where the output is newer than the source."
    exit 1
}

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

# ── Counters ───────────────────────────────────────────

CONVERTED=0
SKIPPED=0

# ── Process files ──────────────────────────────────────

echo ""
echo "SRC: $SRC_DIR"
echo "DST: $DST_DIR"
echo ""

while IFS= read -r -d '' file; do
    relative="${file#"$SRC_DIR"/}"

    # Strip .tif/.tiff extension (case-insensitive), replace with .jp2
    base="${relative%.[tT][iI][fF]}"
    base="${base%.[tT][iI][fF][fF]}"
    out_file="$DST_DIR/${base}.jp2"

    if needs_update "$file" "$out_file"; then
        mkdir -p "$(dirname "$out_file")"
        magick "$file" -quality 0 "$out_file"
        echo "  CONVERT  $relative"
        CONVERTED=$((CONVERTED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$SRC_DIR" -type f \( -iname '*.tif' -o -iname '*.tiff' \) -not -path '*/.git/*' -not -name '.DS_Store' -print0)

# ── Summary ────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Converted: $CONVERTED TIF → JP2"
echo "  Skipped:   $SKIPPED (up to date)"
echo "────────────────────────────────"
echo ""
