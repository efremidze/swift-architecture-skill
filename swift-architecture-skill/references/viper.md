# VIPER Playbook (Swift + SwiftUI/UIKit)

Use this reference when strict feature-level separation is needed, especially in large or legacy UIKit codebases.

## Core Components

- View: render UI and forward user actions
- Interactor: execute business logic and coordinate data access
- Presenter: transform entities into display-ready output and control view state
- Entity: domain models used by the feature
- Router: navigation and module assembly

Expected interaction:

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

Keep one VIPER module per feature to prevent cross-feature leakage.

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

Use boundary protocols and directional references.

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

Keep `view` weak to avoid retain cycles.
Keep presenter/view updates on the main actor so UI calls are thread-safe.

## Assembly Guidance

Create modules via Router/Assembly factory:
- instantiate View, Presenter, Interactor, Router
- inject protocols, not concrete global singletons
- set references once during build

This centralizes wiring and reduces circular dependency mistakes.

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

Rules:
- keep the factory method as the single entry point for module creation
- inject external dependencies (repositories, services) from the caller
- set weak back-references (e.g., `presenter.view`) after construction

SwiftUI integration option:
- keep Presenter/Interactor/Router unchanged
- wrap SwiftUI feature view in `UIHostingController`
- bridge Presenter output through a small adapter object
- for pure SwiftUI apps, inject a SwiftUI router object instead of requiring `UINavigationController`

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

    func showLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func show(profile: ProfileViewData) {
        self.name = profile.displayName
        self.errorMessage = nil
    }

    func showError(message: String) {
        self.errorMessage = message
    }

    func load() { presenter.load() }
    func didTapSettings() { presenter.didTapSettings() }
}

struct ProfileScreen: View {
    @ObservedObject var adapter: ProfileViewAdapter

    var body: some View {
        VStack {
            Text(adapter.name)
            if adapter.isLoading { ProgressView() }
            if let errorMessage = adapter.errorMessage {
                Text(errorMessage)
            }
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

Pure SwiftUI app option (no `UINavigationController`):

```swift
import SwiftUI

enum AppDestination: Hashable {
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppDestination] = []

    func push(_ destination: AppDestination) {
        path.append(destination)
    }
}

@MainActor
final class ProfileSwiftUIRouter: ProfileRouting {
    private let appRouter: AppRouter

    init(appRouter: AppRouter) {
        self.appRouter = appRouter
    }

    func showSettings() {
        appRouter.push(.settings)
    }
}

enum ProfileModulePureSwiftUI {
    @MainActor
    static func build(
        userRepository: UserRepository,
        appRouter: AppRouter
    ) -> ProfileScreen {
        let interactor = ProfileInteractor(repository: userRepository)
        let router = ProfileSwiftUIRouter(appRouter: appRouter)
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        let adapter = ProfileViewAdapter(presenter: presenter)
        presenter.view = adapter
        return ProfileScreen(adapter: adapter)
    }
}
```

At app root, bind the shared router path to `NavigationStack`:

```swift
struct AppRootView: View {
    @State private var appRouter = AppRouter()

    var body: some View {
        @Bindable var appRouter = appRouter

        NavigationStack(path: $appRouter.path) {
            ProfileModulePureSwiftUI.build(
                userRepository: LiveUserRepository(),
                appRouter: appRouter
            )
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
```

## Concurrency and Cancellation

When Presenter coordinates async work, track active tasks and cancel stale requests. The `ProfilePresenter` shown in the Wiring Pattern section above already implements the full cancellation strategy — it holds a `loadTask: Task<Void, Never>?`, a `latestLoadRequestID: UUID?`, and handles `CancellationError` explicitly to guard against stale UI updates.

Rules:
- cancel in-flight tasks before issuing new requests
- handle `CancellationError` explicitly to avoid stale UI updates
- gate UI updates by request identity so only the latest request can update view state
- cancel all tasks on module teardown
- keep presenter intent methods synchronous (`func load()`), and manage async tasks internally

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

Prioritize isolated tests per component:
- Presenter tests with mocked View/Interactor/Router
- Interactor tests with mocked repositories/services
- Router tests for navigation triggers where feasible

Testing rules:
- assert interactions and outputs, not concrete implementations
- avoid network in unit tests
- verify presenter handles success and failure states
- verify Presenter-to-View error contract (`showError(message:)`) for failure paths
- test cancellation behavior when a newer load replaces an in-flight request
- keep async tests deterministic with controlled stubs/clocks (avoid sleeps)

Use the cancellation-aware presenter from the "Concurrency and Cancellation" section for cancellation-path tests.

```swift
@MainActor
final class MockProfileView: ProfileView {
    var shownName: String?
    var shownError: String?
    var isLoading = false

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }

    func show(profile: ProfileViewData) {
        shownName = profile.displayName
    }

    func showError(message: String) {
        shownError = message
    }
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

Prefer VIPER when:
- multiple teams need independently owned feature modules with explicit boundaries
- strict role separation reduces architecture drift in long-lived codebases
- interactor-level business rules must be testable without booting UI screens
- modular compilation and clear dependency direction are high priorities
- UIKit-heavy codebase benefits from router-driven assembly/navigation

Prefer lighter patterns when:
- app is small or prototyping quickly
- ceremony cost outweighs boundary/testability benefits

Compared with organized MVVM, VIPER usually adds more setup but enforces role boundaries more strongly at scale, especially when teams and modules are decoupled.

## PR Review Checklist

- Component responsibilities are respected (View/Interactor/Presenter/Router separated).
- Presenter does not own business logic implementation details.
- Interactor does not navigate.
- Router handles only navigation and module assembly.
- Boundary protocols avoid concrete coupling.
- Retain cycles are prevented with weak references where needed.
- Tests cover presenter orchestration and interactor business rules.
