# DIP Maker - OAIS SIP to DIP converter

Convert JP2 images to high-quality JPGs for access. Non-JP2 files are ignored. Idempotent — safe to re-run.

## Usage

```bash
./dip-maker.sh <SIP_DIR> <DIP_DIR>
```

- **SIP_DIR** — path to the source OAIS Submission Information Package
- **DIP_DIR** — path for the output OAIS Dissemination Information Package (created if it doesn't exist)

### Example

```bash
./dip-maker.sh /archive/sip/2024-batch-01 /access/dip/2024-batch-01
```

## What it does

1. Finds all JP2 files in the SIP directory (case-insensitive: `.jp2`, `.JP2`, etc.)
2. Converts each to JPG at quality 95
3. Non-JP2 files are ignored — only image conversion, nothing else
4. Directory structure from the SIP is mirrored in the DIP

The SIP is never modified.

## Idempotent / replayable

The script compares source and destination timestamps. If the output file already exists and is newer than the source, it's skipped. This means:

- **First run** — converts all JP2s
- **Re-run with no changes** — does nothing (all files skipped)
- **Re-run after SIP update** — only reconverts changed JP2s

Just like `make`, but without a Makefile.

## Requirements

- [ImageMagick](https://imagemagick.org/) (`magick` command) with JP2 (JPEG 2000) support
- Bash 4+ and standard coreutils (`find`, `cp`, `mkdir`)

### macOS (Homebrew)

The standard `brew install imagemagick` formula does **not** include JP2 support. Use the full variant instead:

```bash
brew install imagemagick-full
brew link --force imagemagick-full
```

### Windows

The [standard Windows installer](https://imagemagick.org/script/download.php) includes JP2 support by default.

## Excluded from processing

- `.git/` directories
- `.DS_Store` files

## Limitations

- JPEG is lossy even at quality 95. For lossless preservation, keep the original JP2s in your SIP/AIP.
- Does not parallelise conversions. For large batches, consider wrapping with `xargs -P` or GNU `parallel`.
- Does not remove files from the DIP that no longer exist in the SIP. Delete the DIP and re-run for a clean slate.

## License

CC0 — dedicated to the public domain.

## Origin

Human + Claude, iteratively developed, May 2026.
