#!/usr/bin/env python3
import sys
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "tooling" / "scripts" / "run" / "benchmarks.py"
MANIFEST = ROOT / "tooling" / "evals" / "corpus" / "manifest.json"
TIMEOUT_SECONDS = 300


def main() -> int:
    if not RUNNER.exists():
        print(f"Runner not found: {RUNNER}")
        return 1
    if not MANIFEST.exists():
        print(f"Manifest not found: {MANIFEST}")
        return 1

    try:
        result = subprocess.run(
            [sys.executable, str(RUNNER), "--manifest", str(MANIFEST)],
            cwd=str(ROOT),
            timeout=TIMEOUT_SECONDS,
        )
        return result.returncode
    except subprocess.TimeoutExpired:
        print(f"Corpus evaluation timed out after {TIMEOUT_SECONDS} seconds")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
