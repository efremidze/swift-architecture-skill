# Skill Evaluation Harness

This folder provides scenario-based evaluations for `swift-architecture-skill`.

## Goal

Check whether the skill catches architecture/code smells and proposes concrete, pattern-consistent fixes.

## What You Get

- Reusable smell cases in `evals/cases/`
- Lightweight runner script: `scripts/run-skill-evals.sh`
- Manual scorecards per run
- Optional keyword-based autograding (heuristic)

## Case Format

Each case directory contains:

- `prompt.md`: the exact prompt to run
- `required_keywords.txt`: phrases expected in a good answer
- `forbidden_keywords.txt`: phrases that indicate a weak answer
- `notes.md`: what this case is testing

## Run a Batch

1. Create a run package (manual mode):

```bash
./scripts/run-skill-evals.sh
```

This creates `evals/runs/<timestamp>/...` with copied prompts and scorecards.
Fill each `response.md` with model output.

2. Optional: run with a command that reads stdin and writes stdout:

```bash
./scripts/run-skill-evals.sh --cmd "your-command-here"
```

The command is executed per case as:

```bash
bash -lc "$CMD" < prompt.md > response.md
```

3. Grade a completed run:

```bash
./scripts/run-skill-evals.sh --grade-only --run-dir evals/runs/<timestamp>
```

## Scoring Guidance

Autograde is intentionally simple and noisy. Use manual review as source of truth.

Manual scorecard (per case) focuses on:

- Smell detected accurately
- Architecture fit reasoning is coherent
- Fix steps are concrete and incremental
- Async/cancellation/error-handling guidance appears when relevant
- No hand-wavy or contradictory recommendations

## Suggested CI Gate

- Keep a baseline pass rate for keyword checks
- Require manual review on changed cases or failed keyword checks
- Track regression over time by preserving `evals/runs/` artifacts
