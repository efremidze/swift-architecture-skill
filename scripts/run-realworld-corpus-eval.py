#!/usr/bin/env python3
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts" / "run-testing-benchmark-suite.py"
MANIFEST = ROOT / "quality" / "corpus" / "manifest.json"


def main() -> int:
    if not RUNNER.exists():
        print(f"Runner not found: {RUNNER}")
        return 1
    if not MANIFEST.exists():
        print(f"Manifest not found: {MANIFEST}")
        return 1

    result = subprocess.run(
        ["python3", str(RUNNER), "--manifest", str(MANIFEST)],
        cwd=str(ROOT),
    )
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
