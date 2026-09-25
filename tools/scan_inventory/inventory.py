"""Inventory source files without modifying them or interpreting their contents."""

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import tempfile
import warnings

from PIL import Image, __version__ as PILLOW_VERSION


SCHEMA_VERSION = 1
CACHE_VERSION = "1:" + PILLOW_VERSION
CHUNK_SIZE = 1024 * 1024
IMAGE_EXTENSIONS = {".bmp", ".gif", ".jpeg", ".jpg", ".png", ".tif", ".tiff", ".webp", ".ico", ".ppm", ".pgm", ".pbm"}
CATEGORIES = (
    ("rulebook", {"rulebook", "rulebooks", "rules"}),
    ("map_tile", {"map", "maps", "tile", "tiles"}),
    ("hero", {"hero", "heroes", "character", "characters"}),
    ("enemy", {"enemy", "enemies", "monster", "monsters"}),
    ("mission", {"mission", "missions"}),
    ("encounter", {"encounter", "encounters"}),
    ("threat", {"threat", "threats"}),
    ("item", {"item", "items", "gear", "artifact", "artifacts"}),
)


def resolve_source(explicit=None, config=None):
    """Explicit source overrides environment, which overrides local JSON config."""
    source = explicit or os.environ.get("SOB_SOURCE_ROOT")
    if source:
        return Path(source).expanduser()
    if config:
        config_path = Path(config).expanduser()
        with config_path.open(encoding="utf-8") as stream:
            source = json.load(stream).get("source_root")
        if source:
            path = Path(source).expanduser()
            return path if path.is_absolute() else config_path.parent / path
    raise ValueError("Set SOB_SOURCE_ROOT, pass --source, or provide --config with source_root")


def is_link_or_reparse(path):
    """Reject redirection and unknown reparse types; allow Cloud Files placeholders."""
    info = Path(path).lstat()
    if stat.S_ISLNK(info.st_mode):
        return True
    if getattr(info, "st_file_attributes", 0) & 0x400:
        # IO_REPARSE_TAG_CLOUD through CLOUD_F are storage providers, not name
        # surrogates. Windows may hydrate them on read without redirecting paths.
        tag = getattr(info, "st_reparse_tag", 0)
        return tag & ~0x0000F000 != 0x9000001A
    return False


def _absolute_without_links(path):
    path = Path(os.path.abspath(Path(path).expanduser()))
    for component in (*reversed(path.parents), path):
        try:
            if is_link_or_reparse(component):
                raise ValueError("Paths must not traverse links, junctions, or unsupported reparse points")
        except FileNotFoundError:
            continue
    return path.resolve()


def _validate_destination(path, source):
    path = _absolute_without_links(path)
    if path == source or source in path.parents:
        raise ValueError("Manifest and checkpoint must be outside the source tree")
    if path.exists():
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError("Existing output must be a regular file with no hard links")
    return path


def _fingerprint(info):
    return [info.st_size, info.st_mtime_ns, info.st_ctime_ns, info.st_dev, info.st_ino]


def _error(stage, exc):
    # Exception strings can contain private absolute paths or OS-dependent prose.
    return {"stage": stage, "type": type(exc).__name__, "errno": getattr(exc, "errno", None)}


def _open_readonly(path):
    _absolute_without_links(path)
    before = Path(path).lstat()
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0))
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or (info.st_dev, info.st_ino) != (before.st_dev, before.st_ino) or is_link_or_reparse(path):
            raise ValueError("Refusing a non-regular source file")
        return os.fdopen(descriptor, "rb")
    except BaseException:
        os.close(descriptor)
        raise


def hash_file(path):
    """Read at most one MiB per chunk; never load a full scan into memory."""
    digest = hashlib.sha256()
    with _open_readonly(path) as stream:
        for chunk in iter(lambda: stream.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _category(relative_path):
    tokens = set(re.findall(r"[a-z]+", relative_path.lower()))
    for category, keywords in CATEGORIES:
        if tokens & keywords:
            return category
    return "unknown"


def _record(relative_path, info=None):
    return {
        "relative_path": relative_path,
        "extension": Path(relative_path).suffix.lower(),
        "dimensions": None,
        "byte_size": info.st_size if info else None,
        "sha256": None,
        "duplicate_group_id": None,
        "provisional_category": _category(relative_path),
        "confidence": "imported",
        "processing_status": "complete",
        "errors": [],
    }


def _walk(source, scan_errors):
    pending = [source]
    while pending:
        directory = pending.pop()
        try:
            # Recheck on entry so a directory replaced between visits is not followed.
            if is_link_or_reparse(directory):
                scan_errors.append({"relative_path": directory.relative_to(source).as_posix(), "stage": "list", "type": "LinkOrReparsePoint", "errno": None})
                continue
            with os.scandir(directory) as entries:
                paths = sorted((Path(entry.path) for entry in entries), key=lambda p: p.name)
        except (OSError, ValueError) as exc:
            scan_errors.append({"relative_path": directory.relative_to(source).as_posix(), **_error("list", exc)})
            continue
        for path in paths:
            relative = path.relative_to(source).as_posix()
            try:
                info = path.lstat()
                if is_link_or_reparse(path):
                    record = _record(relative, info)
                    record["processing_status"] = "skipped"
                    record["errors"] = [{"stage": "inspect", "type": "LinkOrReparsePoint", "errno": None}]
                    yield path, info, record
                elif stat.S_ISDIR(info.st_mode):
                    pending.append(path)
                elif stat.S_ISREG(info.st_mode):
                    yield path, info, None
                else:
                    record = _record(relative, info)
                    record["processing_status"] = "skipped"
                    record["errors"] = [{"stage": "inspect", "type": "NonRegularFile", "errno": None}]
                    yield path, info, record
            except (OSError, ValueError) as exc:
                record = _record(relative)
                record["processing_status"] = "error"
                record["errors"] = [_error("stat", exc)]
                yield path, None, record


def _inspect(path, relative, info):
    record = _record(relative, info)
    try:
        record["sha256"] = hash_file(path)
    except (OSError, ValueError) as exc:
        record["errors"].append(_error("hash", exc))
    if record["extension"] in IMAGE_EXTENSIONS and record["sha256"]:
        try:
            # Read image headers only. Do not decode, thumbnail, or rewrite pixels.
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with _open_readonly(path) as stream, Image.open(stream) as image:
                    record["dimensions"] = {"width": image.width, "height": image.height}
        except (OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
            record["errors"].append(_error("dimensions", exc))
    try:
        if is_link_or_reparse(path) or _fingerprint(path.lstat()) != _fingerprint(info):
            record["errors"].append({"stage": "stat", "type": "SourceChangedDuringRead", "errno": None})
            record["sha256"] = None
            record["dimensions"] = None
    except (OSError, ValueError) as exc:
        record["errors"].append(_error("stat", exc))
        record["sha256"] = None
        record["dimensions"] = None
    if record["errors"]:
        record["processing_status"] = "error"
    return record


def _cache(connection, source):
    connection.execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    connection.execute("CREATE TABLE IF NOT EXISTS entries (relative_path TEXT PRIMARY KEY, fingerprint TEXT NOT NULL, record TEXT NOT NULL)")
    expected = {"source": str(source), "version": CACHE_VERSION}
    if dict(connection.execute("SELECT key, value FROM metadata")) != expected:
        connection.execute("DELETE FROM entries")
        connection.execute("DELETE FROM metadata")
        connection.executemany("INSERT INTO metadata VALUES (?, ?)", expected.items())
    connection.commit()


def _cached_record(connection, relative, fingerprint):
    row = connection.execute("SELECT fingerprint, record FROM entries WHERE relative_path = ?", (relative,)).fetchone()
    if row and row[0] == json.dumps(fingerprint):
        try:
            record = json.loads(row[1])
            if set(record) == set(_record(relative)) and record["processing_status"] == "complete" and record["relative_path"] == relative:
                record["confidence"] = "imported"
                record["duplicate_group_id"] = None
                return record
        except (TypeError, ValueError):
            pass
    return None


def _write_manifest(output, source, manifest):
    _validate_destination(output, source)
    descriptor, temporary = tempfile.mkstemp(prefix=".scan-", suffix=".tmp", dir=output.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(manifest, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        _validate_destination(output, source)
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def run_inventory(source, output, *, checkpoint=None, resume=True):
    """Return and atomically save deterministic metadata; all writes stay outside source."""
    source = _absolute_without_links(source)
    if not source.is_dir():
        raise ValueError("Source must be an existing directory")
    output = _validate_destination(output, source)
    checkpoint = _validate_destination(checkpoint or str(output) + ".checkpoint.sqlite3", source)
    sidecars = [Path(str(checkpoint) + suffix) for suffix in ("-journal", "-wal", "-shm")]
    if output in [checkpoint, *sidecars]:
        raise ValueError("Manifest and checkpoint must have distinct paths")
    for sidecar in sidecars:
        _validate_destination(sidecar, source)
    # Every safety check occurs before any directory or checkpoint is created.
    output.parent.mkdir(parents=True, exist_ok=True)
    checkpoint.parent.mkdir(parents=True, exist_ok=True)
    records, scan_errors = [], []
    connection = sqlite3.connect(checkpoint)
    try:
        _cache(connection, source)
        for path, info, record in _walk(source, scan_errors):
            relative = path.relative_to(source).as_posix()
            if record is None:
                fingerprint = _fingerprint(info)
                record = _cached_record(connection, relative, fingerprint) if resume else None
                if record is None:
                    record = _inspect(path, relative, info)
                    connection.execute("INSERT OR REPLACE INTO entries VALUES (?, ?, ?)", (relative, json.dumps(fingerprint), json.dumps(record)))
                    # A committed row survives Ctrl+C; unfinished files are retried.
                    connection.commit()
            records.append(record)
    finally:
        connection.close()
    records.sort(key=lambda record: record["relative_path"])
    counts = Counter(record["sha256"] for record in records if record["sha256"])
    for record in records:
        record["duplicate_group_id"] = "sha256:" + record["sha256"] if record["sha256"] and counts[record["sha256"]] > 1 else None
    manifest = {"schema_version": SCHEMA_VERSION, "files": records, "scan_errors": sorted(scan_errors, key=lambda error: error["relative_path"])}
    _write_manifest(output, source, manifest)
    return manifest


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", help="Source root (or set SOB_SOURCE_ROOT)")
    parser.add_argument("--config", help="Optional local JSON containing source_root")
    parser.add_argument("--output", default=".local/scan_manifest.json")
    parser.add_argument("--checkpoint", help="Default: OUTPUT.checkpoint.sqlite3")
    parser.add_argument("--no-resume", action="store_true", help="Re-read and hash all files")
    args = parser.parse_args(argv)
    try:
        result = run_inventory(resolve_source(args.source, args.config), args.output, checkpoint=args.checkpoint, resume=not args.no_resume)
    except KeyboardInterrupt:
        print("Interrupted. Completed checkpoint entries are retained; rerun to resume.")
        return 130
    except (OSError, ValueError, sqlite3.Error) as exc:
        # Never print file names from private manifests or exceptions to shared logs.
        print("Inventory could not start or save: " + type(exc).__name__)
        return 2
    statuses = Counter(record["processing_status"] for record in result["files"])
    groups = {record["duplicate_group_id"] for record in result["files"] if record["duplicate_group_id"]}
    print(json.dumps({"entries": len(result["files"]), "complete": statuses["complete"], "errors": statuses["error"], "skipped": statuses["skipped"], "directory_errors": len(result["scan_errors"]), "duplicate_groups": len(groups)}, sort_keys=True))
    return 1 if statuses["error"] or result["scan_errors"] else 0
