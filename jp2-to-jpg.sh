#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────┐
# │  JP2 → JPG Converter                                 │
# │  Convert JP2 images → JPG (quality 95)               │
# │  Non-JP2 files are ignored                           │
# │                                                      │
# │  Idempotent — skips files where output is newer      │
# │  than source, like make would.                       │
# │                                                      │
# │  Usage:  ./jp2-to-jpg.sh <SRC_DIR> <DST_DIR>         │
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
    echo "Usage: $0 <SRC_DIR> <DST_DIR>"
    echo ""
    echo "  SRC_DIR   Path to the source directory containing JP2 files"
    echo "  DST_DIR   Path to the output directory for JPG files"
    echo ""
    echo "Converts JP2 images to JPG (quality 95). Non-JP2 files are ignored."
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

    # Strip .jp2 extension (case-insensitive), replace with .jpg
    base="${relative%.[jJ][pP]2}"
    out_file="$DST_DIR/${base}.jpg"

    if needs_update "$file" "$out_file"; then
        mkdir -p "$(dirname "$out_file")"
        magick "$file" -quality 95 "$out_file"
        echo "  CONVERT  $relative"
        CONVERTED=$((CONVERTED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$SRC_DIR" -type f -iname '*.jp2' -not -path '*/.git/*' -not -name '.DS_Store' -print0)

# ── Summary ────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Converted: $CONVERTED JP2 → JPG"
echo "  Skipped:   $SKIPPED (up to date)"
echo "────────────────────────────────"
echo ""
