# Content and save formats

Machine-readable JSON Schemas live in `content/schemas/`. Runtime validation
is dependency-free GDScript in `content/loaders/schema.gd` and
`core/save/state_validator.gd`. Runtime checks also enforce relationships that
JSON Schema alone does not express.

## Pack manifest v1

A pack is a child directory containing `manifest.json` and one or more JSON
arrays of records. Required fields: `schema_version: 1`, stable `id`, `name`,
`version`, `dependencies`, `supported_editions`, `content_files`.
Unknown fields are rejected in v1.

```json
{
  "schema_version": 1,
  "id": "sample",
  "name": "Original sample",
  "version": "0.1.0",
  "dependencies": [{"id": "placeholder", "version": "0.1.0"}],
  "supported_editions": [],
  "content_files": ["records.json"]
}
```

Versions are opaque exact strings, not semantic-version ranges. Enable both
a pack and all its dependencies. The loader rejects cycles and duplicate pack
or record IDs. Disabling a pack removes all its records from the active registry.
File paths must be relative JSON paths without traversal, empty segments,
backslashes or drive/scheme prefixes.

Edition IDs are strings. An empty list is reserved here for edition-neutral
test content. When an edition is known, loading and restoring saves check
declared compatibility. No commercial edition ID has been assigned.

## Record v1

Required fields: `schema_version`, `id`, `pack_id`, `type`, `status`,
`source_ref`, `data`. IDs use lowercase letters, digits, dot, underscore or
hyphen and must start with `pack_id + "."`. Provenance cannot disagree with
the containing manifest. `source_ref` is a logical local relative reference,
never an embedded scan, absolute path, or web fetch request.

Status is exactly `imported`, `identified`, or `verified`. The inventory
tool always emits imported metadata. A separate explicit review is needed
before real content can become verified. The original fixture source reference
is `original/phase0`; it does not refer to the user's library.

`Enemy` fixture data contains integer `hp` (1..10000) and `xp` (0..10000).
`MapTile` fixture data contains `spaces` and `connections`. Spaces have
`id`, `tile`, integer `x` and `y` (0..20). Connections are pairs of IDs;
cross-tile connections are allowed. Assembling a game also checks unknown
references, duplicate IDs/coordinates/edges, connectivity and valid locations.
Future real-game payload schemas require their own review/versioning.

Private packs belong under `local_content/` or another ignored root. A pack
can be discovered and validated from an alternate root using `SOB_PACK_ROOT`.
The playable demo selects the bundled `placeholder` pack; pack-management UI
and full expansion rules are not implemented.

## Campaign save v1

`save.schema.json` documents the envelope. Required top-level fields:

```json
{"format": "sob36.campaign", "save_version": 1, "state": {}}
```

The state above is illustrative only: a real save must include campaign,
RNG, map, enemy, phase, turn, pack selection, initiative and event history.

- Campaign includes ID, edition ID/status, one hero and completed adventures.
- Hero includes ID, name, space ID and XP.
- RNG includes algorithm `park_miller_16807_v1` and integer state.
- Map includes discrete spaces, bidirectional edges and revealed tiles.
- Enemy includes source record ID, location, health, spawn and award flags.
- Events include contiguous sequence numbers, type and payload.
- Packs map enabled IDs to exact installed versions.
- Initiative is empty before engage, otherwise hero/enemy rolls and first actor.

All numbers, including event payload numbers, must be signed 32-bit integers.
Invalid/future envelopes, broken topology, fractional numbers, invalid RNG,
missing or incompatible packs and unverified fixture references fail before
replacing the active game. User-visible messages report load/save failure.
On successful reload, canonical state and subsequent random events match the
uninterrupted run exactly.

Saves use Godot's `user://campaign.json` by default. For local development,
set `SOB_SAVE_PATH` to an absolute path under the checkout's ignored `.local/`.
A backup is retained at the same path plus `.bak`. Restore that backup manually
if a power failure interrupted replacement; the current loader never silently
falls back to older progress.
