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
- In SwiftUI, use an adapter (`ObservableObject`) that forwards to Presenter.

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

## Wiring Pattern

Use boundary protocols and directional references.

```swift
@MainActor
protocol ProfileView: AnyObject {
    func show(name: String)
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

    init(interactor: ProfileInteracting, router: ProfileRouting) {
        self.interactor = interactor
        self.router = router
    }

    func load() async {
        do {
            let user = try await interactor.loadUser()
            view?.show(name: user.name)
        } catch {
            view?.show(name: "")
        }
    }

    func didTapSettings() {
        router.showSettings()
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

```swift
import SwiftUI
import UIKit

@MainActor
final class ProfileViewAdapter: ObservableObject, ProfileView {
    @Published private(set) var name = ""
    private let presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
    }

    func show(name: String) {
        self.name = name
    }

    func load() async { await presenter.load() }
    func didTapSettings() { presenter.didTapSettings() }
}

struct ProfileScreen: View {
    @ObservedObject var adapter: ProfileViewAdapter

    var body: some View {
        VStack {
            Text(adapter.name)
            Button("Settings") { adapter.didTapSettings() }
        }
        .task { await adapter.load() }
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

When Presenter coordinates async work, track active tasks and cancel stale requests.

```swift
@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let interactor: ProfileInteracting
    private let router: ProfileRouting
    private var loadTask: Task<Void, Never>?

    init(interactor: ProfileInteracting, router: ProfileRouting) {
        self.interactor = interactor
        self.router = router
    }

    func load() async {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let user = try await interactor.loadUser()
                view?.show(name: user.name)
            } catch is CancellationError {
                // Cancelled by a newer load request.
            } catch {
                view?.show(name: "")
            }
        }
        await loadTask?.value
    }

    func didTapSettings() {
        router.showSettings()
    }

    deinit {
        loadTask?.cancel()
    }
}
```

Rules:
- cancel in-flight tasks before issuing new requests
- handle `CancellationError` explicitly to avoid stale UI updates
- cancel all tasks on module teardown

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

```swift
@MainActor
final class MockProfileView: ProfileView {
    var shownName: String?
    func show(name: String) { shownName = name }
}

struct StubProfileInteractor: ProfileInteracting {
    var result: Result<User, Error>
    func loadUser() async throws -> User { try result.get() }
}

final class SpyProfileRouter: ProfileRouting {
    var didShowSettings = false
    func showSettings() { didShowSettings = true }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice")
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(result: .success(user)),
            router: SpyProfileRouter()
        )
        presenter.view = view

        await presenter.load()

        XCTAssertEqual(view.shownName, "Alice")
    }

    func test_load_failure_showsEmptyName() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(result: .failure(TestError.notFound)),
            router: SpyProfileRouter()
        )
        presenter.view = view

        await presenter.load()

        XCTAssertEqual(view.shownName, "")
    }

    func test_didTapSettings_routesToSettings() {
        let router = SpyProfileRouter()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(result: .success(User(id: UUID(), name: ""))),
            router: router
        )

        presenter.didTapSettings()

        XCTAssertTrue(router.didShowSettings)
    }
}

private enum TestError: Error { case notFound }
```

## When to Prefer VIPER

Prefer VIPER when:
- feature boundaries must be very explicit
- team needs strict role separation
- UIKit-heavy codebase benefits from modularized presentation flow

Prefer lighter patterns when:
- app is small or prototyping quickly
- ceremony cost outweighs architecture benefit

## PR Review Checklist

- Component responsibilities are respected (View/Interactor/Presenter/Router separated).
- Presenter does not own business logic implementation details.
- Interactor does not navigate.
- Router handles only navigation and module assembly.
- Boundary protocols avoid concrete coupling.
- Retain cycles are prevented with weak references where needed.
- Tests cover presenter orchestration and interactor business rules.
