# Phase 0 validation

Verified with Godot 3.5.3 Standard (GLES2), Windows x64, Python 3.14.3 and
Pillow 12.3.0 on 2026-09-25.

## Automated evidence

- 90 GDScript assertions passed: known RNG vectors, continuation, action
  rejection without mutation, map topology, combat/XP/completion, exact
  canonical save round trips, invalid save rejection, content provenance,
  confidence gating, discovery, dependency/version/cycle checks, and input
  bindings.
- Actual scene smoke test passed at 640×480. Injected keyboard movement and
  mapped gamepad confirmation exercised the real input path. The test completed
  the adventure, saved/reloaded during combat, and retained completed progress.
- Two separate Godot processes passed the persistence proof: write canonical
  state, terminate, reload, compare every field, then compare the next attack
  and its events with an uninterrupted run.
- 14 Python inventory tests passed without skips. Coverage includes read-only
  source checks, dimensions/hashes/duplicates, deterministic restart, unreadable
  entries, changed files, cloud-placeholder handling, junction/link avoidance,
  and manifest/checkpoint writes staying outside the source tree.
- Standalone pack validation passed for one bundled original pack / three records.
- All three JSON Schemas compiled with jsonschema 4.26.0; the bundled manifest,
  three records and two generated campaign saves validated. jsonschema is a
  one-time development check, not a runtime dependency.
- Official Godot archive SHA-512 verified before execution.
- Documented pinned Pillow dependency installed successfully into an isolated
  dependency directory.
- Actual private library inventory completed read-only with no file/directory
  errors. Per-file metadata and checkpoints remain ignored under `.local/`.
- Rendered scene captured and visually inspected at 640×480: board, status,
  placeholder notice and controls fit.
- Separate spec and code-quality reviews completed; identified validation
  gaps were reproduced with failing tests, fixed, and retested.

The malformed-save test intentionally emits one Godot JSON parse diagnostic.
The aggregate runner accepts only that exact expected line for the core suite,
checks suite completion and rejects other engine/script diagnostics.

## Reproduction

From the repository root:

```powershell
python tools/run_tests.py --godot $env:GODOT_BIN
& $env:GODOT_BIN --no-window --path . --script tools/content_validation/validate_packs.gd
```

Only source-controlled files were included in the clean-copy validation.
No cache, save, private pack, scan, inventory manifest, or generated source
material is needed for automated tests or the demo.

## Manual acceptance remaining

- Plug in the user's physical controller and confirm its mapping and feel.
- Verify behavior and performance on actual R36S hardware in a later packaging
  milestone. No R36S build is claimed.
- Verify the exact commercial base-game edition before implementing real rules.
- User review of the placeholder experience and draft pull request.

These limits are distinct from the passing desktop/injected-input tests.
The demo deliberately uses original test mechanics, not commercial rules.
