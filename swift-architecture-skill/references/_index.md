# Reference Index

Quick navigation for the Swift Architecture skill.

## Core Routing

| File | Use it for |
|---|---|
| `selection-guide.md` | choosing the best-fit architecture from user constraints |
| `mvvm.md` | low-to-medium complexity features with lightweight state binding |
| `mvi.md` | reducer-style state machines without adding a framework dependency |
| `tca.md` | complex, highly composable features with strict effect orchestration |
| `clean-architecture.md` | strict layer boundaries and replaceable infrastructure |
| `viper.md` | large UIKit modules needing explicit role separation |
| `reactive.md` | Combine or RxSwift stream-heavy features and event pipelines |
| `mvp.md` | UIKit-first passive views with presenter-driven rendering |
| `coordinator.md` | decoupled navigation flows and deep-linkable screen orchestration |

## Start Here Defaults

- If constraints are unclear: start with `selection-guide.md`.
- If single-feature SwiftUI/UIKit state handling is primary: start with `mvvm.md`.
- If strict state-machine determinism is primary: start with `mvi.md` (or `tca.md` if TCA is accepted).
- If navigation flow ownership is primary: start with `coordinator.md`.

## Common Combination Paths

- `mvvm.md` + `coordinator.md` for screen-state + flow separation
- `mvvm.md` + `reactive.md` for state binding + stream-heavy event handling
- `clean-architecture.md` + `mvvm.md` for layered domain/data + lightweight presentation
- `clean-architecture.md` + `tca.md` for layered domain/data + strict reducer-driven presentation
- `mvp.md` + `coordinator.md` for passive-view UIKit modules with decoupled navigation

## Problem Router

- "I need help choosing an architecture" → `selection-guide.md`
- "The feature is simple and screen-scoped" → `mvvm.md`
- "I want deterministic state transitions without TCA" → `mvi.md`
- "The feature has complex state, child composition, and strict effects" → `tca.md`
- "I need use cases, repositories, and clean boundaries" → `clean-architecture.md`
- "This is a large UIKit module with clear presenter/interactor/router roles" → `viper.md`
- "The problem is stream-heavy or driven by Combine/RxSwift" → `reactive.md`
- "I want a passive UIKit view with a presenter" → `mvp.md`
- "The main issue is navigation flow and screen coordination" → `coordinator.md`
