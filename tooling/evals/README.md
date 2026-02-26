# Skill Evaluation Harness

This folder provides scenario-based evaluations for `swift-architecture-skill`.

## Goal

Check whether the skill catches architecture/code smells and proposes concrete, pattern-consistent fixes.

## Layout

- `tooling/evals/cases.json`: all eval cases in one file
- `tooling/evals/rubric.md`: manual scoring rubric
- `tooling/scripts/run/evals.sh`: runner

## Case Format (`cases.json`)

Each case includes:

- `id`
- `notes`
- `prompt`
- `required_keywords` (legacy all-of keywords)
- `required_any` (optional grouped any-of checks; preferred)
- `forbidden_keywords`
- `forbidden_any` (optional grouped any-of checks)

## Run a Batch

1. Prepare a run package (manual mode):

```bash
./tooling/scripts/run/evals.sh
```

This creates `tooling/evals/runs/<timestamp>/` with:

- `packet.md` (all prompts)
- `responses/<id>.md`
- `scorecards/<id>.md`
- `cases.json` snapshot

2. Optional: run with a command that reads stdin and writes stdout:

```bash
./tooling/scripts/run/evals.sh --cmd "your-command-here"
```

The command is executed per case as:

```bash
bash -lc "$CMD" < prompt_text > responses/<id>.md
```

3. Grade a completed run:

```bash
./tooling/scripts/run/evals.sh --grade-only --run-dir tooling/evals/runs/<timestamp>
```

## Scoring Guidance

Keyword scoring is a quick heuristic. Use manual scorecards as source of truth.

Manual scorecard dimensions:

- Smell detection
- Architecture fit
- Fix quality
- Safety (error/cancellation guidance)
- Clarity
