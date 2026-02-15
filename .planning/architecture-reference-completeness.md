# Architecture Reference Completeness Tracker

Last updated: 2026-02-14

## Scoring rubric

- Completeness: coverage of architecture fundamentals, practical patterns, anti-patterns, testing, and review checklist.
- Quality: correctness, clarity, copy-paste reliability of snippets, and production usefulness.
- Scale: 1 (poor) to 10 (excellent).

## Current scorecard

| Architecture | File | Completeness | Quality | Status | Priority follow-up |
|---|---|---:|---:|---|---|
| MVVM | `swift-architecture-agent/references/mvvm.md` | 9.0 | 8.5 | Good | Added "When to Prefer MVVM" section; Equatable types verified |
| MVI | `swift-architecture-agent/references/mvi.md` | 9.0 | 8.5 | Good | Added composed reducers, action reducer with failure handling, cancellable effects in Store |
| TCA | `swift-architecture-agent/references/tca.md` | 9.5 | 9.5 | Excellent | Add brief migration note for older TCA APIs if needed |
| Clean Architecture | `swift-architecture-agent/references/clean-architecture.md` | 9.0 | 9.0 | Good | Added DTO->Domain mapping, concurrency/cancellation section, test code example |
| VIPER | `swift-architecture-agent/references/viper.md` | 9.0 | 8.5 | Good | Added assembly code, concurrency/cancellation section, full presenter test suite |
| Reactive | `swift-architecture-agent/references/reactive.md` | 9.0 | 8.5 | Good | Added scheduler-injection test sample and parameterized ViewModel pattern |

## Open review notes

1. `swift-architecture-agent/references/tca.md`: `withDependencies` test pattern (lines 248-250) uses a slightly uncommon invocation style; verify against latest TCA 1.7+ API.
2. `swift-architecture-agent/references/reactive.md`: scheduler-injection test uses `DispatchQueue.test` which requires CombineSchedulers library; consider documenting this dependency.

## Definition of done for each architecture doc

- Has clear "when to use" guidance and trade-offs.
- Has canonical structure and dependency boundaries.
- Has at least one self-contained, copy-paste-friendly code path.
- Includes concurrency/cancellation guidance where applicable.
- Includes anti-patterns with fixes.
- Includes testing strategy and PR review checklist.
- Has no known syntax/compilation blockers in showcased snippets.

## Update process

When a review pass is done:

1. Update scores and status in the scorecard.
2. Add/remove items in `Open review notes`.
3. Mark any architecture as `Excellent` only when there are no known snippet correctness caveats.
