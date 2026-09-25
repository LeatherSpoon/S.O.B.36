# Private scan inventory

Run from the repository root with Python 3.10 or newer. Install the pinned image-header reader once:

```powershell
python -m pip install -r requirements.txt
```

The tool only reads source files. It does not run OCR, extract game text, rename, move, recompress, crop, or write source scans. It has no network client and uploads nothing. Reading an online-only OneDrive placeholder may cause Windows/OneDrive to download it; unavailable files become errors and can be retried.

## Exact invocation

Choose the private library through the environment:

```powershell
$env:SOB_SOURCE_ROOT = 'C:\Users\Owner\OneDrive\Games\S.O.B'
python -m tools.scan_inventory --output .local/scan_manifest.json
```

Or specify it for one invocation:

```powershell
python -m tools.scan_inventory --source 'C:\Users\Owner\OneDrive\Games\S.O.B' --output .local/scan_manifest.json
```

Optional local configuration is a UTF-8 JSON file such as `.local/scan_config.json`:

```json
{"source_root": "C:/Users/Owner/OneDrive/Games/S.O.B"}
```

```powershell
python -m tools.scan_inventory --config .local/scan_config.json --output .local/scan_manifest.json
```

Precedence is explicit `--source`, then `SOB_SOURCE_ROOT`, then `--config`. Relative paths in configuration resolve relative to that configuration file. There is no hard-coded source path in application code.

Both output files are private: `.local/scan_manifest.json` and `.local/scan_manifest.json.checkpoint.sqlite3`. The repository ignores `.local/`. Keep custom output/checkpoint paths in that directory or another private, ignored location; filenames and hashes can reveal details about a collection and must not be committed. `--checkpoint .local/another.sqlite3` overrides the checkpoint path. The tool validates that every output, checkpoint, and SQLite sidecar stays outside the selected source tree before creating anything.

## Manifest contract

The UTF-8 JSON envelope contains `schema_version: 1`, `files`, and `scan_errors` for directory-level failures. File records contain:

| Field | Meaning |
| --- | --- |
| `relative_path` | Source-relative path with `/` separators |
| `extension` | Lowercase suffix including `.`; empty for no suffix |
| `dimensions` | `{ "width": n, "height": n }` for supported image headers; otherwise `null` |
| `byte_size` | File byte count; `null` when metadata cannot be read |
| `sha256` | SHA-256 of all file bytes, or `null` when hashing failed or the file changed during processing |
| `duplicate_group_id` | `sha256:<full hash>` when at least two current entries share the hash; otherwise `null` |
| `provisional_category` | Keyword inference from path/filename only: `rulebook`, `map_tile`, `hero`, `enemy`, `mission`, `encounter`, `threat`, `item`, or `unknown` |
| `confidence` | Always `imported` |
| `processing_status` | `complete`, `error`, or `skipped` |
| `errors` | Structured stage, exception type, and OS error number; no exception text or absolute paths |

No record is automatically marked `identified` or `verified`. Category inference may be wrong and does not authorize rules consumption. Verification belongs in a separate explicit content-review workflow; editing the checkpoint cannot promote inventory confidence.

Recognized image extensions are BMP, GIF, JPEG/JPG, PNG, TIFF/TIF, WebP, ICO, PPM, PGM, and PBM. Dimensions refer to the encoded first image/frame, without EXIF rotation or full pixel decoding. A successful header read is not a full image integrity check. Other files, including PDFs and archives, receive hashes and byte sizes with `null` dimensions. Corrupt supported-image headers produce a per-file error while preserving a successfully computed hash.

## Determinism and restart

Manifest records sort by exact relative path; JSON keys sort consistently. There are no wall-clock timestamps or machine-specific source roots in the manifest. Duplicate IDs derive from full hashes and are recomputed from the current traversal, so deleted files do not survive in output. Identical unchanged inputs produce byte-identical manifests.

Each hash is streamed in one-MiB chunks. Memory usage scales with metadata/entry count, not total scan bytes. A SQLite checkpoint commits each processed file independently. If interrupted with Ctrl+C, the old manifest remains intact and finished checkpoint entries survive. Repeat the same command to resume; the final manifest is written to a temporary file and atomically replaced only after traversal completes. Do not run multiple inventories using the same checkpoint at once.

Cache reuse requires matching source root, cache algorithm version, Pillow version, relative path, byte size, nanosecond modification/creation-change timestamps, filesystem device, and file identity. Errors are always retried. Replaced or changed files are rehashed; changes detected during a read produce `SourceChangedDuringRead` and no trusted hash. Metadata cannot prove unchanged bytes if someone deliberately preserves all metadata, or if a filesystem has insufficient timestamp precision. Force fresh reads after such changes:

```powershell
python -m tools.scan_inventory --output .local/scan_manifest.json --no-resume
```

The checkpoint is a local optimization, not authenticated evidence. It may retain metadata for removed files, but those entries are never emitted without a current filesystem entry. A corrupt or incompatible SQLite file fails safely; choose a new ignored checkpoint path to rebuild it. Confidence remains `imported` even on reuse.

## Path and error safety

The scanner does not follow symbolic links, directory junctions, or unknown reparse types. Windows Cloud Files tags (`IO_REPARSE_TAG_CLOUD` through `_F`) are allowed because they represent storage-provider placeholders rather than path redirection. The distinction follows [Microsoft's reparse tag model](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-tags). Linked/unsupported entries are recorded as skipped; their targets are not traversed. Source and output ancestors are checked as well. Existing output/checkpoint files with multiple hard links are rejected to prevent writes through aliases. Files open read-only, with no-follow support where the platform provides it, and identity is checked when opening.

Keep the source tree stable during a scan. These guards are intended for a local collection, not as a security boundary against another process actively swapping ancestor directories while the scanner runs. The operating system may update access-time or cloud hydration metadata on reads; the scanner never changes content or source names.

The command prints only aggregate counts. Exit status is `0` for traversal without file/directory errors, `1` when the manifest contains errors, `2` for configuration/output/checkpoint failure, and `130` for Ctrl+C. Skipped links are included in the aggregate and do not cause an error exit. Directory failures appear in `scan_errors`; unreadable files do not stop sibling processing.

## Tests and Python API

```powershell
python -m unittest discover -s tests -p test_scan_inventory.py -v
```

Synthetic tests cover unchanged source bytes/timestamps, byte-identical output, dimensions, duplicates and deletion, error isolation/retry, partial restart, cache invalidation, source binding, confidence preservation, source/output boundary checks, hard-link protection, Windows junctions, cloud tags, and source mutation during hashing. They contain no commercial material.

```python
from tools.scan_inventory.inventory import run_inventory

manifest = run_inventory(
    source_root,
    ".local/scan_manifest.json",
    checkpoint=".local/scan_manifest.json.checkpoint.sqlite3",
    resume=True,
)
```

The API returns the same envelope it saves. It raises configuration/output errors and `KeyboardInterrupt`; individual source failures are represented in the envelope.
