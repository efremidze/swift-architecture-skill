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
