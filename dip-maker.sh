#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────┐
# │  DIP Maker:                                          │
# │  Convert images for an OAIS Dissemination Package.   │
# │  JP2 images → JPG (quality 95)                       │
# │  Non-JP2 files are ignored                           │
# │                                                      │
# │  Idempotent — skips files where output is newer      │
# │  than source, like make would.                       │
# │                                                      │
# │  Usage:  ./dip-maker.sh <SIP_DIR> <DIP_DIR>          │
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
    echo "Usage: $0 <SIP_DIR> <DIP_DIR>"
    echo ""
    echo "  SIP_DIR   Path to the source OAIS SIP directory"
    echo "  DIP_DIR   Path to the output OAIS DIP directory"
    echo ""
    echo "Converts JP2 images to JPG (quality 100). Non-JP2 files are ignored."
    echo "Idempotent: skips files where the output is newer than the source."
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

SIP_DIR="$1"
DIP_DIR="$2"

if [ ! -d "$SIP_DIR" ]; then
    echo "Error: SIP directory does not exist: $SIP_DIR" >&2
    exit 1
fi

# Resolve to absolute paths for safety
SIP_DIR="$(cd "$SIP_DIR" && pwd)"
DIP_DIR="$(mkdir -p "$DIP_DIR" && cd "$DIP_DIR" && pwd)"

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
echo "SIP: $SIP_DIR"
echo "DIP: $DIP_DIR"
echo ""

while IFS= read -r -d '' file; do
    relative="${file#"$SIP_DIR"/}"

    # Strip .jp2 extension (case-insensitive), replace with .jpg
    base="${relative%.[jJ][pP]2}"
    out_file="$DIP_DIR/${base}.jpg"

    if needs_update "$file" "$out_file"; then
        mkdir -p "$(dirname "$out_file")"
        magick "$file" -quality 95 "$out_file"
        echo "  CONVERT  $relative"
        CONVERTED=$((CONVERTED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(find "$SIP_DIR" -type f \( -iname '*.jp2' \) -not -path '*/.git/*' -not -name '.DS_Store' -print0)

# ── Summary ────────────────────────────────────────────

echo ""
echo "────────────────────────────────"
echo "  Converted: $CONVERTED JP2 → JPG"
echo "  Skipped:   $SKIPPED (up to date)"
echo "────────────────────────────────"
echo ""
