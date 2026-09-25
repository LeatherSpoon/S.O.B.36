"""Run core, real scene input, process-restart persistence, and inventory tests."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def godot_run(executable: str, script: str, marker: str, extra_env=None) -> None:
    env = os.environ.copy()
    env.update(extra_env or {})
    result = subprocess.run(
        [executable, "--no-window", "--audio-driver", "Dummy", "--path", str(ROOT),
         "--script", script],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        env=env, timeout=90,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    # Godot 3 may exit zero after a GDScript runtime error: inspect diagnostics too.
    unexpected = [
        line for line in output.splitlines()
        if ("SCRIPT ERROR:" in line or line.startswith("ERROR:"))
        and not (script == "tests/run_tests.gd" and line ==
                 "ERROR: Error parsing JSON at line 0: Expected 'true','false' or 'null', got 'garbage'.")
    ]
    if result.returncode or marker not in output or unexpected:
        raise RuntimeError(f"{script} failed (exit {result.returncode})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    version = subprocess.run([args.godot, "--version"], capture_output=True, text=True, timeout=20)
    if not version.stdout.strip().startswith("3.5."):
        raise RuntimeError("Godot 3.5.x is required")
    (ROOT / ".local").mkdir(exist_ok=True)
    godot_run(args.godot, "tests/run_tests.gd", "; failures: 0")
    godot_run(args.godot, "tests/scene_smoke.gd", "Scene smoke failures: 0")
    godot_run(args.godot, "tests/persistence_process.gd", "Persistence write complete", {"SOB_TEST_MODE": "write"})
    godot_run(args.godot, "tests/persistence_process.gd", "Separate-process persistence proof passed", {"SOB_TEST_MODE": "read"})
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"], cwd=ROOT, check=True)
    print("All Phase 0 automated checks passed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print(f"TEST FAILURE: {exc}", file=sys.stderr)
        raise SystemExit(1)
