#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "quality" / "benchmarks" / "manifest.json"
BASE_CONTRACT = ROOT / "quality" / "testing-quality-contract.json"
SYNTAX_VALIDATOR = ROOT / "scripts" / "validate-testing-snippets.sh"
SEMANTIC_VALIDATOR = ROOT / "scripts" / "validate-testing-quality.py"


def load_json(path: Path) -> Dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run_command(cmd: List[str]) -> Tuple[bool, str]:
    result = subprocess.run(cmd, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


def evaluate_case(
    case: Dict,
    default_heading_regex: str,
    base_contract: Dict,
) -> Tuple[bool, bool, str, str]:
    source = ROOT / case["file"]
    if not source.exists():
        return False, False, f"Missing case file: {source}", f"Missing case file: {source}"

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        case_copy = temp_path / source.name
        shutil.copyfile(source, case_copy)

        syntax_passed, syntax_output = run_command(
            [str(SYNTAX_VALIDATOR), str(temp_path)]
        )

        contract = {
            "version": base_contract.get("version", 1),
            "playbooks": [
                {
                    "path": str(case_copy),
                    "section_heading_regex": case.get(
                        "section_heading_regex", default_heading_regex
                    ),
                }
            ],
            "required_any_groups": base_contract.get("required_any_groups", []),
            "required_patterns": base_contract.get("required_patterns", []),
        }
        contract_path = temp_path / "contract.json"
        contract_path.write_text(json.dumps(contract, indent=2), encoding="utf-8")

        semantic_passed, semantic_output = run_command(
            [
                "python3",
                str(SEMANTIC_VALIDATOR),
                "--contract",
                str(contract_path),
            ]
        )

    return syntax_passed, semantic_passed, syntax_output, semantic_output


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run external benchmark suite for testing validators."
    )
    parser.add_argument(
        "--manifest",
        default=str(DEFAULT_MANIFEST),
        help="Path to benchmark manifest JSON.",
    )
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path

    if not manifest_path.exists():
        print(f"Manifest not found: {manifest_path}")
        return 1
    if not BASE_CONTRACT.exists():
        print(f"Base contract not found: {BASE_CONTRACT}")
        return 1

    manifest = load_json(manifest_path)
    base_contract = load_json(BASE_CONTRACT)
    cases = manifest.get("cases", [])
    if not cases:
        print("No benchmark cases found.")
        return 1

    default_heading_regex = manifest.get(
        "default_section_heading_regex", r"^##\s+Testing Strategy\s*$"
    )

    failures = 0
    print(f"Running benchmark suite: {len(cases)} case(s)")
    for case in cases:
        case_id = case["id"]
        expect_syntax = bool(case["expect_syntax"])
        expect_semantic = bool(case["expect_semantic"])
        syntax_ok, semantic_ok, syntax_output, semantic_output = evaluate_case(
            case, default_heading_regex, base_contract
        )

        syntax_match = syntax_ok == expect_syntax
        semantic_match = semantic_ok == expect_semantic
        status = "PASS" if syntax_match and semantic_match else "FAIL"

        print(
            f"- {status} {case_id}: "
            f"syntax={syntax_ok} (expected {expect_syntax}), "
            f"semantic={semantic_ok} (expected {expect_semantic})"
        )

        if not syntax_match:
            failures += 1
            print("  Syntax validator output:")
            for line in syntax_output.splitlines()[:10]:
                print(f"    {line}")

        if not semantic_match:
            failures += 1
            print("  Semantic validator output:")
            for line in semantic_output.splitlines()[:10]:
                print(f"    {line}")

    if failures:
        print(f"Benchmark suite failed with {failures} mismatch(es).")
        return 1

    print("Benchmark suite passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
