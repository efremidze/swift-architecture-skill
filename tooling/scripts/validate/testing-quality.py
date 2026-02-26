#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path
from typing import Dict, List, Optional


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONTRACT_PATH = ROOT / "tooling" / "evals" / "contract.json"


def read_contract(contract_path: Path) -> Dict:
    if not contract_path.exists():
        raise FileNotFoundError(f"Contract not found: {contract_path}")
    return json.loads(contract_path.read_text(encoding="utf-8"))


def extract_section(content: str, heading_regex: str) -> Optional[str]:
    heading = re.search(heading_regex, content, flags=re.MULTILINE)
    if not heading:
        return None

    section_start = heading.end()
    next_heading = re.search(r"^##\s+", content[section_start:], flags=re.MULTILINE)
    if not next_heading:
        return content[section_start:]

    return content[section_start : section_start + next_heading.start()]


def matches_any(patterns: List[str], content: str) -> bool:
    for pattern in patterns:
        if re.search(pattern, content, flags=re.IGNORECASE | re.MULTILINE):
            return True
    return False


def count_matches(pattern: str, content: str) -> int:
    return len(re.findall(pattern, content, flags=re.IGNORECASE | re.MULTILINE))


def validate_playbook(contract: Dict, playbook: Dict) -> List[str]:
    errors: List[str] = []
    relative_path = playbook["path"]
    path = ROOT / relative_path
    if not path.exists():
        return [f"{relative_path}: file does not exist"]

    content = path.read_text(encoding="utf-8")
    heading_regex = playbook.get("section_heading_regex", r"^##\s+Testing")
    try:
        re.compile(heading_regex)
    except re.error as err:
        return [f"{relative_path}: invalid section_heading_regex: {err}"]

    section = extract_section(content, heading_regex)
    if section is None:
        return [f"{relative_path}: testing section not found (regex: {heading_regex})"]

    required_any_groups = playbook.get(
        "required_any_groups", contract.get("required_any_groups", [])
    )
    for index, group in enumerate(required_any_groups, start=1):
        if not matches_any(group, section):
            errors.append(
                f"{relative_path}: missing required concept group {index} (no match in testing section)"
            )

    required_patterns = playbook.get("required_patterns", contract.get("required_patterns", []))
    for requirement in required_patterns:
        label = requirement["label"]
        pattern = requirement["regex"]
        scope = requirement.get("scope", "section")
        min_count = int(requirement.get("min_count", 1))
        if scope not in {"section", "file"}:
            errors.append(
                f"{relative_path}: {label} (invalid scope '{scope}', expected 'section' or 'file')"
            )
            continue

        target = section if scope == "section" else content
        try:
            count = count_matches(pattern, target)
        except re.error as err:
            errors.append(
                f"{relative_path}: {label} (invalid regex /{pattern}/ for {scope} scope: {err})"
            )
            continue
        if count < min_count:
            errors.append(
                f"{relative_path}: {label} (found {count}, expected >= {min_count})"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate testing guidance quality against a JSON contract."
    )
    parser.add_argument(
        "--contract",
        default=str(DEFAULT_CONTRACT_PATH),
        help="Path to the quality contract JSON file.",
    )
    args = parser.parse_args()
    contract_path = Path(args.contract)
    if not contract_path.is_absolute():
        contract_path = ROOT / contract_path

    try:
        contract = read_contract(contract_path)
    except Exception as exc:  # pragma: no cover - CLI safety
        print(f"Failed to load contract: {exc}")
        return 1

    playbooks = contract.get("playbooks", [])
    if not playbooks:
        print("Contract has no playbooks to validate.")
        return 1

    all_errors: List[str] = []
    for playbook in playbooks:
        all_errors.extend(validate_playbook(contract, playbook))

    if all_errors:
        print("Testing quality validation failed:")
        for error in all_errors:
            print(f"- {error}")
        return 1

    print(f"Testing quality validation passed for {len(playbooks)} playbook(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
