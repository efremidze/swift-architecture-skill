#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES_FILE="$ROOT_DIR/.evals/cases.json"
RUNS_DIR="$ROOT_DIR/.evals/runs"
RUN_DIR=""
CMD=""
GRADE_ONLY=0

usage() {
  cat <<USAGE
Usage:
  ./scripts/run-skill-evals.sh [--cmd "<command>"] [--run-dir <path>]
  ./scripts/run-skill-evals.sh --grade-only --run-dir <path>

Options:
  --cmd         Command that reads prompt from stdin and writes response to stdout.
                Example: --cmd "codex run --model gpt-5"
  --run-dir     Existing run directory. If omitted, a new timestamped run is created.
  --grade-only  Skip setup/run and only score an existing run directory.
  -h, --help    Show this help message.
USAGE
}

create_scorecard() {
  local file="$1"
  local case_id="$2"

  cat > "$file" <<SCORE
# Scorecard: $case_id

Use \`.evals/rubric.md\` for definitions.

- [ ] \`smell_detection\` (0/1)
- [ ] \`architecture_fit\` (0/1)
- [ ] \`fix_quality\` (0/1)
- [ ] \`safety\` (0/1)
- [ ] \`clarity\` (0/1)

## Notes

- 
SCORE
}

build_packet() {
  local cases_path="$1"
  local packet_path="$2"

  {
    echo "# Eval Packet"
    echo
    echo "Use these prompts to collect responses for each case."
    echo
    jq -r '.cases[] | "## " + .id + "\n\n### Notes\n" + .notes + "\n### Prompt\n```text\n" + .prompt + "\n```\n"' "$cases_path"
  } > "$packet_path"
}

match_keyword() {
  local keyword="$1"
  local response_file="$2"
  grep -qiF -- "$keyword" "$response_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cmd)
      [[ $# -lt 2 ]] && { echo "Missing value for --cmd" >&2; exit 1; }
      CMD="$2"
      shift 2
      ;;
    --run-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --run-dir" >&2; exit 1; }
      RUN_DIR="$2"
      shift 2
      ;;
    --grade-only)
      GRADE_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if [[ ! -f "$CASES_FILE" ]]; then
  echo "Cases file not found: $CASES_FILE" >&2
  exit 1
fi

if [[ "$GRADE_ONLY" -eq 0 ]]; then
  if [[ -z "$RUN_DIR" ]]; then
    RUN_DIR="$RUNS_DIR/$(date +%Y%m%d-%H%M%S)"
  fi

  mkdir -p "$RUN_DIR/responses" "$RUN_DIR/scorecards"
  cp "$CASES_FILE" "$RUN_DIR/cases.json"
  build_packet "$RUN_DIR/cases.json" "$RUN_DIR/packet.md"

  while IFS= read -r case_id; do
    response_file="$RUN_DIR/responses/$case_id.md"
    scorecard_file="$RUN_DIR/scorecards/$case_id.md"

    : > "$response_file"
    create_scorecard "$scorecard_file" "$case_id"

    if [[ -n "$CMD" ]]; then
      prompt_text="$(jq -r --arg id "$case_id" '.cases[] | select(.id == $id) | .prompt' "$RUN_DIR/cases.json")"
      if ! printf '%s' "$prompt_text" | bash -lc "$CMD" > "$response_file"; then
        echo "Command failed for case '$case_id'." >&2
        echo "[Runner error] Command failed for this case." > "$response_file"
      fi
    fi
  done < <(jq -r '.cases[].id' "$RUN_DIR/cases.json")

  echo "Prepared run: $RUN_DIR"
  if [[ -z "$CMD" ]]; then
    echo "No --cmd provided. Fill files in responses/, then re-run with --grade-only."
  fi
fi

if [[ -z "$RUN_DIR" ]]; then
  echo "--run-dir is required for grading." >&2
  exit 1
fi

if [[ ! -d "$RUN_DIR" ]]; then
  echo "Run directory not found: $RUN_DIR" >&2
  exit 1
fi

run_cases_file="$RUN_DIR/cases.json"
if [[ ! -f "$run_cases_file" ]]; then
  echo "Run has no cases.json; using current .evals/cases.json for grading." >&2
  run_cases_file="$CASES_FILE"
fi

summary_file="$RUN_DIR/summary.tsv"
printf "case\trequired_hits\trequired_total\tforbidden_hits\tforbidden_total\tkeyword_pass\n" > "$summary_file"

total_cases=0
pass_cases=0

while IFS= read -r case_json; do
  case_id="$(jq -r '.id' <<< "$case_json")"
  response_file="$RUN_DIR/responses/$case_id.md"

  # Backward compatibility with legacy run layout.
  if [[ ! -f "$response_file" && -f "$RUN_DIR/$case_id/response.md" ]]; then
    response_file="$RUN_DIR/$case_id/response.md"
  fi

  [[ -f "$response_file" ]] || : > "$response_file"

  req_hits=0
  req_total=0
  forb_hits=0
  forb_total=0

  # Preferred mode: required_any is an array of checks, where each check is either:
  # - a single string
  # - an array of equivalent phrases (any-of match)
  # Backward compatible fallback: required_keywords (all-of single terms).
  if jq -e '.required_any? | type == "array" and length > 0' >/dev/null <<< "$case_json"; then
    while IFS= read -r group_json; do
      req_total=$((req_total + 1))
      group_hit=0

      if jq -e 'type == "array"' >/dev/null <<< "$group_json"; then
        while IFS= read -r keyword; do
          if match_keyword "$keyword" "$response_file"; then
            group_hit=1
            break
          fi
        done < <(jq -r '.[]' <<< "$group_json")
      elif jq -e 'type == "string"' >/dev/null <<< "$group_json"; then
        keyword="$(jq -r '.' <<< "$group_json")"
        if match_keyword "$keyword" "$response_file"; then
          group_hit=1
        fi
      fi

      req_hits=$((req_hits + group_hit))
    done < <(jq -c '.required_any[]' <<< "$case_json")
  else
    while IFS= read -r keyword; do
      req_total=$((req_total + 1))
      if match_keyword "$keyword" "$response_file"; then
        req_hits=$((req_hits + 1))
      fi
    done < <(jq -r '.required_keywords[]?' <<< "$case_json")
  fi

  # Optional forbidden_any supports grouped any-of forbidden matches.
  if jq -e '.forbidden_any? | type == "array" and length > 0' >/dev/null <<< "$case_json"; then
    while IFS= read -r group_json; do
      forb_total=$((forb_total + 1))
      group_hit=0

      if jq -e 'type == "array"' >/dev/null <<< "$group_json"; then
        while IFS= read -r keyword; do
          if match_keyword "$keyword" "$response_file"; then
            group_hit=1
            break
          fi
        done < <(jq -r '.[]' <<< "$group_json")
      elif jq -e 'type == "string"' >/dev/null <<< "$group_json"; then
        keyword="$(jq -r '.' <<< "$group_json")"
        if match_keyword "$keyword" "$response_file"; then
          group_hit=1
        fi
      fi

      forb_hits=$((forb_hits + group_hit))
    done < <(jq -c '.forbidden_any[]' <<< "$case_json")
  else
    while IFS= read -r keyword; do
      forb_total=$((forb_total + 1))
      if match_keyword "$keyword" "$response_file"; then
        forb_hits=$((forb_hits + 1))
      fi
    done < <(jq -r '.forbidden_keywords[]?' <<< "$case_json")
  fi

  keyword_pass=0
  if [[ "$req_total" -gt 0 && "$req_hits" -eq "$req_total" && "$forb_hits" -eq 0 ]]; then
    keyword_pass=1
    pass_cases=$((pass_cases + 1))
  fi

  total_cases=$((total_cases + 1))

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$case_id" \
    "$req_hits" \
    "$req_total" \
    "$forb_hits" \
    "$forb_total" \
    "$keyword_pass" >> "$summary_file"
done < <(jq -c '.cases[]' "$run_cases_file")

echo "Wrote: $summary_file"
echo "Keyword pass: $pass_cases/$total_cases"
echo "Use scorecards/ + .evals/rubric.md for final manual verdict."
