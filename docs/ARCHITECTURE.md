# Phase 0 architecture and decisions

## Boundaries

`app/input/controls.gd` installs logical actions for keyboards, mapped gamepad
buttons, and left stick axes. `app/presentation/main.gd` translates these into
domain actions, draws snapshots, and displays emitted events. It never writes
hero XP, position, enemy health, RNG, or campaign progress.

`core/campaign/` contains plain Reference objects: GameState, CampaignState
and HeroState. None extends a scene node. `core/actions/action_service.gd`
validates before any mutation or RNG consumption, applies the action immediately,
and appends domain events. Presentation timing is never part of resolution.
AI can eventually submit the same action dictionaries.

The event queue retains a numbered canonical history for this small slice.
The UI keeps a separate three-message display buffer. Display text and visual
state are not saved. Long campaigns will need event-log compaction/versioning.

## Decisions

1. **Godot 3.5.3 and GLES2.** 640×480 logical canvas with aspect-preserving
   scaling. Desktop development is tested; R36S exports and hardware performance
   remain outside Phase 0.
2. **Explicit PRNG algorithm.** Park–Miller 16807 uses bounded 64-bit integer
   products and state in 1..2147483646, avoiding floating-point RNG state and
   engine-specific random implementations. Die rolls use rejection sampling.
   Golden vectors and save continuation tests pin the algorithm.
3. **Canonical integer JSON.** Domain numbers are signed 32-bit integers, exactly
   representable by JSON readers. Godot 3 parses numbers as reals; validation
   rejects fractional/out-of-range values before restoring integers. No accepted
   canonical field is silently rounded or dropped.
4. **Versioned envelope.** Save v1 records format, version, state, RNG algorithm,
   edition confidence, selected pack IDs and exact versions. Unknown versions
   fail clearly. Future migrations belong before state validation in the decoder,
   and require golden old-save fixtures. There are no historical versions yet.
5. **Preserve the previous save.** Write a sibling temporary file, flush, reopen
   and validate it, retain the old file as `.bak`, then rename. If final rename
   fails, attempt to restore the backup. This is not a transactional database:
   after power loss during replacement the backup may need manual restoration.
6. **Pack selection is explicit.** Discover manifests in immediate child
   directories, sort all discovery inputs, validate, then publish a complete
   registry only after every selected pack succeeds. Dependencies use exact
   versions and must be enabled explicitly. Missing, disabled, mismatched and
   cyclic dependencies fail. Save state persists selected packs.
7. **Confidence is a rules boundary.** Imports may exist in the registry at
   `imported` or `identified`; `for_rules` returns only copied `verified`
   records. The demo fixtures are original authored test data, marked verified
   for their intended testing purpose. No automated interpretation is verified.
8. **Edition remains unresolved.** New campaigns store an empty edition ID and
   `unverified` status. Empty pack edition lists mean edition-neutral fixtures,
   not verified compatibility with every commercial edition.
9. **Private library stays external.** Inventory is Python because Pillow and
   filesystem tooling are appropriate for desktop ingestion. It does not run
   inside Godot, perform OCR, change scans, or generate rule content.

## Original fixture mechanics

This is not a partial transcription of tabletop rules. One hero walks a
four-space linear map across two tiles. At the doorway, reveal connects the
second tile and exposes a 4 HP enemy. Engage rolls two d6 for a logged initiative
order (ties favor hero); enemy turns do not act in this stub. Each test attack
deals 1 damage for rolls 1–3 and 2 for 4–6. Defeat awards 5 test XP once.
Finish increments completed adventures and the UI saves. A new campaign uses
seed 12345. These deliberately small original fixtures validate architecture.

The current action service, tile IDs, one-hero restriction, and combat are
explicit Phase 0 demo policy. A future verified base-game rules module must
replace this policy; the pack registry, state/action/event interface, RNG and
save envelope remain reusable. Further schemas/migrations are required as
real heroes, inventories and campaigns are introduced.

## Extension points

- `core/rules/`: verified edition-specific rule sets, when sourced and reviewed.
- `core/ai/`: action proposers using the same validator; no authoritative state.
- `app/audio/`: event-driven feedback, with no effects on gameplay state.
- `tools/asset_pipeline/`: future derived assets under ignored local roots.
- Content types reserve Campaign, Party, Hero, HeroClass, Ability, Item, Card,
  Enemy, EnemyGroup, Encounter, Threat, Mission, World, Location, Town,
  TownLocation, MapTile, MapSpace, MapConnection, Deck, StatusEffect,
  ExpansionPack. Only the original Enemy/MapTile fixture payloads have gameplay
  implementations in Phase 0; other payloads currently have envelope validation.

## Reference documentation

Implementation uses the official [Godot 3.5 command-line interface](https://docs.godotengine.org/en/3.5/tutorials/editor/command_line_tutorial.html)
and [project settings](https://docs.godotengine.org/en/3.5/classes/class_projectsettings.html).
No commercial content or third-party adaptation code was imported.
