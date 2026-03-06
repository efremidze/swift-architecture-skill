# Coordinator Playbook (Swift + SwiftUI/UIKit)

Use this reference when navigation logic needs to be decoupled from individual screens, enabling reusable flows, deep linking, and testable routing without view controllers owning their own transitions.

## Core Concept

A Coordinator owns one navigation flow. It creates and connects screens, passes dependencies, and decides what happens next when a user action triggers a transition.

```text
AppCoordinator
  -> AuthCoordinator   (owns login/signup flow)
  -> MainCoordinator   (owns tab/home flow)
       -> ProfileCoordinator (owns profile flow)
```

Rules:
- each coordinator owns one flow (a screen, a sub-flow, or a full section)
- screens emit navigation events; coordinators decide what to do with them
- screens do not reference coordinators or push/present directly
- parent coordinators launch child coordinators for nested flows

## Feature Structure

```text
App/
  AppCoordinator.swift
  Coordinators/
    AuthCoordinator.swift
    MainCoordinator.swift
    ProfileCoordinator.swift
  Features/
    Auth/
      LoginViewModel.swift
      LoginView.swift
    Profile/
      ProfileViewModel.swift
      ProfileView.swift
Navigation/
  Coordinator.swift         (protocol)
  NavigationRouter.swift    (UIKit helper)
```

## Coordinator Protocol

Define a minimal base contract.

```swift
@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    func start()
}

extension Coordinator {
    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}
```

Rules:
- retain child coordinators so they are not deallocated mid-flow
- remove child coordinators when the flow they own completes
- `start()` is the single entry point that kicks off the flow

## UIKit Coordinator

For UIKit, wrap a `UINavigationController` in a thin router.

```swift
@MainActor
final class NavigationRouter {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController = UINavigationController()) {
        self.navigationController = navigationController
    }

    func push(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.pushViewController(viewController, animated: animated)
    }

    func present(_ viewController: UIViewController, animated: Bool = true) {
        navigationController.present(viewController, animated: animated)
    }

    func pop(animated: Bool = true) {
        navigationController.popViewController(animated: animated)
    }

    func popToRoot(animated: Bool = true) {
        navigationController.popToRootViewController(animated: animated)
    }
}
```

Profile flow coordinator example:

```swift
@MainActor
final class ProfileCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let router: NavigationRouter
    private let userRepository: UserRepository

    init(router: NavigationRouter, userRepository: UserRepository) {
        self.router = router
        self.userRepository = userRepository
    }

    func start() {
        let viewModel = ProfileViewModel(
            repository: userRepository,
            onEditTapped: { [weak self] in self?.showEditProfile() },
            onLogoutTapped: { [weak self] in self?.finish() }
        )
        let viewController = ProfileViewController(viewModel: viewModel)
        router.push(viewController)
    }

    private func showEditProfile() {
        let editCoordinator = EditProfileCoordinator(
            router: router,
            userRepository: userRepository,
            onComplete: { [weak self] in self?.removeChild($0) }
        )
        addChild(editCoordinator)
    }

    private func finish() {
        // Notify parent this flow is done.
    }
}
```

## SwiftUI Coordinator

For SwiftUI, model navigation state as a value type and bind it to `NavigationStack`.

```swift
@MainActor
@Observable
final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var path: [AppDestination] = []
    var sheet: AppSheet?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func start() {
        // Nothing to push — root is set at view layer.
    }

    func showProfile(userID: UUID) {
        path.append(.profile(userID))
    }

    func showSettings() {
        sheet = .settings
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func dismissSheet() {
        sheet = nil
    }
}

enum AppDestination: Hashable {
    case profile(UUID)
    case editProfile(UUID)
}

enum AppSheet: Identifiable {
    case settings
    var id: String { "\(self)" }
}
```

Root view binds coordinator state to `NavigationStack`:

```swift
struct AppRootView: View {
    @State private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self._coordinator = State(initialValue: coordinator)
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        NavigationStack(path: $coordinator.path) {
            HomeView(
                onProfileTapped: { id in coordinator.showProfile(userID: id) },
                onSettingsTapped: { coordinator.showSettings() }
            )
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .profile(let id):
                    ProfileView(viewModel: makeProfileViewModel(userID: id))
                case .editProfile(let id):
                    EditProfileView(userID: id)
                }
            }
        }
        .sheet(item: $coordinator.sheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView(onDismiss: { coordinator.dismissSheet() })
            }
        }
    }

    private func makeProfileViewModel(userID: UUID) -> ProfileViewModel {
        ProfileViewModel(
            userID: userID,
            repository: coordinator.userRepository,
            onEditTapped: { coordinator.path.append(.editProfile(userID)) }
        )
    }
}
```

Rules:
- model destinations as a `Hashable` enum so `NavigationStack` can drive them
- model sheets as an `Identifiable` enum to bind `sheet(item:)`
- mutate coordinator state on the main actor
- avoid deep conditional nesting in the `navigationDestination` closure — prefer `switch`

## Child Coordinator Pattern

Parent coordinators own child coordinators for nested flows.

```swift
@MainActor
final class MainCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    private let router: NavigationRouter
    private let userRepository: UserRepository

    init(router: NavigationRouter, userRepository: UserRepository) {
        self.router = router
        self.userRepository = userRepository
    }

    func start() {
        showHome()
    }

    func showHome() {
        let viewModel = HomeViewModel(
            onProfileTapped: { [weak self] id in self?.showProfile(userID: id) }
        )
        let viewController = HomeViewController(viewModel: viewModel)
        router.push(viewController)
    }

    private func showProfile(userID: UUID) {
        let profileRouter = NavigationRouter(
            navigationController: router.navigationController
        )
        let coordinator = ProfileCoordinator(
            router: profileRouter,
            userRepository: userRepository
        )
        addChild(coordinator)
    }
}
```

## Deep Linking

Handle deep links by parsing a URL into a destination and routing directly to it.
Push destinations update `path`; sheet destinations set `sheet`.

```swift
@MainActor
final class DeepLinkHandler {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func handle(url: URL) {
        guard url.scheme == "myapp" else { return }
        switch url.host {
        case "profile":
            guard
                let idString = url.pathComponents.dropFirst().first,
                let id = UUID(uuidString: idString)
            else { return }
            coordinator.path = [.profile(id)]
        case "settings":
            coordinator.sheet = .settings
        default:
            break
        }
    }
}
```

## Anti-Patterns and Fixes

1. View controller pushes its own next screen:
   - Smell: `ProfileViewController` calls `navigationController?.pushViewController(SettingsViewController(), animated: true)` directly.
   - Fix: emit a closure or delegate event; let the Coordinator perform the push.

2. Coordinator retained only by a local variable:
   - Smell: parent loses reference to child coordinator; it deallocates mid-flow.
   - Fix: add child to `childCoordinators` before calling `start()`.

3. Navigation logic spread across ViewModels:
   - Smell: ViewModel holds a reference to `AppCoordinator` and calls `coordinator.showSettings()` directly.
   - Fix: inject navigation closures (`onSettingsTapped: () -> Void`) so the ViewModel stays decoupled from the coordinator type.

4. Deep linking bypasses coordinator:
   - Smell: `AppDelegate` calls `navigationController.pushViewController(...)` directly on deep link receipt.
   - Fix: route all deep links through `DeepLinkHandler` → `AppCoordinator.handle(url:)`.

5. Coordinator mixing business logic:
   - Smell: Coordinator fetches data or applies business rules before routing.
   - Fix: keep Coordinator responsible only for navigation; delegate data work to ViewModels/Repositories.

## Testing Strategy

Test Coordinators by verifying navigation state changes for success paths (expected destinations appended), failure paths (unknown inputs handled without crashing), and cancellation-safe pop operations.
Use stub repositories and direct coordinator state inspection to keep tests deterministic.
Avoid sleeps; prefer synchronous state mutations and direct property assertions.

```swift
@MainActor
final class SpyNavigationRouter: NavigationRouter {
    var pushedViewControllers: [UIViewController] = []
    var presentedViewControllers: [UIViewController] = []

    override func push(_ viewController: UIViewController, animated: Bool = true) {
        pushedViewControllers.append(viewController)
    }

    override func present(_ viewController: UIViewController, animated: Bool = true) {
        presentedViewControllers.append(viewController)
    }
}

@MainActor
final class ProfileCoordinatorTests: XCTestCase {
    func test_start_pushesProfileViewController() {
        let router = SpyNavigationRouter()
        let coordinator = ProfileCoordinator(
            router: router,
            userRepository: StubUserRepository()
        )

        coordinator.start()

        XCTAssertEqual(router.pushedViewControllers.count, 1)
        XCTAssertTrue(router.pushedViewControllers.first is ProfileViewController)
    }

    func test_showEditProfile_addsChildCoordinator() {
        let router = SpyNavigationRouter()
        let coordinator = ProfileCoordinator(
            router: router,
            userRepository: StubUserRepository()
        )
        coordinator.start()

        coordinator.showEditProfileForTesting()

        XCTAssertEqual(coordinator.childCoordinators.count, 1)
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_showProfile_success_appendsDestination() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        let id = UUID()

        coordinator.showProfile(userID: id)

        XCTAssertEqual(coordinator.path, [.profile(id)])
    }

    func test_pop_removesLastDestination() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        coordinator.path = [.profile(UUID()), .editProfile(UUID())]

        coordinator.pop()

        XCTAssertEqual(coordinator.path.count, 1)
    }

    func test_dismissSheet_clearsSheet() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        coordinator.sheet = .settings

        coordinator.dismissSheet()

        XCTAssertNil(coordinator.sheet)
    }

    func test_deepLink_failure_doesNotCrashOnUnknownScheme() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        let handler = DeepLinkHandler(coordinator: coordinator)
        let unknownURL = URL(string: "https://example.com/profile/123")!

        handler.handle(url: unknownURL)

        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func test_pop_cancellation_onEmptyPath_doesNotCrash() {
        let coordinator = AppCoordinator(userRepository: StubUserRepository())
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.pop()

        XCTAssertTrue(coordinator.path.isEmpty)
    }
}

struct StubUserRepository: UserRepository {
    func fetchCurrentUser() async throws -> User {
        User(id: UUID(), name: "Stub", isPremium: false, joinDate: .now)
    }
}
```

Note: `showEditProfileForTesting()` exposes the private routing action for test access — annotate with `#if DEBUG` or use `@testable import` and `internal` access level to keep production code clean.

## When to Prefer Coordinator

Prefer Coordinator when:
- navigation logic is complex (conditional flows, deep linking, multi-step wizards)
- multiple screens need to be reused across different flows
- you want to test routing logic without instantiating full screens
- ViewModels and View Controllers should have zero navigation coupling

Pair with MVVM by injecting navigation closures into ViewModels; pair with MVP by having the Presenter call a Router protocol backed by a Coordinator.

The Coordinator pattern is not an architecture on its own — it is a navigation layer that complements presentation patterns. Prefer it when `UINavigationController` push/present calls scattered across view controllers make flows hard to follow or test.

## PR Review Checklist

- Each coordinator owns one clearly scoped flow.
- Child coordinators are retained in `childCoordinators` before `start()` is called.
- Child coordinators are removed when their flow completes.
- ViewModels and View Controllers receive navigation closures, not coordinator references.
- Navigation state (SwiftUI path/sheet) is modeled as value types.
- Deep link handling routes through the coordinator, not directly to view controllers.
- Tests verify routing state changes without relying on UIKit presentation timing.
