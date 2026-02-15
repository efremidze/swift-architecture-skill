# Architecture Selection Guide

Use this reference when the user asks for an architecture recommendation.

## Decision Matrix

| Factor | MVVM | MVI | TCA | Clean | VIPER | Reactive |
|--------|------|-----|-----|-------|-------|----------|
| State complexity | Low–Med | High | High | Med–High | Med | Med |
| Unidirectional flow | Optional | Strict | Strict | N/A | N/A | Stream-based |
| Composition / modularity | Feature-level | Feature-level | Strong (Scope/forEach) | Layer-level | Module-level | Operator-level |
| Testing determinism | Good | Very high | Very high (TestStore) | Good | Good | Good (with schedulers) |
| Boilerplate | Low | Medium | Medium–High | Medium–High | High | Low–Medium |
| SwiftUI fit | Excellent | Good | Excellent | Good | Fair (UIKit-native) | Good |
| UIKit fit | Good | Good | Good | Good | Excellent | Good |
| Team learning curve | Low | Medium | High | Medium | Medium–High | Medium |
| Async/effect orchestration | Manual | Structured | Built-in | Manual | Manual | Operator-driven |
| Framework dependency | None | None | swift-composable-architecture | None | None | Combine or RxSwift |

## UI Stack Nuance by Architecture

- **MVVM**: SwiftUI favors direct state binding; UIKit/mixed favors coordinator-driven navigation.
- **MVI**: SwiftUI uses store-bound views; UIKit maps events to intents and renders from store state.
- **TCA**: SwiftUI uses `StoreOf` in views; UIKit uses a controller render loop from `ViewStore`.
- **Clean Architecture**: Domain/data stay the same; only presentation adapters differ.
- **VIPER**: UIKit-native fit; SwiftUI usually uses an adapter plus `UIHostingController`.
- **Reactive**: SwiftUI keeps pipelines in observable models; UIKit keeps them in presenter/view model.

## Quick Decision Flow

```text
1. Is the feature stream-heavy (search, live feeds, real-time updates)?
   YES -> Consider Reactive (references/reactive.md). If strict reducer/state-machine flow is also required, continue to step 2 and likely combine patterns.
   NO  -> Continue

2. Is strict unidirectional data flow and state-machine modeling required?
   YES -> Is the app already TCA-based, or is adding TCA dependency acceptable?
          YES -> TCA (references/tca.md)
          NO  -> MVI (references/mvi.md)
   NO  -> Continue

3. Does the codebase need strict layer isolation with replaceable infrastructure?
   YES -> Clean Architecture (references/clean-architecture.md)
   NO  -> Continue

4. Is this a large UIKit codebase needing strict per-feature separation?
   YES -> VIPER (references/viper.md)
   NO  -> Continue

5. Default recommendation:
   -> MVVM (references/mvvm.md)
```

## Inference from User Constraints

Use these request signals:

### Signals pointing to MVVM
- "simple feature", "screen-level state", "standard iOS pattern"
- small/medium feature without strict state-machine needs

### Signals pointing to MVI
- "state machine", "deterministic transitions", "unidirectional"
- need to replay/serialize state transitions

### Signals pointing to TCA
- "composable", "TestStore", "pointfree", mentions of TCA
- existing TCA codebase or strong child-feature composition needs

### Signals pointing to Clean Architecture
- "layers", "use cases", "dependency rule", "hexagonal"
- stable module boundaries and replaceable infrastructure are priorities

### Signals pointing to VIPER
- "module", "router", "presenter", legacy UIKit codebase
- strict role separation in large UIKit modules

### Signals pointing to Reactive
- "streams", "Combine", "RxSwift", "real-time", "search"
- feature behavior is event-pipeline driven (typeahead, WebSocket, live feeds)

## Combining Architectures

Some projects use multiple patterns. Common valid combinations:

- **MVVM + Reactive**: MVVM structure with Combine/Rx pipelines inside ViewModels
- **Clean Architecture + MVVM**: Clean layers for domain/data, MVVM for presentation
- **Clean Architecture + TCA**: Clean layers for domain/data, TCA for feature presentation
- **VIPER + Reactive**: VIPER module structure with reactive Interactors

When combining, clarify which pattern governs which layer and keep boundaries consistent.

## Recommendation Format

When recommending:

1. Name one pattern and justify it in one sentence.
2. Cite the reference file.
3. If close call, note the trade-off briefly.
4. Apply the playbook to the user’s feature.
