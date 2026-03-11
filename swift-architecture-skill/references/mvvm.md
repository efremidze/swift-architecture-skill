# MVVM Playbook (Swift + SwiftUI/UIKit)

Use this reference for MVVM requests or screen-level state with async effects.

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

Prefer vertical feature slices with clear boundaries. Treat this layout as illustrative, not a required file checklist for every feature:

```text
App/
  Features/
    Feed/
      FeedView.swift
      FeedViewModel.swift
      FeedState.swift
      FeedViewData.swift
      FeedDestination.swift
      FeedAssembly.swift
  Navigation/
    AppRouter.swift
    DeepLink.swift
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

struct FeedItemViewData: Identifiable, Hashable {
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

// iOS 16: replace `@Observable` with `ObservableObject`, add `@Published` to `state`, and use `@StateObject` in views.

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

`FeedAssembly.makeViewModel()` keeps feature wiring obvious, but can become limiting as apps grow. A common evolution path is an app-level dependency container (composition root) that owns shared dependency graphs.

```swift
protocol AppDependencies {
    var feedRepository: FeedRepository { get }
}

struct LiveDependencies: AppDependencies {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var feedRepository: FeedRepository {
        LiveFeedRepository(api: api)
    }
}

@MainActor
final class AppContainer {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func makeFeedViewModel() -> FeedViewModel {
        FeedViewModel(repository: dependencies.feedRepository)
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
    @State private var viewModel: FeedViewModel

    init(viewModel: FeedViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

// iOS 16: replace `@State private var viewModel` with `@StateObject private var viewModel` and initialize with `StateObject(wrappedValue:)`.

## Navigation Patterns

Keep routing decisions testable and decoupled from presentation APIs: ViewModel decides *where*, routing layer decides *how*.

| Scenario | Recommended Pattern |
|---|---|
| Pure SwiftUI, linear flows | `NavigationStack` path on ViewModel |
| Sheets, alerts, confirmations | Optional state-driven presentation |
| UIKit host or mixed SwiftUI/UIKit | Coordinator protocol — see `coordinator.md` |
| Multi-step flows (onboarding, checkout) | Coordinator with child coordinators |
| Universal Links / push notifications | Deep link router + state-driven nav |

Model destinations as a `Hashable` enum. Model sheets/alerts as optional `Identifiable` state.

### SwiftUI: ViewModel-owned path (default)

```swift
enum FeedDestination: Hashable {
    case detail(id: UUID)
    case profile(userId: UUID)
    case settings
}

@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()
    var navigationPath: [FeedDestination] = []

    func didTapItem(_ item: FeedItemViewData) {
        navigationPath.append(.detail(id: item.id))
    }
}

struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.state.items) { item in
                Button(item.title) { viewModel.didTapItem(item) }
            }
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .detail(let id): FeedDetailView(viewModel: FeedDetailViewModel(itemID: id))
                case .profile(let id): ProfileView(viewModel: ProfileViewModel(userId: id))
                case .settings: SettingsView(viewModel: SettingsViewModel())
                }
            }
            .task { viewModel.onAppear() }
        }
    }
}
```

**Router-owned path:** Extract a `FeedRouter(@Observable)` that owns `path: [FeedDestination]` when `FeedState` becomes cluttered with navigation properties. ViewModel exposes `destinationForItem(_:) -> FeedDestination`; View calls `router.push(viewModel.destinationForItem(item))`.

**UIKit Coordinator:** Inject a `FeedCoordinator` protocol into the ViewModel (weak reference). Concrete `FeedFlowCoordinator` wraps `UINavigationController` and calls `pushViewController` / `present`. See `coordinator.md` for the full pattern.

**Deep Linking:** Centralize in `AppRouter.handle(_: DeepLink)`. Parse URLs to a `DeepLink` enum, then set `navigationPath` directly on the relevant ViewModel.

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
- Fix: move heavy CPU work off-main; assign final state on main actor.

```swift
// Anti-pattern: expensive mapping runs on @MainActor.
@MainActor
func load() {
    loadTask?.cancel()
    state.load = .loading

    loadTask = Task {
        do {
            let page = try await repository.fetchPage(cursor: nil)
            state.items = page.items.map(FeedItemViewData.init) // can hitch UI for large pages
            state.load = .loaded(())
        } catch is CancellationError {
            // Ignore cancellation.
        } catch {
            state.load = .failed(error.localizedDescription)
        }
    }
}

// Better: do CPU-heavy mapping off actor, then commit state on @MainActor.
@MainActor
func load() {
    loadTask?.cancel()
    state.load = .loading

    loadTask = Task {
        do {
            let page = try await repository.fetchPage(cursor: nil)
            let mappedItems = try await Task.detached(priority: .userInitiated) {
                page.items.map(FeedItemViewData.init)
            }.value
            try Task.checkCancellation()
            state.items = mappedItems
            state.load = .loaded(())
        } catch is CancellationError {
            // Ignore cancellation.
        } catch {
            state.load = .failed(error.localizedDescription)
        }
    }
}
```

If mapping is small but reused, extract it into a pure helper (`static`/`nonisolated`) for testability; if it is expensive, run it off actor (`Task.detached` or a background service). Under strict concurrency (Swift 6), ensure detached-task captures/results are `Sendable`, or move the work behind a background actor/service boundary.

## Testing Expectations

Test state transitions: success (`loading -> loaded`), failure (`loading -> failed`), cancellation (no stale overwrite), mapping correctness (domain -> view data). Use `ControlledFeedRepository` to drive responses deterministically:

```swift
import XCTest

struct FeedItem: Equatable {
    let id: UUID
    let title: String
}

struct FeedPage: Equatable {
    let items: [FeedItem]
}

extension FeedItemViewData {
    init(_ item: FeedItem) {
        self.id = item.id
        self.title = item.title
    }
}

actor ControlledFeedRepository: FeedRepository {
    private var continuations: [CheckedContinuation<FeedPage, Error>] = []

    func fetchPage(cursor: String?) async throws -> FeedPage {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resolveNext(with result: Result<FeedPage, Error>) {
        guard !continuations.isEmpty else { return }
        let continuation = continuations.removeFirst()
        switch result {
        case .success(let page):
            continuation.resume(returning: page)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

@MainActor
final class FeedViewModelTests: XCTestCase {
    func test_load_success_setsLoadedAndMapsItems() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)
        let expected = FeedPage(items: [FeedItem(id: UUID(), title: "A")])

        sut.load()
        await repository.resolveNext(with: .success(expected))
        await Task.yield()

        XCTAssertEqual(sut.state.items.map(\.title), ["A"])
        if case .loaded = sut.state.load {
            // expected
        } else {
            XCTFail("Expected loaded state")
        }
    }

    func test_load_failure_setsFailed() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)

        sut.load()
        await repository.resolveNext(with: .failure(TestError.offline))
        await Task.yield()

        if case .failed = sut.state.load {
            // expected
        } else {
            XCTFail("Expected failed state")
        }
    }

    func test_load_cancellation_ignoresStaleResult() async {
        let repository = ControlledFeedRepository()
        let sut = FeedViewModel(repository: repository)

        let stale = FeedPage(items: [FeedItem(id: UUID(), title: "stale")])
        let latest = FeedPage(items: [FeedItem(id: UUID(), title: "latest")])

        sut.load() // request A
        sut.load() // request B cancels A

        await repository.resolveNext(with: .success(stale))
        await repository.resolveNext(with: .success(latest))
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(sut.state.items.map(\.title), ["latest"])
    }
}

private enum TestError: Error {
    case offline
}
```

## When to Prefer MVVM

- Screen-level state management without strict unidirectional flow requirements.
- Team wants explicit View/ViewModel boundaries at moderate ceremony cost (scales file splits to actual complexity).

## PR Review Checklist

- View does not call services directly.
- ViewModel exposes explicit state model.
- Domain models are not directly coupled to View rendering.
- Navigation destinations are modeled as value types (enum/struct), not imperative calls.
- ViewModel does not import UIKit or reference presentation APIs directly.
- Deep link handling routes through a centralized router, not ad-hoc view logic.
