# Skill Evaluation Harness

This folder provides scenario-based evaluations for `swift-architecture-skill`.

## Goal

Check whether the skill catches architecture/code smells and proposes concrete, pattern-consistent fixes.

## Layout

- `.evals/cases.json`: all eval cases in one file
- `.evals/rubric.md`: manual scoring rubric
- `scripts/run-skill-evals.sh`: runner

## Case Format (`cases.json`)

Each case includes:

- `id`
- `notes`
- `prompt`
- `required_keywords`
- `forbidden_keywords`

## Run a Batch

1. Prepare a run package (manual mode):

```bash
./scripts/run-skill-evals.sh
```

This creates `.evals/runs/<timestamp>/` with:

- `packet.md` (all prompts)
- `responses/<id>.md`
- `scorecards/<id>.md`
- `cases.json` snapshot

2. Optional: run with a command that reads stdin and writes stdout:

```bash
./scripts/run-skill-evals.sh --cmd "your-command-here"
```

The command is executed per case as:

```bash
bash -lc "$CMD" < prompt_text > responses/<id>.md
```

3. Grade a completed run:

```bash
./scripts/run-skill-evals.sh --grade-only --run-dir .evals/runs/<timestamp>
```

## Scoring Guidance

Keyword scoring is a quick heuristic. Use manual scorecards as source of truth.

Manual scorecard dimensions:

- Smell detection
- Architecture fit
- Fix quality
- Safety (error/cancellation guidance)
- Clarity
