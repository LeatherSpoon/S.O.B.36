# Collection-informed visual pass

## Observed reference and scope

The first phase inventoried metadata; it did not inspect card artwork.
For this pass, representative local scans were visually inspected: a character
sheet, Gunslinger portrait, mine map sheet, Mines/Targa/Trederra world cards,
Darkness back, Tentacles sheet and a mine encounter. This is a representative
art-direction study, not a claim that every card or rule has been verified.

The observed language combines scorched parchment, inked Western portraits,
iron/wood framing, ochre lantern light, cyan supernatural shadows, frosted alien
ruins and smoky industrial battlefields. The mine presentation uses that palette.
No edition has been inferred and no card rules are transcribed into logic.

## Authorized design

- Replace the abstract board with an illustrated mine/cavern stage.
- Read portrait, enemy and card imagery directly from the user's local library.
  No scanned pixels or commercial text belong in the public repository.
- Original supplemental environment art provides a coherent play scene.
- Event-driven movement, reveal fog, lantern/dust ambience, combat recoil/flash,
  rising damage indicators and an ending transition tell the existing demo story.
- A controller-accessible collection viewer exposes the local image collection,
  grouped by folder, with zoom/pan for large scans.
- Reduced motion disables ambient motion, shake and travel animation.
- Canonical state resolves immediately; visuals never consume the gameplay RNG.
- Install a launchable Windows build at the user's chosen SOB36 folder, leaving
  its existing SOB scan subfolder intact. This is the enhanced playable slice,
  not a finished implementation of all tabletop rules.

## Test and delivery plan

1. Add regression checks for visual event consumption, state/RNG independence,
   reduced motion, gallery controls and safe local art loading.
2. Implement the isolated visual model and the redesigned scene.
3. Run the full existing core/persistence suite and new visual checks.
4. Capture real runtime frames; inspect layout and animation.
5. Build a source-allowlisted application pack excluding private scans, tests,
   manifests and saves. Install runtime, pack and local assets beside SOB.
6. Run the installed application in a scripted smoke mode; compare scan
   inventories before/after to confirm originals are unchanged.

The actual verified paths are E:\R36_Projects\SOB36 (product) and its SOB
subfolder (scans). These are installation settings, never hard-coded game paths.

## Verified outcome (2026-09-25)

The full test runner passed 139 unit assertions, gameplay/visual scene checks,
separate-process persistence, and 14 Python scan tests. The visual scene also
checks malformed cosmetic configuration fallback. An independent code review
found no blocking issue; its malformed-role suggestion was fixed and retested.

Real runtime frames were visually inspected at 640x480. The installed Windows
runtime/pack passed startup, save/load and collection discovery (478 image
files) with automatic sibling-SOB discovery, without development path overrides.
A full before/after inventory rehashed all 523 source files; the two manifests
are identical. No source scan was modified or committed. Hardware testing on
the R36S remains outstanding.
