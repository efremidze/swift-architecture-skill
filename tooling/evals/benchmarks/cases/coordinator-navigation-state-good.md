# Benchmark: Coordinator Navigation State (Good)

## Testing Strategy

Test coordinator routing by inspecting navigation state changes directly.
Use a spy router or observe the coordinator's path/sheet properties.
Cover destination appending, popping, sheet presentation, and cancellation-safe state on unknown inputs.

```swift
import XCTest

enum AppDestination: Hashable {
    case profile(UUID)
    case editProfile(UUID)
}

enum AppSheet: Identifiable {
    case settings
    var id: String { "\(self)" }
}

@MainActor
protocol Coordinator: AnyObject {
    var childCoordinators: [any Coordinator] { get set }
    func start()
}

@MainActor
final class AppCoordinator: Coordinator {
    var childCoordinators: [any Coordinator] = []
    var path: [AppDestination] = []
    var sheet: AppSheet?

    func start() {}

    func showProfile(userID: UUID) {
        path.append(.profile(userID))
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func showSettings() {
        sheet = .settings
    }

    func dismissSheet() {
        sheet = nil
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_showProfile_appendsDestination() {
        let coordinator = AppCoordinator()
        let id = UUID()

        coordinator.showProfile(userID: id)

        XCTAssertEqual(coordinator.path, [.profile(id)])
    }

    func test_pop_removesLastDestination() {
        let coordinator = AppCoordinator()
        let firstID = UUID()
        let secondID = UUID()
        coordinator.path = [.profile(firstID), .editProfile(secondID)]

        coordinator.pop()

        XCTAssertEqual(coordinator.path, [.profile(firstID)])
    }

    func test_showSettings_setsSheet() {
        let coordinator = AppCoordinator()

        coordinator.showSettings()

        if case .settings = coordinator.sheet {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected settings sheet")
        }
    }

    func test_dismissSheet_clearsSheet() {
        let coordinator = AppCoordinator()
        coordinator.sheet = .settings

        coordinator.dismissSheet()

        XCTAssertNil(coordinator.sheet)
    }

    func test_pop_onEmptyPath_doesNotCrash() {
        let coordinator = AppCoordinator()
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.pop()

        XCTAssertTrue(coordinator.path.isEmpty)
    }
}
```
