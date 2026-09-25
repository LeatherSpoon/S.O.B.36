# AGENTS.md

This file is the working contract for Codex and other coding agents in this repository.

## Mission

Build a maintainable, offline-first digital adaptation engine for the user's personally owned **Shadows of Brimstone** collection. Begin with the base game but design every subsystem so later content packs such as Frontier Town and Trederra can plug in without engine rewrites.

## Non-negotiable constraints

1. Preserve the original game rules. Digital conveniences may improve UX but must not silently alter rules.
2. Gameplay state is authoritative; animation is presentation only.
3. Randomness must be deterministic from explicit saved RNG state.
4. Save data must be versioned and migration-ready.
5. Controller-first UX at 640×480 is a core requirement, not a later porting task.
6. Expansions are modular content packs.
7. No proprietary scans, rulebooks, card art, enemy sheets, or extracted commercial text may be committed to this public repository.
8. Never modify source scans in place.
9. Automated card/image interpretation is provisional until explicitly marked `verified`.
10. Rules code may only consume verified content records.

## Local paths

Suggested repository checkout (must be an empty directory):

```text
E:\R36_Projects\SOB-engine
```

Editable private working copies (not a Git checkout):

```text
E:\R36_Projects\SOB
```

The user authorizes this copy library for future requested image edits. Keep
these files and derived assets outside Git. Do not edit images merely as part
of inventory; the inventory command remains read-only for either library.

Private original source scans (read-only):

```text
C:\Users\Owner\OneDrive\Games\S.O.B
```

Do not hard-code the scan path in application logic. Resolve it through:

1. `SOB_SOURCE_ROOT` environment variable,
2. optional local configuration,
3. documented fallback only for the user's development machine.

## Initial technology choices

- Godot 3.5.x
- GDScript unless a subsystem has a compelling reason otherwise
- 640×480 logical viewport
- keyboard mappings for desktop testing plus controller-first input abstraction
- JSON for portable content manifests unless profiling demonstrates a need for another format
- deterministic PRNG wrapper owned by the game-state layer

Do not couple core rules logic tightly to Godot nodes. Keep domain/rules code testable independently from presentation.

## Architecture

Target separation:

```text
app/
  presentation/
  input/
  audio/

core/
  campaign/
  rules/
  rng/
  actions/
  events/
  save/
  ai/

content/
  schemas/
  loaders/
  packs/

tools/
  scan_inventory/
  content_validation/
  asset_pipeline/

tests/
```

### State/action/event flow

```text
Input or AI
  -> propose Action
  -> rules validate Action
  -> Action mutates canonical GameState
  -> domain Events emitted
  -> presentation animates Events
```

Animations must never be required to finish in order to determine canonical rules state.

## Content model

Plan for at least:

- Campaign
- Party
- Hero
- HeroClass
- Ability
- Item
- Card
- Enemy
- EnemyGroup
- Encounter
- Threat
- Mission
- World
- Location
- Town
- TownLocation
- MapTile
- MapSpace
- MapConnection
- Deck
- StatusEffect
- ExpansionPack

Every content record should support:

- stable ID
- content pack / expansion provenance
- schema version
- confidence status: `imported | identified | verified`
- source reference local to the user's collection without embedding proprietary data in Git

## Scan ingestion

Phase 0 scan tooling must be read-only against `SOB_SOURCE_ROOT`.

First-pass inventory should collect:

- relative path
- file extension
- image dimensions
- byte size
- SHA-256
- duplicate groups by hash
- provisional category from path/filename only
- processing status

Do not require OCR for the first inventory pass. OCR/vision-assisted interpretation can be layered later and must remain reviewable.

Never rename, move, recompress, crop, or overwrite original scans.

## Edition handling

The exact base-game edition has not yet been verified in the repository. Do not hard-code edition-specific card counts or rules as assumptions.

Create edition metadata as a first-class field. If source material suggests an edition, record it as provisional until user verification.

## Testing expectations

At minimum:

- deterministic RNG tests
- save/load round-trip tests
- content schema validation
- content-pack dependency tests
- action validation tests
- map topology tests
- headless tests for core rules where practical

A save/load round trip must preserve state, including RNG state, exactly.

## Research references

Use these as architectural/reference material; respect each project's license and do not copy unlicensed proprietary content into this repository:

- Grauenwolf/BrimstoneMissions — mission schema, expansion/world relationships, rules decomposition
- ranaur/shadows-of-brimstone — broad personal reference/archive and TTS-derived structure; no general reusable-content license
- templebay33/brimstone_reference — machine-readable map/rules reference concepts
- rbhaddon/sobapp — older Unity HexCrawl/Frontier Town companion experiments
- ConstructiveCoding/sobtracker — character tracker concepts
- RedSpartan/BrimstoneCompanion — companion app concepts

## Definition of done for Phase 0

Phase 0 is complete when:

- desktop project boots at 640×480;
- input abstraction supports keyboard and gamepad;
- deterministic game-state/RNG service exists;
- versioned campaign save/load round-trips successfully;
- modular content packs can be discovered and validated;
- scan inventory tool can safely inventory the private source folder;
- no private/copyrighted source assets are committed;
- automated tests cover the above;
- README contains exact commands to run the game, tests, and scan inventory.
