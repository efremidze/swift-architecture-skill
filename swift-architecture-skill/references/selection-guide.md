# Architecture Selection Guide

Use this reference when the user asks for an architecture recommendation.

## Decision Matrix

| Factor | MVVM | MVI | TCA | Clean | VIPER | Reactive | MVP | Coordinator |
|--------|------|-----|-----|-------|-------|----------|-----|-------------|
| State complexity | Low–Med | High | High | Med–High | Med | Med | Low–Med | N/A (navigation layer) |
| Unidirectional flow | Optional | Strict | Strict | N/A | N/A | Stream-based | Optional | N/A |
| Composition / modularity | Feature-level | Feature-level | Strong (Scope/forEach) | Layer-level | Module-level | Operator-level | Feature-level | Flow-level |
| Testing determinism | Good | Very high | Very high (TestStore) | Good | Good | Good (with schedulers) | Good | Good |
| Boilerplate | Low | Medium | Medium–High | Medium–High | High | Low–Medium | Medium | Low–Medium |
| SwiftUI fit | Excellent | Good | Excellent | Good | Fair (UIKit-native) | Good | Fair | Good |
| UIKit fit | Good | Good | Good | Good | Excellent | Good | Excellent | Excellent |
| Team learning curve | Low | Medium | High | Medium | Medium–High | Medium | Low | Low |
| Async/effect orchestration | Manual | Structured | Built-in | Manual | Manual | Operator-driven | Manual | N/A |
| Framework dependency | None | None | swift-composable-architecture | None | None | Combine or RxSwift; optional test scheduler | None | None |

## UI Stack Nuance by Architecture

- **MVVM**: SwiftUI favors direct state binding; UIKit/mixed favors coordinator-driven navigation.
- **MVI**: SwiftUI uses store-bound views; UIKit maps events to intents and renders from store state.
- **TCA**: SwiftUI uses `StoreOf` in views; UIKit uses a controller render loop from `ViewStore`.
- **Clean Architecture**: Domain/data stay the same; only presentation adapters differ.
- **VIPER**: UIKit-native fit; SwiftUI usually uses an adapter plus `UIHostingController`.
- **Reactive**: SwiftUI keeps pipelines in observable models; UIKit keeps them in Presenter/ViewModel.
- **MVP**: UIKit-native fit; Presenter drives passive View via protocol commands; SwiftUI uses an observable adapter.
- **Coordinator**: Works with both stacks; UIKit uses `UINavigationController` wrapper; SwiftUI models navigation as value-type state bound to `NavigationStack`.

## Quick Decision Flow

```text
1. Is the feature stream-heavy (search, live feeds, real-time updates)?
   YES -> Mark Reactive (references/reactive.md) as a stream concern. Continue to choose the owning presentation/layering pattern below unless the task is only about stream composition.
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

5. Is the primary goal decoupling navigation from screens (deep linking, reusable flows)?
   YES -> Mark Coordinator (references/coordinator.md) as the flow concern. If screens also need state/presentation guidance, pair it with MVVM, MVP, TCA, or MVI below.
   NO  -> Continue

6. Is UIKit the primary stack and a fully passive View with zero logic desired?
   YES -> MVP (references/mvp.md)
   NO  -> Continue

7. Default recommendation:
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

### Signals pointing to MVP
- "passive view", "presenter drives view", "UIKit without observable state"
- migrating from MVC with minimal framework changes
- team prefers explicit command-dispatch over state binding

### Signals pointing to Coordinator
- "navigation", "deep linking", "flow", "routing", "decouple navigation"
- multiple screens need to be reused across different flows
- view controllers or ViewModels currently contain push/present calls

## Combining Architectures

Some projects use multiple patterns. Common valid combinations:

- **MVVM + Reactive**: MVVM structure with Combine/Rx pipelines inside ViewModels
- **Clean Architecture + MVVM**: Clean layers for domain/data, MVVM for presentation
- **Clean Architecture + TCA**: Clean layers for domain/data, TCA for feature presentation
- **VIPER + Reactive**: VIPER module structure with reactive Interactors
- **MVVM + Coordinator**: MVVM for screen-level state, Coordinator for navigation flows
- **MVP + Coordinator**: MVP for presentation logic, Coordinator for navigation and routing
- **Clean Architecture + MVP**: Clean layers for domain/data, MVP for presentation

Combination selection rules:
- Choose one **primary** pattern for the user's main boundary: feature state/presentation, domain layering, or navigation flow.
- Choose a **secondary** pattern only for a distinct concern such as navigation (`Coordinator`) or streams (`Reactive`).
- Coordinator is usually secondary unless the main problem is flow ownership, deep linking, or reusable navigation.
- Reactive is usually secondary when streams live inside MVVM, MVP, VIPER, MVI, or TCA presentation boundaries.
- Clean Architecture is usually primary for app/module layering, with MVVM, MVP, or TCA as the presentation pattern.
- Read both playbooks when recommending a combination, then explicitly say which files/modules each pattern owns.
- Do not recommend multiple full presentation patterns for the same feature boundary unless the task is a migration between them.

## Disqualifier Checklist

Before finalizing a recommendation, quickly disqualify poor fits:

- **Disqualify MVVM** when strict replayable state-machine behavior is required across many async branches.
- **Disqualify MVI/TCA** when feature complexity is low and delivery speed outweighs reducer/store ceremony.
- **Disqualify Clean Architecture** when the feature is small and stable boundaries/infrastructure replacement are not meaningful goals.
- **Disqualify VIPER** when module size/team scale does not justify role-heavy setup.
- **Disqualify Reactive-first** when behavior is mostly request/response with little stream composition.
- **Disqualify MVP** when SwiftUI-first binding ergonomics are a higher priority than passive-view command dispatch.
- **Disqualify Coordinator as primary** when the main problem is state/business orchestration rather than flow control.

## Migration Trigger Thresholds

Use these signals to recommend evolving architecture:

- MVVM -> MVI/TCA: repeated stale-response bugs, effect orchestration branching growth, or hard-to-reason state transitions.
- MVVM/MVP -> Coordinator: repeated duplicated routing logic across screens or deep-link expansion.
- MVP/MVVM -> VIPER: modules repeatedly blur responsibilities and team ownership boundaries.
- Presentation-only pattern -> Clean Architecture: repeated coupling to infrastructure blocks testing/replacement.
- Async-first -> Reactive-first: event pipelines (search/live feed/real-time updates) dominate feature complexity.
