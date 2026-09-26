# Codex Kickoff — Phase 0 / Foundation

## Objective

Create the technical foundation for S.O.B.36 without attempting a complete Shadows of Brimstone implementation yet.

The end state of this phase is a small, deterministic vertical slice that proves the architecture can support persistent campaign play, modular expansions, private scan ingestion, AI, and future R36S deployment.

## User context

The user owns the physical game and multiple expansions and has a large private scan collection.

Local development paths:

```text
Code checkout (suggested): E:\R36_Projects\SOB-engine
Editable private copies:   E:\R36_Projects\SOB36\SOB
Original scan library:     C:\Users\Owner\OneDrive\Games\S.O.B
```

The repository itself is public. Proprietary source material must remain local-only.

## Phase 0 work packages

### WP0 — Repository/bootstrap

Create a conventional Godot 3.5.x project with:

- 640×480 logical resolution
- clean folder structure matching `AGENTS.md`
- keyboard + controller input abstraction
- headless/test entry point where practical
- developer setup instructions

### WP1 — Deterministic domain core

Implement:

- `GameState`
- `CampaignState`
- `HeroState`
- deterministic RNG service with serializable state
- action validation/execution boundary
- domain event queue
- versioned save envelope

The presentation layer must observe events; it must not own canonical game rules.

### WP2 — Content-pack framework

Implement a pack manifest and loader supporting:

- stable pack ID
- name
- version
- dependencies
- supported edition metadata
- content file discovery
- schema validation
- enable/disable state

Create one non-proprietary placeholder pack for tests.

Design now for future packs such as:

```text
base/
frontier_town/
trederra/
...
```

but do not fill them with copyrighted content in Git.

### WP3 — Private scan inventory tool

Create a read-only inventory command for `SOB_SOURCE_ROOT`.

Output a **local ignored manifest** containing:

- relative path
- file extension
- dimensions
- size
- SHA-256
- duplicate-group ID
- provisional type/category if inferable from path/filename
- `imported/identified/verified` status

Requirements:

- recursive
- restartable
- deterministic
- does not alter source files
- handles a large collection
- reports unreadable files without aborting the entire run
- no OCR requirement in this phase

### WP4 — Minimal board vertical slice

Using placeholders only:

- load a new campaign
- create at least one hero
- enter a test adventure
- render one test map tile
- represent discrete traversable spaces/connections
- move hero with controller
- reveal/connect a second test tile
- spawn a placeholder enemy
- execute a minimal deterministic initiative/combat stub
- award placeholder XP
- finish adventure
- save campaign

This is architecture validation, not rules completeness.

### WP5 — Persistence proof

Automated or scripted acceptance test:

1. Create campaign with known RNG seed/state.
2. Create hero.
3. Perform several actions including a random result.
4. Save.
5. Terminate/reload.
6. Assert full canonical state equality.
7. Continue one random operation and verify it produces the same result as an uninterrupted run.

### WP6 — Documentation

Document:

- local setup
- Godot version
- run commands
- test commands
- scan-inventory command
- location of local generated/private content
- pack schema
- save schema
- architectural decision log

## Explicitly out of scope for Phase 0

- Full card transcription
- Full base-game rules
- OCR of the entire scan library
- Final art
- Full enemy AI
- Strategic hero AI
- Frontier Town rules implementation
- Trederra rules implementation
- R36S packaging
- Network multiplayer

These become subsequent milestones after foundation validation.

## Phase 1 direction

Once Phase 0 is green:

1. Verify exact base-game edition.
2. Inventory and classify base-game source material.
3. Build verified schemas for heroes, enemies, items, decks, missions, and map tiles.
4. Implement original base-game turn sequence and combat.
5. Implement enemy behavior.
6. Build one complete base-game mission.
7. Add local pass-and-play.
8. Only then expand content breadth.

## Acceptance criteria

Phase 0 is accepted when:

- project launches at 640×480;
- no committed proprietary source material exists;
- scan inventory successfully processes the user's source directory read-only;
- content packs are discoverable and schema-validated;
- controller navigation works;
- placeholder two-tile adventure is playable;
- campaign XP/state persists;
- deterministic save/load test passes;
- all automated tests pass;
- setup is reproducible from a fresh clone plus the user's private local content.

## Engineering bias

Prefer boring, explicit, testable infrastructure over clever abstractions.

Do not optimize for the first demo at the expense of later Frontier Town / Trederra modularity.
