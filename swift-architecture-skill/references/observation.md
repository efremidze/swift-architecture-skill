# Observation Model: `@Observable` vs `ObservableObject` (Shared)

Cross-cutting guidance for SwiftUI state observation. It applies to every playbook that exposes observable presentation state (MVVM ViewModels, MVI stores, Reactive models, MVP/VIPER SwiftUI adapters, TCA views).

The minimum deployment target determines which observation mechanism to use. This affects SwiftUI wiring in every architecture:

| Factor | `@Observable` (iOS 17+) | `ObservableObject` (iOS 14–16) |
|--------|--------------------------|-------------------------------|
| Import | `import Observation` (re-exported by `import SwiftUI`) | `import Combine` (re-exported by `import SwiftUI`) |
| Property tracking | Fine-grained (per-property) | Coarse (any `@Published` change re-renders) |
| View ownership | `@State` | `@StateObject` |
| Binding access | `@Bindable` | `@ObservedObject` / `$property` |
| Combine interop | Manual (wrap with `Publisher`) | Native (`$property` is a publisher) |
| UIKit integration | Observe with `withObservationTracking` or use KVO bridge | Subscribe to `objectWillChange` or `@Published` publishers |
| TCA | Uses `@ObservableState` macro (built on Observation) | Older `ViewStore`-based API |

**When to use `@Observable`:**
- iOS 17+ deployment target
- SwiftUI-first features where fine-grained re-rendering matters
- New code without existing Combine subscriber chains

**When to keep `ObservableObject`:**
- iOS 16 or earlier deployment target
- Existing UIKit code subscribing to `@Published` properties via Combine
- Shared models that expose publishers to multiple consumers
- Gradual migration: keep `ObservableObject` on existing types, use `@Observable` on new types
