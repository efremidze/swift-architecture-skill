# Architecture Reference Completeness Tracker

Last updated: 2026-02-15

## Scoring rubric

- Completeness: coverage of architecture fundamentals, practical patterns, anti-patterns, testing, and review checklist.
- Quality: correctness, clarity, and production usefulness of guidance and snippets.
- Scale: 1 (poor) to 10 (excellent).

## Current scorecard

| Architecture | File | Completeness | Quality | Status | Priority follow-up |
|---|---|---:|---:|---|---|
| MVVM | `swift-architecture-skill/references/mvvm.md` | 9.2 | 9.1 | Excellent | Navigation/deep-link path aligned on stable IDs; guidance wording aligned with selection matrix |
| MVI | `swift-architecture-skill/references/mvi.md` | 9.2 | 9.1 | Excellent | Effect model, composition mapping, and error/cancellation guidance are coherent |
| TCA | `swift-architecture-skill/references/tca.md` | 9.5 | 9.4 | Excellent | Presentation reducer guidance (`.ifLet`) and navigation modeling are aligned |
| Clean Architecture | `swift-architecture-skill/references/clean-architecture.md` | 9.2 | 9.2 | Excellent | Layering, DTO mapping, DI, and cancellation guidance are consistent |
| VIPER | `swift-architecture-skill/references/viper.md` | 9.2 | 9.0 | Excellent | Interaction model, actor/thread guidance, and tests are aligned |
| Reactive | `swift-architecture-skill/references/reactive.md` | 9.2 | 9.1 | Excellent | Canonical pipeline, scheduler-injection testing, and fallback error handling are aligned |

## Open review notes

1. `swift-architecture-skill/references/tca.md`: keep an eye on TCA API drift in test helper style (`withDependencies`) on future package upgrades.

## Definition of done for each architecture doc

- Has clear "when to use" guidance and trade-offs.
- Has canonical structure and dependency boundaries.
- Has at least one clear, self-contained reference code path.
- Includes concurrency/cancellation guidance where applicable.
- Includes anti-patterns with fixes.
- Includes testing strategy and PR review checklist.
- Has no known misleading architectural guidance or contradictory examples.

## Update process

When a review pass is done:

1. Update scores and status in the scorecard.
2. Add/remove items in `Open review notes`.
3. Mark any architecture as `Excellent` only when there are no known guidance correctness caveats.
