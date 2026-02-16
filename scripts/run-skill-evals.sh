#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASES_DIR="$ROOT_DIR/evals/cases"
RUNS_DIR="$ROOT_DIR/evals/runs"
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

trim_line() {
  local line="$1"
  # Remove leading whitespace.
  line="${line#"${line%%[![:space:]]*}"}"
  # Remove trailing whitespace.
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

parse_keywords_file() {
  local file="$1"
  local response_file="$2"
  local mode="$3"
  local total=0
  local hits=0

  if [[ ! -f "$file" ]]; then
    printf '0 0\n'
    return
  fi

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    local line
    line="$(trim_line "$raw")"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    total=$((total + 1))
    if grep -qiF -- "$line" "$response_file"; then
      hits=$((hits + 1))
    fi
  done < "$file"

  if [[ "$mode" == "required" ]]; then
    printf '%s %s\n' "$hits" "$total"
  else
    printf '%s %s\n' "$hits" "$total"
  fi
}

create_scorecard() {
  local file="$1"

  cat > "$file" <<'SCORE'
# Scorecard

Use `evals/rubric.md` for definitions.

- [ ] `smell_detection` (0/1)
- [ ] `architecture_fit` (0/1)
- [ ] `fix_quality` (0/1)
- [ ] `safety` (0/1)
- [ ] `clarity` (0/1)

## Notes

- 
SCORE
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

if [[ "$GRADE_ONLY" -eq 0 ]]; then
  if [[ -z "$RUN_DIR" ]]; then
    RUN_DIR="$RUNS_DIR/$(date +%Y%m%d-%H%M%S)"
  fi

  mkdir -p "$RUN_DIR"

  for case_dir in "$CASES_DIR"/*; do
    [[ -d "$case_dir" ]] || continue
    case_id="$(basename "$case_dir")"
    out_dir="$RUN_DIR/$case_id"
    mkdir -p "$out_dir"

    cp "$case_dir/prompt.md" "$out_dir/prompt.md"
    cp "$case_dir/notes.md" "$out_dir/notes.md"
    cp "$case_dir/required_keywords.txt" "$out_dir/required_keywords.txt"
    cp "$case_dir/forbidden_keywords.txt" "$out_dir/forbidden_keywords.txt"
    : > "$out_dir/response.md"
    create_scorecard "$out_dir/scorecard.md"

    if [[ -n "$CMD" ]]; then
      if ! bash -lc "$CMD" < "$out_dir/prompt.md" > "$out_dir/response.md"; then
        echo "Command failed for case '$case_id'." >&2
        echo "[Runner error] Command failed for this case." > "$out_dir/response.md"
      fi
    fi
  done

  echo "Prepared run: $RUN_DIR"
  if [[ -z "$CMD" ]]; then
    echo "No --cmd provided. Fill each response.md manually, then re-run with --grade-only."
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

summary_file="$RUN_DIR/summary.tsv"
printf "case\trequired_hits\trequired_total\tforbidden_hits\tforbidden_total\tkeyword_pass\n" > "$summary_file"

total_cases=0
pass_cases=0

for case_dir in "$RUN_DIR"/*; do
  [[ -d "$case_dir" ]] || continue

  response_file="$case_dir/response.md"
  required_file="$case_dir/required_keywords.txt"
  forbidden_file="$case_dir/forbidden_keywords.txt"

  [[ -f "$response_file" ]] || : > "$response_file"

  read -r req_hits req_total < <(parse_keywords_file "$required_file" "$response_file" "required")
  read -r forb_hits forb_total < <(parse_keywords_file "$forbidden_file" "$response_file" "forbidden")

  keyword_pass=0
  if [[ "$req_total" -gt 0 && "$req_hits" -eq "$req_total" && "$forb_hits" -eq 0 ]]; then
    keyword_pass=1
    pass_cases=$((pass_cases + 1))
  fi

  total_cases=$((total_cases + 1))

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(basename "$case_dir")" \
    "$req_hits" \
    "$req_total" \
    "$forb_hits" \
    "$forb_total" \
    "$keyword_pass" >> "$summary_file"
done

echo "Wrote: $summary_file"
echo "Keyword pass: $pass_cases/$total_cases"
echo "Use scorecard.md files + evals/rubric.md for final manual verdict."
