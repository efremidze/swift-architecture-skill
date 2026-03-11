# VIPER Playbook (Swift + SwiftUI/UIKit)

Use this reference when strict feature-level separation is needed, especially in large or legacy UIKit codebases.

## Core Components

- View: render UI and forward user actions
- Interactor: execute business logic and coordinate data access
- Presenter: transform entities into display-ready output and control view state
- Entity: domain models used by the feature
- Router: navigation and module assembly

```text
View -> Presenter -> Interactor -> Repository/Service -> Interactor -> Presenter -> View
Presenter -> Router (navigation)
```

## Canonical Feature Layout

```text
Feature/
  View/
  Presenter/
  Interactor/
  Entity/
  Router/
```

- Keep one VIPER module per feature to prevent cross-feature leakage.

## Responsibilities

### View

- Render data provided by Presenter.
- Forward user inputs (`didTap...`, `didAppear`, text changes).
- Avoid direct service/repository access.
- In SwiftUI, use an adapter (`@Observable` on iOS 17+ or `ObservableObject` when Combine/UIKit interop is needed) that forwards to Presenter.

### Presenter

- Own presentation flow for the feature.
- Ask Interactor for business results.
- Map entities to view models/display strings.
- Call Router for navigation.

### Interactor

- Execute business rules and use cases.
- Call repositories/services through protocols.
- Return domain results to Presenter.
- Avoid direct view or navigation concerns.

### Router

- Perform navigation transitions.
- Build and wire module dependencies.

### Entity

- Represent domain data and business invariants.
- Avoid UI and framework coupling where possible.
- Keep display formatting out of `Entity`; Presenter maps entity -> display model.

```swift
struct User: Equatable {
    let id: UUID
    let name: String
    let isPremium: Bool
}

struct ProfileViewData: Equatable {
    let displayName: String
    let badgeText: String?
}

extension ProfileViewData {
    init(user: User) {
        self.displayName = user.name
        self.badgeText = user.isPremium ? "Premium" : nil
    }
}
```

## Wiring Pattern

```swift
@MainActor
protocol ProfileView: AnyObject {
    func showLoading(_ isLoading: Bool)
    func show(profile: ProfileViewData)
    func showError(message: String)
}

protocol ProfileInteracting {
    func loadUser() async throws -> User
}

protocol ProfileRouting {
    func showSettings()
}

@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let interactor: ProfileInteracting
    private let router: ProfileRouting
    private var loadTask: Task<Void, Never>?
    private var latestLoadRequestID: UUID?

    init(interactor: ProfileInteracting, router: ProfileRouting) {
        self.interactor = interactor
        self.router = router
    }

    func load() {
        let requestID = UUID()
        latestLoadRequestID = requestID
        loadTask?.cancel()
        view?.showLoading(true)

        loadTask = Task {
            do {
                let user = try await interactor.loadUser()
                try Task.checkCancellation()
                guard latestLoadRequestID == requestID else { return }
                view?.show(profile: ProfileViewData(user: user))
            } catch is CancellationError {
                // Cancelled by a newer load request.
            } catch {
                guard latestLoadRequestID == requestID else { return }
                view?.showError(message: "Failed to load profile. Please try again.")
            }
            guard latestLoadRequestID == requestID else { return }
            view?.showLoading(false)
        }
    }

    func didTapSettings() {
        router.showSettings()
    }

    deinit {
        loadTask?.cancel()
    }
}
```

- `weak var view: ProfileView?` — prevents retain cycles
- Keep all Presenter → View calls on `@MainActor`

## Assembly Guidance

```swift
enum ProfileModule {
    static func build(
        userRepository: UserRepository,
        navigationController: UINavigationController
    ) -> UIViewController {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileRouter(navigationController: navigationController)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let viewController = ProfileViewController(presenter: presenter)
        presenter.view = viewController
        return viewController
    }
}
```

- Keep the factory method as the single entry point for module creation
- Inject external dependencies (repositories, services) from the caller
- Set weak back-references (e.g., `presenter.view`) after construction

**SwiftUI:** Bridge via thin `@Observable` adapter conforming to the View protocol; inject a SwiftUI router instead of `UINavigationController`. For pure SwiftUI apps, implement `ProfileRouting` as a thin wrapper calling `appRouter.push(.settings)` on a shared `@Observable AppRouter` — see `coordinator.md`.

```swift
import SwiftUI
import UIKit

@MainActor
final class ProfileViewAdapter: ObservableObject, ProfileView {
    @Published private(set) var name = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private let presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
    }

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }
    func show(profile: ProfileViewData) { self.name = profile.displayName; self.errorMessage = nil }
    func showError(message: String) { self.errorMessage = message }
    func load() { presenter.load() }
    func didTapSettings() { presenter.didTapSettings() }
}

struct ProfileScreen: View {
    @ObservedObject var adapter: ProfileViewAdapter

    var body: some View {
        VStack {
            Text(adapter.name)
            if adapter.isLoading { ProgressView() }
            if let errorMessage = adapter.errorMessage { Text(errorMessage) }
            Button("Settings") { adapter.didTapSettings() }
        }
        .task { adapter.load() }
    }
}

enum ProfileModuleSwiftUI {
    static func build(
        userRepository: UserRepository,
        navigationController: UINavigationController
    ) -> UIViewController {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileRouter(navigationController: navigationController)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let adapter = ProfileViewAdapter(presenter: presenter)
        presenter.view = adapter
        return UIHostingController(rootView: ProfileScreen(adapter: adapter))
    }
}
```

## Concurrency and Cancellation

- Cancel in-flight tasks before issuing new requests
- Handle `CancellationError` explicitly to avoid stale UI updates
- Gate UI updates by request identity so only the latest request can update view state
- Cancel all tasks on module teardown
- Keep presenter intent methods synchronous (`func load()`), and manage async tasks internally

## Anti-Patterns and Fixes

1. Massive Presenter:
- Smell: presenter contains business logic, formatting, networking, and navigation details.
- Fix: move business logic to Interactor and formatting helpers; keep Presenter orchestration-focused.

2. Interactor performing navigation:
- Smell: interactor directly pushes/presents screens.
- Fix: route navigation through Router called by Presenter.

3. Circular dependencies and strong cycles:
- Smell: View <-> Presenter <-> Router retain each other strongly.
- Fix: use boundary protocols and weak references where required.

4. View doing business work:
- Smell: View transforms data or calls services directly.
- Fix: move logic into Presenter/Interactor.

5. Router containing business logic:
- Smell: Router decides domain outcomes.
- Fix: keep Router limited to navigation and assembly.

## Testing Strategy

Test each component in isolation: Presenter with mocked View/Interactor/Router; Interactor with stub repositories. Assert Presenter-to-View output contracts (`show(profile:)`, `showError(message:)`) and cancellation behavior.

```swift
@MainActor
final class MockProfileView: ProfileView {
    var shownName: String?
    var shownError: String?
    var isLoading = false

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }
    func show(profile: ProfileViewData) { shownName = profile.displayName }
    func showError(message: String) { shownError = message }
}

struct StubProfileInteractor: ProfileInteracting {
    var load: () async throws -> User
    func loadUser() async throws -> User { try await load() }
}

final class SpyProfileRouter: ProfileRouting {
    var didShowSettings = false
    func showSettings() { didShowSettings = true }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice", isPremium: false)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { user }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownName, "Alice")
    }

    func test_load_failure_showsError() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw TestError.notFound }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownError, "Failed to load profile. Please try again.")
    }

    func test_didTapSettings_routesToSettings() {
        let router = SpyProfileRouter()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { User(id: UUID(), name: "", isPremium: false) }),
            router: router
        )

        presenter.didTapSettings()

        XCTAssertTrue(router.didShowSettings)
    }

    func test_load_cancellation_doesNotOverwriteExistingName() async {
        let view = MockProfileView()
        view.shownName = "Current"
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw CancellationError() }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownName, "Current")
    }
}

private enum TestError: Error { case notFound }
```

## When to Prefer VIPER

- Multiple teams need independently owned feature modules with explicit, enforced role boundaries.
- UIKit-heavy codebase where interactor-level business rules must be testable in isolation.

## PR Review Checklist

- Component responsibilities are respected (View/Interactor/Presenter/Router separated).
- Presenter does not own business logic implementation details.
- Interactor does not navigate.
- Router handles only navigation and module assembly.
- Boundary protocols avoid concrete coupling.
- Retain cycles are prevented with weak references where needed.
