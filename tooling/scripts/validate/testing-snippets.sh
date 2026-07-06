#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
MODE="all"
PLAYBOOK_DIR="$ROOT_DIR/swift-architecture-skill/references"

usage() {
  cat <<USAGE
Usage:
  ./tooling/scripts/validate/testing-snippets.sh [--all|--testing-only] [playbook-dir]

Options:
  --all           Parse every Swift code fence. Default.
  --testing-only  Parse only Swift fences under Testing sections.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --testing-only)
      MODE="testing"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      PLAYBOOK_DIR="$1"
      shift
      ;;
  esac
done

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc not found; skipping Swift snippet validation."
  exit 0
fi

if [[ ! -d "$PLAYBOOK_DIR" ]]; then
  echo "Playbook directory not found: $PLAYBOOK_DIR"
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

total_blocks=0
failed_blocks=0

while IFS= read -r file; do
  in_target_section=0
  in_swift_block=0
  block_index=0
  current_block_file=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$MODE" == "all" ]]; then
      in_target_section=1
    elif [[ "$in_target_section" -eq 0 && "$line" =~ ^##[[:space:]]+Testing ]]; then
      in_target_section=1
      continue
    fi

    if [[ "$MODE" == "testing" && "$in_target_section" -eq 1 && "$line" =~ ^##[[:space:]] && ! "$line" =~ ^##[[:space:]]+Testing ]]; then
      if [[ "$in_swift_block" -eq 1 ]]; then
        echo "Unclosed Swift fence in target section: $file"
        failed_blocks=$((failed_blocks + 1))
        in_swift_block=0
      fi
      in_target_section=0
    fi

    if [[ "$in_target_section" -eq 0 ]]; then
      continue
    fi

    if [[ "$in_swift_block" -eq 0 && "$line" =~ ^\`\`\`swift ]]; then
      in_swift_block=1
      block_index=$((block_index + 1))
      current_block_file="$tmp_dir/$(basename "$file" .md)-swift-$block_index.swift"
      : > "$current_block_file"
      continue
    fi

    if [[ "$in_swift_block" -eq 1 && "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      in_swift_block=0
      total_blocks=$((total_blocks + 1))

      filtered_file="$current_block_file.filtered.swift"
      sed '/^[[:space:]]*import[[:space:]]\+/d' "$current_block_file" > "$filtered_file"

      if ! swiftc -frontend -parse "$filtered_file" >/dev/null 2>"$filtered_file.err"; then
        echo "Swift syntax check failed: $file (Swift block $block_index)"
        sed 's/^/  /' "$filtered_file.err"
        failed_blocks=$((failed_blocks + 1))
      fi

      continue
    fi

    if [[ "$in_swift_block" -eq 1 ]]; then
      printf '%s\n' "$line" >> "$current_block_file"
    fi
  done < "$file"

  if [[ "$in_swift_block" -eq 1 ]]; then
    in_swift_block=0
    total_blocks=$((total_blocks + 1))

    filtered_file="$current_block_file.filtered.swift"
    sed '/^[[:space:]]*import[[:space:]]\+/d' "$current_block_file" > "$filtered_file"

    if ! swiftc -frontend -parse "$filtered_file" >/dev/null 2>"$filtered_file.err"; then
      echo "Unclosed Swift fence at end of file: $file"
      sed 's/^/  /' "$filtered_file.err"
      failed_blocks=$((failed_blocks + 1))
    fi
  fi
done < <(find "$PLAYBOOK_DIR" -name "*.md" | sort)

if [[ "$total_blocks" -eq 0 ]]; then
  echo "No Swift snippets found."
  exit 1
fi

if [[ "$failed_blocks" -gt 0 ]]; then
  echo "Validated $total_blocks Swift snippet(s); $failed_blocks failed."
  exit 1
fi

echo "Validated $total_blocks Swift snippet(s) successfully."
