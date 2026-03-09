# Benchmark: Coordinator Navigation State (Good)

## Testing Strategy

Test coordinator routing by verifying navigation state changes directly using a
StubUserRepository for deterministic, synchronous behaviour without sleeps.
Cover success destination appending, failure on unknown deep link schemes, and
cancellation-safe pop operations that remove the last route without crashing.
Verify child coordinator lifecycle: retained on addChild, removed on completion.

```swift
import XCTest

// MARK: - Domain

struct User {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func fetchCurrentUser() async throws -> User
}

struct StubUserRepository: UserRepository {
    func fetchCurrentUser() async throws -> User {
        User(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Stub")
    }
}

// MARK: - Navigation

enum AppDestination: Hashable {
    case profile(UUID)
    case editProfile(UUID)
}

enum AppSheet: Identifiable {
    case settings
    var id: String { "\(self)" }
}

// MARK: - Coordinator

@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [any Coordinator] { get set }
    func start()
}

@MainActor
extension Coordinator {
    func addChild(_ coordinator: any Coordinator) {
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    func removeChild(_ coordinator: any Coordinator) {
        childCoordinators.removeAll { ($0 as AnyObject) === (coordinator as AnyObject) }
    }
}

@MainActor
final class AppCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    var path: [AppDestination] = []
    var sheet: AppSheet?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func start() {}

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

@MainActor
final class ChildFlowCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    var didStart = false
    func start() { didStart = true }
}

// MARK: - Tests

@MainActor
final class AppCoordinatorTests: XCTestCase {
    private func makeCoordinator() -> AppCoordinator {
        AppCoordinator(userRepository: StubUserRepository())
    }

    func test_showProfile_success_appendsDestination() {
        let coordinator = makeCoordinator()
        let id = UUID()

        coordinator.showProfile(userID: id)

        XCTAssertEqual(coordinator.path, [.profile(id)])
    }

    func test_deepLink_failure_doesNotCrashOnUnknownScheme() {
        let coordinator = makeCoordinator()
        let handler = DeepLinkHandler(coordinator: coordinator)
        let unknown = URL(string: "https://example.com/profile/123")!

        handler.handle(url: unknown)

        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func test_pop_onEmptyPath_doesNotCrash() {
        let coordinator = makeCoordinator()
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.pop()

        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func test_cancelChildFlow_removesChildCoordinator() {
        let coordinator = makeCoordinator()
        let child = ChildFlowCoordinator()

        coordinator.addChild(child)

        XCTAssertEqual(coordinator.childCoordinators.count, 1)
        XCTAssertTrue(child.didStart)

        coordinator.removeChild(child)

        XCTAssertEqual(coordinator.childCoordinators.count, 0)
    }

    func test_pop_removesLastDestination() {
        let coordinator = makeCoordinator()
        let firstID = UUID()
        let secondID = UUID()
        coordinator.path = [.profile(firstID), .editProfile(secondID)]

        coordinator.pop()

        XCTAssertEqual(coordinator.path, [.profile(firstID)])
    }

    func test_dismissSheet_clearsSheet() {
        let coordinator = makeCoordinator()
        coordinator.sheet = .settings

        coordinator.dismissSheet()

        XCTAssertNil(coordinator.sheet)
    }
}
```
