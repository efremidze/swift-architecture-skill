# Architecture Reference Completeness Tracker

Last updated: 2026-02-14

## Scoring rubric

- Completeness: coverage of architecture fundamentals, practical patterns, anti-patterns, testing, and review checklist.
- Quality: correctness, clarity, copy-paste reliability of snippets, and production usefulness.
- Scale: 1 (poor) to 10 (excellent).

## Current scorecard

| Architecture | File | Completeness | Quality | Status | Priority follow-up |
|---|---|---:|---:|---|---|
| MVVM | `swift-architecture-agent/references/mvvm.md` | 8.5 | 8.5 | Good | Ensure example types used by `FeedState: Equatable` are explicitly Equatable or document requirement |
| MVI | `swift-architecture-agent/references/mvi.md` | 8.0 | 8.0 | Good | Add composed reducer examples and richer failure/cancellation handling snippet |
| TCA | `swift-architecture-agent/references/tca.md` | 9.5 | 9.5 | Excellent | Add brief migration note for older TCA APIs if needed |
| Clean Architecture | `swift-architecture-agent/references/clean-architecture.md` | 8.0 | 8.5 | Good | Add concrete adapter/mapping example (DTO -> Domain) |
| VIPER | `swift-architecture-agent/references/viper.md` | 7.5 | 8.0 | Fair-Good | Expand assembly/wiring and module test examples |
| Reactive | `swift-architecture-agent/references/reactive.md` | 8.0 | 8.0 | Good | Make error-handling snippet fully self-contained and add scheduler-injection test sample |

## Open review notes

1. `swift-architecture-agent/references/mvvm.md`: `FeedState` claims `Equatable`; verify/document `FeedItemViewData` and `ToastState` equatability assumptions.
2. `swift-architecture-agent/references/reactive.md`: error-handling example references undeclared sample symbols (`query`, `ResultState`) and should be made standalone.

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
