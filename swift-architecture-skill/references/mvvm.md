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

Prefer vertical feature slices with clear boundaries:

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
    @State private var viewModel: FeedViewModel

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
    @StateObject private var viewModel: FeedViewModel

    var body: some View {
        List(viewModel.state.items, id: \.id) { item in
            Text(item.title)
        }
        .task { viewModel.onAppear() }
    }
}
```

## Navigation Patterns

Keep routing decisions testable and decoupled from presentation APIs: ViewModel decides *where*, routing layer decides *how*.

### SwiftUI Navigation (iOS 16+ / `NavigationStack`)

Model destinations as an enum and drive `NavigationStack` from ViewModel path state. Prefer stable IDs over list-specific `ViewData`.

```swift
enum FeedDestination: Hashable {
    case detail(id: UUID)
    case profile(userId: UUID)
    case settings
}
```

ViewModel exposes a navigation path:

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()
    var navigationPath: [FeedDestination] = []

    // ...existing properties...

    func didTapItem(_ item: FeedItemViewData) {
        navigationPath.append(.detail(id: item.id))
    }

    func didTapProfile(userId: UUID) {
        navigationPath.append(.profile(userId: userId))
    }
}
```

View binds the path to `NavigationStack`:

```swift
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.state.items) { item in
                Button(item.title) {
                    viewModel.didTapItem(item)
                }
            }
            .navigationDestination(for: FeedDestination.self) { destination in
                switch destination {
                case .detail(let itemID):
                    FeedDetailView(viewModel: FeedDetailViewModel(itemID: itemID))
                case .profile(let userId):
                    ProfileView(viewModel: ProfileViewModel(userId: userId))
                case .settings:
                    SettingsView(viewModel: SettingsViewModel())
                }
            }
            .task { viewModel.onAppear() }
        }
    }
}
```

### Modal / Sheet Presentation

Model sheet presentation as optional state on the ViewModel.

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()
    var activeSheet: FeedSheet?

    struct FeedFilter: Equatable {
        var showUnreadOnly = false
    }

    enum FeedSheet: Identifiable {
        case compose
        case filter(current: FeedFilter)

        var id: String {
            switch self {
            case .compose: "compose"
            case .filter: "filter"
            }
        }
    }

    func didTapCompose() {
        activeSheet = .compose
    }
}
```

```swift
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        List(viewModel.state.items) { item in
            Text(item.title)
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .compose:
                ComposeView(viewModel: ComposeViewModel())
            case .filter(let current):
                FilterView(viewModel: FilterViewModel(filter: current))
            }
        }
    }
}
```

### Coordinator Pattern (UIKit or Mixed Codebases)

When UIKit is involved or complex multi-step flows require centralized control, use a Coordinator protocol.

```swift
@MainActor
protocol FeedCoordinator: AnyObject {
    func showDetail(itemID: UUID)
    func showProfile(userId: UUID)
    func presentCompose(onComplete: @MainActor @escaping () -> Void)
}
```

Inject the Coordinator into the ViewModel:

```swift
@MainActor
@Observable
final class FeedViewModel {
    private(set) var state = FeedState()

    private let repository: FeedRepository
    private weak var coordinator: FeedCoordinator?
    private var loadTask: Task<Void, Never>?

    init(repository: FeedRepository, coordinator: FeedCoordinator) {
        self.repository = repository
        self.coordinator = coordinator
    }

    func didTapItem(_ item: FeedItemViewData) {
        coordinator?.showDetail(itemID: item.id)
    }

    func didTapCompose() {
        coordinator?.presentCompose { [weak self] in
            self?.load()
        }
    }
}
```

Concrete implementation lives in the navigation layer:

```swift
@MainActor
final class FeedFlowCoordinator: FeedCoordinator {
    private let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func showDetail(itemID: UUID) {
        let viewModel = FeedDetailAssembly.makeViewModel(itemID: itemID)
        let vc = UIHostingController(rootView: FeedDetailView(viewModel: viewModel))
        navigationController.pushViewController(vc, animated: true)
    }

    func showProfile(userId: UUID) {
        let viewModel = ProfileAssembly.makeViewModel(userId: userId)
        let vc = UIHostingController(rootView: ProfileView(viewModel: viewModel))
        navigationController.pushViewController(vc, animated: true)
    }

    func presentCompose(onComplete: @MainActor @escaping () -> Void) {
        let composeVM = ComposeAssembly.makeViewModel(onComplete: onComplete)
        let vc = UIHostingController(rootView: ComposeView(viewModel: composeVM))
        navigationController.present(vc, animated: true)
    }
}
```

### Deep Linking

Centralize deep link resolution in a router that maps URLs to navigation destinations.

```swift
enum DeepLink {
    case feedItem(id: UUID)
    case profile(userId: UUID)
    case settings

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return nil }
        switch host {
        case "feed":
            guard let idString = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let id = UUID(uuidString: idString) else { return nil }
            self = .feedItem(id: id)
        case "profile":
            guard let idString = components.queryItems?.first(where: { $0.name == "userId" })?.value,
                  let id = UUID(uuidString: idString) else { return nil }
            self = .profile(userId: id)
        case "settings":
            self = .settings
        default:
            return nil
        }
    }
}
```

Apply deep links to existing navigation state:

```swift
@MainActor
@Observable
final class AppRouter {
    var feedViewModel: FeedViewModel

    func handle(_ deepLink: DeepLink) {
        switch deepLink {
        case .feedItem(let id):
            feedViewModel.navigationPath = [.detail(id: id)]
        case .profile(let userId):
            feedViewModel.navigationPath = [.profile(userId: userId)]
        case .settings:
            feedViewModel.navigationPath = [.settings]
        }
    }
}
```

### Which Pattern to Choose

| Scenario | Recommended Pattern |
|---|---|
| Pure SwiftUI, linear flows | `NavigationStack` path on ViewModel |
| Sheets, alerts, confirmations | Optional state-driven presentation |
| UIKit host or mixed SwiftUI/UIKit | Coordinator protocol |
| Multi-step flows (onboarding, checkout) | Coordinator with child coordinators |
| Universal Links / push notifications | Deep link router + state-driven nav |

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
- team wants low-ceremony state handling
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
- Navigation destinations are modeled as value types (enum/struct), not imperative calls.
- ViewModel does not import UIKit or reference presentation APIs directly.
- Deep link handling routes through a centralized router, not ad-hoc view logic.
- Unit tests cover success, failure, and cancellation.
