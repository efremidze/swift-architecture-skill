# MVVM Playbook (Swift + SwiftUI/UIKit)

Use this reference when the request is explicitly MVVM or when screen-level state and async effects need clear separation and test seams.

## Core Boundaries

- Model: Domain entities and business rules. Keep UI-framework independent.
- View: Render state and forward user intents. Do not call services directly.
- ViewModel: Own presentation state, map domain to view data, coordinate effects.
- Services/Repositories: Side-effect boundaries (network, persistence, analytics).

Dependency direction:
- View -> ViewModel
- ViewModel -> UseCases/Repositories/Services (via protocols)
- Model -> no dependency on View/ViewModel

## Feature Structure

Prefer vertical feature slices with clear boundaries:

```text
App/
  Features/
    Feed/
      FeedView.swift
      FeedViewModel.swift
      FeedState.swift
      FeedViewData.swift
      FeedAssembly.swift
Domain/
  Entities/
  UseCases/
Data/
  Repositories/
  API/
  Persistence/
```

## State Modeling

Use explicit state types over boolean combinations.

```swift
enum Loadable<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

struct FeedItemViewData: Identifiable, Equatable {
    let id: UUID
    let title: String
}

struct ToastState: Equatable {
    let message: String
}

struct FeedState: Equatable {
    var load: Loadable<Void> = .idle
    var items: [FeedItemViewData] = []
    var isRefreshing = false
    var toast: ToastState?
}
```

## ViewModel Pattern

Keep mutation on main actor, own task handles, and cancel stale work.

### Modern Pattern (iOS 17+ / `@Observable`)

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()

    private let repository: FeedRepository
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func onAppear() {
        guard case .idle = state.load else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        state.load = .loading

        loadTask = Task {
            do {
                let page = try await repository.fetchPage(cursor: nil)
                try Task.checkCancellation()
                state.items = page.items.map(FeedItemViewData.init)
                state.load = .loaded(())
            } catch is CancellationError {
                // Ignore cancellation.
            } catch {
                state.load = .failed(error.localizedDescription)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
```

### Legacy Pattern (iOS 16 and earlier / `ObservableObject`)

```swift
@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var state = FeedState()

    private let repository: FeedRepository
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func onAppear() {
        guard case .idle = state.load else { return }
        load()
    }

    func load() {
        loadTask?.cancel()
        state.load = .loading

        loadTask = Task {
            do {
                let page = try await repository.fetchPage(cursor: nil)
                try Task.checkCancellation()
                state.items = page.items.map(FeedItemViewData.init)
                state.load = .loaded(())
            } catch is CancellationError {
                // Ignore cancellation.
            } catch {
                state.load = .failed(error.localizedDescription)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
```

## Dependency Injection

Inject abstractions into ViewModel constructors. Build live dependencies in feature assembly.

```swift
protocol FeedRepository {
    func fetchPage(cursor: String?) async throws -> FeedPage
}

enum FeedAssembly {
    static func makeViewModel() -> FeedViewModel {
        FeedViewModel(repository: LiveFeedRepository(api: .live))
    }
}
```

## View Guidance

- Bind to ViewModel state only.
- Keep business transforms out of `body`/`cellForRowAt`.
- Expose dedicated `ViewData` structs for formatting and display concerns.
- Keep View-local state only for transient UI details (focus, scroll position).

SwiftUI view with `@Observable` ViewModel (iOS 17+):

```swift
struct FeedView: View {
    @State var viewModel: FeedViewModel

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

SwiftUI view with `ObservableObject` ViewModel (iOS 16 and earlier):

```swift
struct FeedView: View {
    @StateObject var viewModel: FeedViewModel

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

## Anti-Patterns and Fixes

1. God ViewModel:
- Smell: networking, parsing, persistence, and state orchestration all in one class.
- Fix: extract UseCases/Repositories; keep ViewModel focused on state and intent handling.

2. Duplicate state in View and ViewModel:
- Smell: `@State var items` and `viewModel.state.items` coexist.
- Fix: one source of truth in ViewModel.

3. Stale async overwrite:
- Smell: older response replaces newer state.
- Fix: cancel in-flight task before new request and check cancellation.

4. Navigation logic inside ViewModel with UIKit types:
- Smell: direct `UINavigationController` usage in ViewModel.
- Fix: inject Router/Coordinator protocol.

5. Heavy work on main actor:
- Smell: decoding or expensive mapping in main-actor methods.
- Fix: move heavy work to non-main contexts; assign final state on main actor.

## Testing Expectations

Focus on deterministic state transitions:
- success path (`loading -> loaded`)
- failure path (`loading -> failed`)
- cancellation path (no stale overwrite)
- mapping correctness (domain -> view data)

Test strategy:
- Use protocol stubs/fakes for repositories.
- Avoid sleep-based tests; use controllable stub responses.
- If ViewModel is `@MainActor`, run assertions through `await MainActor.run`.

## When to Prefer MVVM

Prefer MVVM when:
- screen-level state management is the primary concern
- team familiarity with reactive/observable patterns is strong
- feature complexity is moderate and does not require strict unidirectional flow
- rapid iteration and low ceremony are valued

Prefer MVI/TCA when:
- deterministic state-machine modeling is required
- complex effect orchestration and cancellation correctness are critical

Prefer Clean Architecture/VIPER when:
- strict layer boundaries and use-case isolation matter more than presentation-layer simplicity

## PR Review Checklist

- View does not call services directly.
- ViewModel exposes explicit state model.
- Dependencies are injected (no app-wide singleton dependency in ViewModel).
- Async tasks have cancellation strategy.
- Domain models are not directly coupled to View rendering.
- Unit tests cover success, failure, and cancellation.
