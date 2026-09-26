# S.O.B.36

Personal, offline-first digital adaptation framework for **Shadows of Brimstone**, initially targeting PC development and the R36S handheld at a 640×480 logical resolution.

## Project goals

- Preserve the original tabletop rules as the canonical gameplay model.
- Support persistent heroes, XP, equipment, injuries, mutations, campaign state, towns, mines, Other Worlds, missions, and expansion content.
- Support local pass-and-play human players and computer-controlled players.
- Keep presentation separate from deterministic game state so save/load, replay, testing, and AI simulation remain reliable.
- Treat expansions as modular content packs rather than hard-coded forks of the engine.
- Start with the base game, then grow into Frontier Town, Trederra, and other expansions.

- 
## Development targets

- **Primary development machine:** Windows PC
- **Suggested code checkout:** `E:\R36_Projects\SOB-engine` (use an empty folder)
- **Windows product folder:** `E:\R36_Projects\SOB36`
- **Editable private image copies:** `E:\R36_Projects\SOB36\SOB`
- **Private scan/source library:** `C:\Users\Owner\OneDrive\Games\S.O.B`
- **Primary handheld target:** R36S
- **Logical resolution:** 640×480
- **Initial engine:** Godot 3.5.x, controller-first

## Source-material policy


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
4. Persist hero(s) state(s).
5. Discover modular content packs.
6. Inventory the private scan library without modifying it.
7. Display map tile(s).
8. Move a hero(s) between spaces.
9. Spawn a placeholder enemy.
10. Execute a deterministic turn/combat stub.
11. Save, quit, reload, and reproduce state exactly.

See `AGENTS.md` and `docs/CODEX_KICKOFF.md`.

## Phase 0: run the foundation demo

This branch implements an **original placeholder adventure**, not verified
Shadows of Brimstone rules. It includes two connected tiles, one hero, one test
enemy, deterministic initiative/attacks, test XP, and campaign save/reload.
No edition-specific commercial rules or content are included.

### Prerequisites

- [Godot 3.5.3 Standard](https://godotengine.org/download/archive/3.5.3-stable/)
  (not Godot 4; no .NET required).
- Python 3.10+ and the pinned Pillow dependency for inventory/tests.
  Development verification used Python 3.14.3 and Pillow 12.3.0.
- A keyboard; a mapped gamepad is optional for desktop testing.

Clone into an **empty directory**. The originally proposed
`E:\R36_Projects\SOB36\SOB` was found to contain source scan folders on the handoff
machine. The user confirmed that this folder holds editable private image copies;
keep it separate from the Git checkout. The OneDrive library remains the
read-only original. Use an empty sibling such as `E:\R36_Projects\SOB-engine`
for code. Phase 0 performs no image edits.

Run the following from the repository root in PowerShell. Replace the Godot
executable path with your installation:

```powershell
$env:GODOT_BIN = 'C:\Tools\Godot_v3.5.3-stable_win64.exe'
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
New-Item -ItemType Directory -Force .local | Out-Null
$env:SOB_SAVE_PATH = Join-Path (Get-Location) '.local\campaign.json'
& $env:GODOT_BIN --path .
```

The private source library is not required to run the placeholder demo.
Without `SOB_SAVE_PATH`, saves go to Godot's `user://campaign.json`
(on Windows, under `%APPDATA%\Godot\app_userdata\S.O.B.36 - Foundation\`).
The override above keeps development saves inside ignored `.local/`.

### Controls and walkthrough

| Action | Keyboard | Standard mapped gamepad |
| --- | --- | --- |
| Move | Arrow keys or WASD | D-pad or left stick |
| Reveal / engage / attack / finish | Enter or Space | A / bottom face button |
| Save | F5 | X / left face button |
| Load | F9 | Y / top face button |
| New campaign | N | Start |
| Cancel new-campaign confirmation | Escape | B / right face button |
| Browse private image collection | G or Tab | Select |
| Reduced motion | M | Left shoulder |

Move right once to the doorway, confirm to reveal, move right again, and confirm
to roll initiative. Confirm repeatedly to defeat the enemy. Confirm once more
to finish and save. The hero earns 5 test XP. Load restores position, progress,
event history and the next RNG result exactly. New campaign asks for confirmation;
its fixed seed (12345) makes the demonstration reproducible.

Controller mapping and injected gamepad input are automated-tested. Physical
R36S/controller hardware validation and R36S packaging remain outstanding.

### Run all automated checks

```powershell
.\.venv\Scripts\python.exe tools/run_tests.py --godot $env:GODOT_BIN
```

This runs GDScript core/content/input tests, the actual scene with injected
keyboard and gamepad events, a save/write then terminate/read proof in separate
Godot processes, and the Python scan safety tests. Tests write only under
ignored `.local/`. The malformed-save test deliberately triggers one Godot
JSON parse diagnostic; the runner checks that exact expected diagnostic and
rejects other engine/script errors.

Individual commands:

```powershell
& $env:GODOT_BIN --no-window --path . --script tests/run_tests.gd
& $env:GODOT_BIN --no-window --path . --script tools/content_validation/validate_packs.gd
.\.venv\Scripts\python.exe -m unittest discover -s tests -p 'test_scan_inventory.py' -v
```

On Linux, use the Godot 3.5.3 headless binary for automated checks, or the normal
desktop binary with a display for visual testing. Use `python3` and
`.venv/bin/python` instead of the Windows Python paths.

### Inventory your private scans

```powershell
$env:SOB_SOURCE_ROOT = 'C:\Users\Owner\OneDrive\Games\S.O.B'
.\.venv\Scripts\python.exe -m tools.scan_inventory --output .local/scan_manifest.json
```

Rerun the same command to resume; use `--no-resume` to rehash all files.
The manifest and checkpoint contain private metadata and must stay local.
Sources are opened read-only. OneDrive may hydrate cloud files when read.
No OCR, source editing, scan copying into Git, or automatic verification occurs.

See [scan inventory](docs/SCAN_INVENTORY.md), [schemas](docs/SCHEMAS.md),
[architecture and decisions](docs/ARCHITECTURE.md),
and [Phase 0 validation](docs/PHASE0_VALIDATION.md).

### Validate alternate packs

A pack root contains child pack directories, each with a manifest.
For private work, place that root under ignored `local_content/`.

```powershell
$env:SOB_PACK_ROOT = Join-Path (Get-Location) 'local_content\packs'
$env:SOB_ENABLED_PACKS = 'placeholder,sample'
& $env:GODOT_BIN --no-window --path . --script tools/content_validation/validate_packs.gd
```

All enabled packs and their exact-version dependencies must be present in that
root. `SOB_EDITION_ID` optionally validates a known edition. The demo itself uses
the bundled placeholder pack; commercial packs and a pack-selection interface
belong to subsequent milestones.

### Collection-informed visuals and local Windows build

The mine scene adds original generated environment art, local scan portraits,
animated movement/reveals/combat/dice, and a folder-based image viewer. Press G
or Select; arrows change image/folder, A zooms, arrows pan when zoomed, B fits
then closes. M or left shoulder toggles reduced motion. Some scans contain
multiple cards on a sheet; PDFs are not displayed. Art remains cosmetic and
never supplies unverified gameplay rules.

The local Windows installation is `E:\R36_Projects\SOB36\SOB36.exe` with scans
in its `SOB` subfolder. It saves in `saves/campaign.json`; press F9 to load.
Keep `.local/visuals.json` private. See [private art setup](docs/PRIVATE_VISUAL_LIBRARY.md)
and [visual scope](docs/VISUAL_UPGRADE.md).

To build an application pack from public-safe source files:

```powershell
$env:SOB_PACK_OUTPUT = Join-Path (Get-Location) 'build\SOB36.pck'
# Python waits for the Windows GUI executable to exit and checks its result.
python -c 'import os,subprocess; subprocess.run([os.environ["GODOT_BIN"], "--no-window", "--path", ".", "--script", "tools/package/build_pack.gd"], check=True)'
```

Place the pack beside the official Godot 3.5.3 Standard Windows executable,
renamed `SOB36.exe`, and include its license notices. The local portable build
uses this standard engine binary; optimized exports and R36S packaging are
still future work. The pack allowlists application/core/placeholder content;
private scans, configurations, manifests and saves are excluded.
