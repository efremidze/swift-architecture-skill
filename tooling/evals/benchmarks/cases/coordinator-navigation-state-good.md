# Benchmark: Coordinator Navigation State (Good)

## Testing Strategy

Test coordinator routing by inspecting navigation state changes directly using a
MockCoordinatorDelegate stub to capture callbacks without sleeps or real UIKit dependencies.
Cover success destination appending, failure on empty-path pops, and cancellation-safe
pop operations that remove the last route. All tests are deterministic and synchronous.

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

protocol CoordinatorDelegate: AnyObject {
    func coordinatorDidNavigate(to destination: AppDestination)
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
    weak var delegate: CoordinatorDelegate?

    func start() {}

    func showProfile(userID: UUID) {
        let destination = AppDestination.profile(userID)
        path.append(destination)
        delegate?.coordinatorDidNavigate(to: destination)
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
final class MockCoordinatorDelegate: CoordinatorDelegate {
    var navigatedDestinations: [AppDestination] = []
    func coordinatorDidNavigate(to destination: AppDestination) {
        navigatedDestinations.append(destination)
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_showProfile_success_appendsDestinationAndNotifiesDelegate() {
        let coordinator = AppCoordinator()
        let mock = MockCoordinatorDelegate()
        coordinator.delegate = mock
        let id = UUID()

        coordinator.showProfile(userID: id)

        XCTAssertEqual(coordinator.path, [.profile(id)])
        XCTAssertEqual(mock.navigatedDestinations, [.profile(id)])
    }

    func test_pop_onEmptyPath_failure_doesNotModifyPath() {
        let coordinator = AppCoordinator()
        XCTAssertTrue(coordinator.path.isEmpty)

        coordinator.pop()

        XCTAssertTrue(coordinator.path.isEmpty)
    }

    func test_cancelNavigation_pop_removesLastDestination() {
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
}
```
