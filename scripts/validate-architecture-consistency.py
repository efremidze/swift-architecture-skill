#!/usr/bin/env python3
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple


ROOT = Path(__file__).resolve().parents[1]
REFERENCES_DIR = ROOT / "swift-architecture-skill" / "references"
SKILL_PATH = ROOT / "swift-architecture-skill" / "SKILL.md"
SELECTION_GUIDE_PATH = REFERENCES_DIR / "selection-guide.md"
README_PATH = ROOT / "README.md"
QUALITY_CONTRACT_PATH = ROOT / "quality" / "testing-quality-contract.json"


SELECTION_HEADER_TO_SLUG: Dict[str, str] = {
    "MVVM": "mvvm",
    "MVI": "mvi",
    "TCA": "tca",
    "Clean": "clean-architecture",
    "VIPER": "viper",
    "Reactive": "reactive",
}

README_NAME_TO_SLUG: Dict[str, str] = {
    "MVVM": "mvvm",
    "MVI": "mvi",
    "TCA": "tca",
    "Clean Architecture": "clean-architecture",
    "VIPER": "viper",
    "Reactive": "reactive",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def expected_reference_slugs() -> Set[str]:
    slugs = {
        p.stem
        for p in REFERENCES_DIR.glob("*.md")
        if p.stem != "selection-guide"
    }
    return slugs


def parse_skill_mapping_slugs(skill_text: str) -> Set[str]:
    pattern = re.compile(
        r"^- [^`]+?\s*(?:→|->)\s*`references/([a-z0-9-]+)\.md`$",
        flags=re.MULTILINE,
    )
    return set(pattern.findall(skill_text))


def parse_selection_matrix_slugs(selection_text: str) -> Tuple[Set[str], List[str]]:
    errors: List[str] = []
    matrix_line = None
    for line in selection_text.splitlines():
        if line.startswith("| Factor |"):
            matrix_line = line
            break

    if matrix_line is None:
        return set(), ["selection-guide.md: decision matrix header line not found"]

    parts = [part.strip() for part in matrix_line.split("|") if part.strip()]
    if len(parts) < 2:
        return set(), ["selection-guide.md: invalid decision matrix header format"]

    header_slugs: Set[str] = set()
    for header in parts[1:]:
        if header not in SELECTION_HEADER_TO_SLUG:
            errors.append(f"selection-guide.md: unknown matrix header '{header}'")
            continue
        header_slugs.add(SELECTION_HEADER_TO_SLUG[header])

    return header_slugs, errors


def parse_selection_flow_slugs(selection_text: str) -> Set[str]:
    return set(re.findall(r"references/([a-z0-9-]+)\.md", selection_text))


def parse_readme_supported_slugs(readme_text: str) -> Tuple[Set[str], List[str]]:
    errors: List[str] = []
    matches = re.findall(r"^- \*\*(.+?)\*\* -", readme_text, flags=re.MULTILINE)
    slugs: Set[str] = set()
    for name in matches:
        if name not in README_NAME_TO_SLUG:
            continue
        slugs.add(README_NAME_TO_SLUG[name])

    missing_named = set(README_NAME_TO_SLUG.keys()) - set(matches)
    if missing_named:
        errors.append(
            "README.md: missing supported architecture entries for "
            + ", ".join(sorted(missing_named))
        )

    return slugs, errors


def parse_quality_contract_slugs(contract_text: str) -> Set[str]:
    return set(
        re.findall(
            r"swift-architecture-skill/references/([a-z0-9-]+)\.md",
            contract_text,
        )
    )


def compare_sets(label: str, actual: Set[str], expected: Set[str]) -> List[str]:
    errors: List[str] = []
    missing = expected - actual
    extra = actual - expected
    if missing:
        errors.append(f"{label}: missing {sorted(missing)}")
    if extra:
        errors.append(f"{label}: unexpected {sorted(extra)}")
    return errors


def main() -> int:
    expected = expected_reference_slugs()
    errors: List[str] = []

    skill_mapping = parse_skill_mapping_slugs(read_text(SKILL_PATH))
    errors.extend(compare_sets("SKILL.md architecture mapping", skill_mapping, expected))

    selection_text = read_text(SELECTION_GUIDE_PATH)
    matrix_slugs, matrix_errors = parse_selection_matrix_slugs(selection_text)
    errors.extend(matrix_errors)
    errors.extend(compare_sets("selection-guide matrix headers", matrix_slugs, expected))

    flow_slugs = parse_selection_flow_slugs(selection_text)
    errors.extend(compare_sets("selection-guide decision flow references", flow_slugs, expected))

    readme_slugs, readme_errors = parse_readme_supported_slugs(read_text(README_PATH))
    errors.extend(readme_errors)
    errors.extend(compare_sets("README supported architectures", readme_slugs, expected))

    contract_slugs = parse_quality_contract_slugs(read_text(QUALITY_CONTRACT_PATH))
    errors.extend(compare_sets("testing quality contract playbooks", contract_slugs, expected))

    if errors:
        print("Architecture consistency validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Architecture consistency validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
