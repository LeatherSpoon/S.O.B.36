# S.O.B.36

Personal, offline-first digital adaptation framework for **Shadows of Brimstone**, initially targeting PC development and the R36S handheld at a 640×480 logical resolution.

## Project goals

- Preserve the original tabletop rules as the canonical gameplay model.
- Support persistent heroes, XP, equipment, injuries, mutations, campaign state, towns, mines, Other Worlds, missions, and expansion content.
- Support local pass-and-play human players and computer-controlled players.
- Keep presentation separate from deterministic game state so save/load, replay, testing, and AI simulation remain reliable.
- Treat expansions as modular content packs rather than hard-coded forks of the engine.
- Start with the base game, then grow into Frontier Town, Trederra, and other owned expansions.

## Development targets

- **Primary development machine:** Windows PC
- **Expected local checkout:** `E:\R36_Projects\SOB`
- **Private scan/source library:** `C:\Users\Owner\OneDrive\Games\S.O.B`
- **Primary handheld target:** R36S
- **Logical resolution:** 640×480
- **Initial engine:** Godot 3.5.x, controller-first

## Source-material policy

This repository is currently **public**. Do not commit copyrighted scans, rulebooks, card faces, enemy sheets, extracted proprietary text, or other commercial game assets.

The user's locally owned scans are the private source of truth and remain outside Git. Tooling should read them from a configurable source path and generate local-only derived content.

Use the environment variable:

```text
SOB_SOURCE_ROOT=C:\Users\Owner\OneDrive\Games\S.O.B
```

Generated/private content must stay in ignored directories.

## Data confidence

Imported content moves through three explicit states:

```text
Imported -> Identified -> Verified
```

Only **Verified** gameplay data may drive rules resolution. Automated interpretation must never silently become canonical game data.

## Initial milestone

Build the architectural spine before attempting full rules coverage:

1. Boot at 640×480.
2. Controller and keyboard navigation.
3. Create/load a campaign.
4. Persist hero state.
5. Discover modular content packs.
6. Inventory the private scan library without modifying it.
7. Display one placeholder map tile.
8. Move a hero between spaces.
9. Spawn a placeholder enemy.
10. Execute a deterministic turn/combat stub.
11. Save, quit, reload, and reproduce state exactly.

See `AGENTS.md` and `docs/CODEX_KICKOFF.md`.
