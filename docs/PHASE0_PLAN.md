# Phase 0 implementation plan

The approved scope is `CODEX_KICKOFF.md` and issue #1. Implement on
`codex/phase0-foundation` in an isolated checkout; the expected E: directory
already contains source material and must not be overwritten.

**Goal:** A playable, placeholder-only deterministic two-tile adventure.

**Architecture:** Plain GDScript Reference objects own campaign, hero, map,
RNG and events. Input proposes actions; validation precedes all mutation.
Godot draws state and displays emitted events. JSON saves include explicit
algorithm/version, state, edition confidence, and content pack versions.

**Stack:** Godot 3.5.3 (GLES2), GDScript, Python 3 + Pillow for scan metadata.

## Work and verification

- [x] Core: write `tests/core_suite.gd` before `core/` implementation;
  verify known RNG vectors, rejected actions leave state and RNG untouched,
  topology, initiative/combat/XP, and save rejection/round trips.
- [x] Content: write `tests/content_suite.gd` before `content/loaders/`;
  validate manifests and records, dependencies/cycles/disabled packs, safe
  relative file paths, duplicate IDs, and verified-only rules access.
- [x] Presentation: `project.godot`, `app/input/controls.gd`,
  `app/presentation/main.gd` and scene. D-pad/left stick or arrows move;
  confirm reveals/attacks/finishes, dedicated save/load/new controls.
  Verify bindings and instantiate the real scene in a smoke test.
- [x] Inventory: `tools/scan_inventory/`, `tests/test_scan_inventory.py`;
  read-only recursive scan, bounded hashing, dimensions, deterministic
  duplicates, resume, isolated output, and recoverable unreadable files.
  Run against real private library with ignored local output only.
- [x] Persistence proof: `tests/persistence_process.gd` and Python runner
  start two separate Godot processes, reload and compare canonical state
  and next randomized action to uninterrupted execution.
- [x] Docs: exact setup/run/test commands, schemas, design decisions,
  provenance boundaries, edition uncertainty, and acceptance evidence.
- [x] Review spec compliance then code quality; address findings and run
  tests from a fresh source copy before preparing the reviewable result.

No rulebook/card content is needed. All demo mechanics are original test
fixtures, visibly identified as such, and make no edition claims.
