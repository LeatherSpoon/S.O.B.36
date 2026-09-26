# Private visual library

The collection viewer and presentation art read the user's local scans. Images and
derived commercial artwork are never added to the public repository. Artwork is
presentation only: loading it does not identify rules, verify card text, change a
campaign, or consume gameplay randomness.

## Source location

`app/presentation/art_library.gd` resolves the source in this order:

1. `SOB_SOURCE_ROOT` environment variable.
2. `source_root` in `.local/paths.local.json` at the project/application root.
3. A `SOB` folder beside the running executable, if present.
4. The project's `SOB` folder (`res://SOB`).

Example private configuration:

```json
{"source_root": "D:/MyPrivateCollection/SOB"}
```

Relative configuration paths resolve against the project/application root. A
configured but missing library produces an empty collection. No personal source
path is embedded in application code. `.local` and `*.local.json` are ignored by
Git. Keep a sibling `SOB` library outside the public checkout; use a configured
external location when developing from the repository.

## Rendering and boundaries

The loader recursively discovers `.jpg`, `.jpeg`, `.png`, and `.webp` files and
sorts them by absolute path. Records contain an absolute `path`, the parent-folder
`category`, and filename stem `name`. Filename/category labels are provisional
collection navigation, not validated game content.

`discover(source = "")` returns those records and sets `root`. Calling it without
a source uses the location rules above. Invalid or unavailable roots return an
empty array and clear the previous cache. `get_texture(path, max_edge = 1024)`
returns a texture or `null`; it accepts only images discovered inside the current
root. `cache_size()` reports the number of retained texture entries.

Godot loads original image bytes read-only and resizes decoded images in memory,
preserving aspect ratio. Maximum requested texture edges are capped at 4096
pixels. The default is 1024. An LRU cache retains at most eight textures across
size variants. Art regions are drawn from textures at runtime; no cropped or
recompressed artwork is saved. A caller retaining a texture may keep it alive
after cache eviction.

Godot 3.5 does not expose filesystem link metadata. On Windows, the loader uses
read-only PowerShell metadata queries to reject junctions, symbolic links, and
all other reparse entries, including linked ancestors. Cloud placeholders are
also skipped. On Linux/macOS it uses the system shell, `find` without link
following, and ancestor symlink checks. If these facilities are unavailable, the
library stays empty. Windows uncached reads include a metadata process startup;
cached textures stay in memory.

Texture reads recheck their path and ancestors before opening an uncached file.
As with ordinary local filesystem access, this is not an atomic defense against
another process maliciously replacing directories between the metadata check and
the image open. Keep the collection hierarchy stable while the app is running.
Paths containing newlines or parent traversal components are rejected.

## Verification

`tests/art_suite.gd` generates small synthetic PNG fixtures under ignored `.local`
storage. It covers extension filtering, sorted discovery, category labels,
missing roots, traversal and sibling-prefix rejection, real junction/symlink
rejection, in-memory resizing, unchanged source hashes, cache reuse/eviction and
bounds, environment precedence, and unchanged campaign/RNG state. No commercial
scans are needed for these tests.

## Cosmetic role configuration

A private `.local/visuals.json` beside the project/executable can map `hero`,
`enemy`, and `world` to local imagery. `SOB_VISUAL_CONFIG` takes precedence.
Each role is an object with a source-relative `path` and optional normalized
`region: [x, y, width, height]`. Invalid values fall back to a placeholder or
full image. Regions only affect in-memory drawing; source files are untouched.
Use forward slashes and keep the file outside Git. The local installation has
these mappings configured from visually inspected scans.
