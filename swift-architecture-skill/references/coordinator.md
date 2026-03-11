# Coordinator Playbook (Swift + SwiftUI/UIKit)

Use this reference when navigation logic needs to be decoupled from individual screens, enabling reusable flows, deep linking, and testable routing without view controllers owning their own transitions.

## Core Concept

```text
AppCoordinator
  -> AuthCoordinator   (owns login/signup flow)
  -> MainCoordinator   (owns tab/home flow)
       -> ProfileCoordinator (owns profile flow)
```

- Each coordinator owns one flow (a screen, a sub-flow, or a full section)
- Screens emit navigation events; coordinators decide what to do with them
- Screens do not reference coordinators or push/present directly
- Parent coordinators launch child coordinators for nested flows

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

- Retain child coordinators so they are not deallocated mid-flow
- Remove child coordinators when the flow they own completes
- `start()` is the single entry point that kicks off the flow

## UIKit Coordinator

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

    func showProfile(userID: UUID) { path.append(.profile(userID)) }
    func showSettings() { sheet = .settings }
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func dismissSheet() { sheet = nil }
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

- Model destinations as a `Hashable` enum so `NavigationStack` can drive them
- Model sheets as an `Identifiable` enum to bind `sheet(item:)`
- Mutate coordinator state on the main actor
- Avoid deep conditional nesting in the `navigationDestination` closure — prefer `switch`

## Child Coordinator Pattern

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

- Parse URL → destination enum; set coordinator path/sheet directly.

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

Verify navigation state changes directly: expected destinations appended on success, unknown inputs handled safely, pop guards empty-path crashes. Use stub repositories and synchronous state inspection — no sleeps.

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
        let coordinator = ProfileCoordinator(router: router, userRepository: StubUserRepository())

        coordinator.start()

        XCTAssertEqual(router.pushedViewControllers.count, 1)
        XCTAssertTrue(router.pushedViewControllers.first is ProfileViewController)
    }

    func test_showEditProfile_addsChildCoordinator() {
        let router = SpyNavigationRouter()
        let coordinator = ProfileCoordinator(router: router, userRepository: StubUserRepository())
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

- Expose private routing actions via internal access + `@testable import`, or `#if DEBUG`.

## When to Prefer Coordinator

- Navigation logic is complex: conditional flows, deep linking, multi-step wizards, or reused screens across flows.
- ViewModels/View Controllers must have zero navigation coupling and routing must be independently testable.

## PR Review Checklist

- Each coordinator owns one clearly scoped flow.
- Child coordinators are retained in `childCoordinators` before `start()` is called.
- Child coordinators are removed when their flow completes.
- ViewModels and View Controllers receive navigation closures, not coordinator references.
- Navigation state (SwiftUI path/sheet) is modeled as value types.
- Deep link handling routes through the coordinator, not directly to view controllers.
