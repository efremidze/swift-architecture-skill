# Architecture Selection Guide

Use this reference when the user does not specify an architecture or asks for a recommendation. Walk through the decision factors below and recommend the best-fit pattern.

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

## Quick Decision Flow

```text
1. Is the feature stream-heavy (search, live feeds, real-time updates)?
   YES -> Consider Reactive (references/reactive.md)
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

When inferring architecture, look for these signals in the user's request:

### Signals pointing to MVVM
- "simple feature", "screen-level state", "standard iOS pattern"
- Small to medium feature scope with no complex state machines
- Team is new to iOS or prefers low ceremony

### Signals pointing to MVI
- "state machine", "deterministic transitions", "unidirectional"
- Complex multi-step workflows (checkout, onboarding)
- Need to replay or serialize state

### Signals pointing to TCA
- "composable", "TestStore", "pointfree", mentions of TCA
- Existing TCA codebase or explicit desire for TCA
- Need strong composition across many child features

### Signals pointing to Clean Architecture
- "layers", "use cases", "dependency rule", "hexagonal"
- Large team needing stable module boundaries
- Infrastructure replacement or multi-platform sharing is a goal

### Signals pointing to VIPER
- "module", "router", "presenter", legacy UIKit codebase
- Large existing UIKit app with navigation complexity
- Strict role separation is a team requirement

### Signals pointing to Reactive
- "streams", "Combine", "RxSwift", "real-time", "search"
- Feature is event-pipeline driven (typeahead, WebSocket feeds)
- Team already uses Combine or RxSwift extensively

## Combining Architectures

Some projects use multiple patterns. Common valid combinations:

- **MVVM + Reactive**: MVVM structure with Combine/Rx pipelines inside ViewModels
- **Clean Architecture + MVVM**: Clean layers for domain/data, MVVM for presentation
- **Clean Architecture + TCA**: Clean layers for domain/data, TCA for feature presentation
- **VIPER + Reactive**: VIPER module structure with reactive Interactors

When combining, clarify which pattern governs which layer and keep boundaries consistent.

## Recommendation Format

When recommending an architecture, provide:

1. The recommended pattern and a one-sentence justification
2. Load the corresponding reference file
3. If the choice is close between two patterns, briefly explain the trade-off
4. Apply the selected playbook to the user's specific feature context
