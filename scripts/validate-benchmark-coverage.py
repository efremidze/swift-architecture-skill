#!/usr/bin/env python3
import json
from pathlib import Path
from typing import Dict, List


ROOT = Path(__file__).resolve().parents[1]
BENCHMARK_MANIFEST = ROOT / "quality" / "benchmarks" / "manifest.json"
ARCHITECTURES = [
    "mvvm",
    "mvi",
    "tca",
    "clean-architecture",
    "viper",
    "reactive",
]


def load_json(path: Path) -> Dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise RuntimeError(f"Failed to read JSON file {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Invalid JSON in {path}: {exc}") from exc


def main() -> int:
    if not BENCHMARK_MANIFEST.exists():
        print(f"Benchmark manifest not found: {BENCHMARK_MANIFEST}")
        return 1

    try:
        manifest = load_json(BENCHMARK_MANIFEST)
    except RuntimeError as exc:
        print(exc)
        return 1
    cases = manifest.get("cases", [])
    if not cases:
        print("Benchmark manifest has no cases.")
        return 1

    errors: List[str] = []
    coverage = {
        architecture: {"positive": 0, "negative": 0}
        for architecture in ARCHITECTURES
    }

    for case in cases:
        case_id = case.get("id", "<missing-id>")
        architecture_assertions = case.get("architecture_assertions")
        if not architecture_assertions:
            continue

        architecture = case.get("architecture")
        if architecture not in coverage:
            errors.append(
                f"{case_id}: architecture assertions require valid architecture in {ARCHITECTURES}"
            )
            continue

        if not isinstance(architecture_assertions, list):
            errors.append(f"{case_id}: architecture_assertions must be a list")
            continue

        for index, assertion in enumerate(architecture_assertions, start=1):
            if not assertion.get("label"):
                errors.append(f"{case_id}: assertion {index} missing label")
            if not assertion.get("regex"):
                errors.append(f"{case_id}: assertion {index} missing regex")

        if not case.get("expect_semantic", False):
            errors.append(
                f"{case_id}: architecture assertion cases must keep semantic expectation true"
            )

        expect_architecture = bool(case.get("expect_architecture", True))
        bucket = "positive" if expect_architecture else "negative"
        coverage[architecture][bucket] += 1

    for architecture, counts in coverage.items():
        if counts["positive"] < 1:
            errors.append(
                f"{architecture}: missing architecture-positive benchmark case with assertions"
            )
        if counts["negative"] < 1:
            errors.append(
                f"{architecture}: missing architecture-negative benchmark case with assertions"
            )

    if errors:
        print("Benchmark coverage validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Benchmark coverage validation passed.")
    for architecture in ARCHITECTURES:
        counts = coverage[architecture]
        print(
            f"- {architecture}: positive={counts['positive']}, negative={counts['negative']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
