# image-converters

Image format converters for a digitisation pipeline. Each script converts between two formats, preserving directory structure. All are idempotent — safe to re-run.

```
TIFF (scan) ──→ JP2 (master) ──→ JPG (dissemination)
                    └──→ TIFF (client export)
```

## Scripts

| Script | From | To | Use case |
|--------|------|----|----------|
| `tif-to-jp2.sh` | TIFF | JP2 (lossless) | Create preservation masters from scans |
| `jp2-to-jpg.sh` | JP2 | JPG (quality 95) | Create access/dissemination copies |
| `jp2-to-tif.sh` | JP2 | TIFF (LZW) | Export high-res masters for clients |

## Usage

All scripts take the same arguments:

```bash
./tif-to-jp2.sh <SRC_DIR> <DST_DIR>
./jp2-to-jpg.sh <SRC_DIR> <DST_DIR>
./jp2-to-tif.sh <SRC_DIR> <DST_DIR>
```

- **SRC_DIR** — directory containing source images
- **DST_DIR** — output directory (created if it doesn't exist)

Source directory is never modified. Directory structure is mirrored in output.

### Example

```bash
# Full pipeline: scan TIFFs → master JP2s → access JPGs
./tif-to-jp2.sh /scans/2024-batch-01 /archive/masters/2024-batch-01
./jp2-to-jpg.sh /archive/masters/2024-batch-01 /access/2024-batch-01
```

## Idempotent / replayable

Each script compares source and destination timestamps. If the output file already exists and is newer than the source, it's skipped.

- **First run** — converts all files
- **Re-run with no changes** — does nothing (all skipped)
- **Re-run after source update** — only reconverts changed files

## Requirements

- [ImageMagick](https://imagemagick.org/) (`magick` command) with JP2 (JPEG 2000) support
- Bash 4+ and standard coreutils (`find`, `mkdir`)

### macOS (Homebrew)

The standard `brew install imagemagick` formula does **not** include JP2 support. Use the full variant instead:

```bash
brew install imagemagick-full
brew link --force imagemagick-full
```

### Windows

The [standard Windows installer](https://imagemagick.org/script/download.php) includes JP2 support by default.

## Limitations

- JPEG is lossy even at quality 95. For lossless preservation, keep the original JP2s.
- Does not parallelise conversions. For large batches, consider wrapping with `xargs -P` or GNU `parallel`.
- Does not remove files from output that no longer exist in source. Delete the output dir and re-run for a clean slate.

## License

CC0 — dedicated to the public domain.

## Origin

Human + Claude, iteratively developed, 2026.
