# Real-World Corpus: Coordinator Path State (Expected Fail)

Source:
- Synthetic — representative of SwiftUI Coordinator navigation state testing patterns

## Testing Strategy

Tests cover navigation path changes for common routing actions but do not include
cancellation-focused tests or deterministic async timing.
Dependency stubs are not used — the Coordinator is tested with direct state assertions only.

```swift
import XCTest

enum AppRoute: Hashable {
    case detail(id: UUID)
    case settings
    case compose
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var path: [AppRoute] = []

    func showDetail(id: UUID) {
        path.append(.detail(id: id))
    }

    func showSettings() {
        path.append(.settings)
    }

    func showCompose() {
        path.append(.compose)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_showDetail_appendsDetailRoute() {
        let coordinator = AppCoordinator()
        let id = UUID()
        coordinator.showDetail(id: id)
        XCTAssertEqual(coordinator.path, [.detail(id: id)])
    }

    func test_showSettings_appendsSettingsRoute() {
        let coordinator = AppCoordinator()
        coordinator.showSettings()
        XCTAssertEqual(coordinator.path, [.settings])
    }

    func test_pop_removesLastRoute() {
        let coordinator = AppCoordinator()
        coordinator.showSettings()
        coordinator.showCompose()
        coordinator.pop()
        XCTAssertEqual(coordinator.path, [.settings])
    }

    func test_popToRoot_clearsPath() {
        let coordinator = AppCoordinator()
        coordinator.showDetail(id: UUID())
        coordinator.showSettings()
        coordinator.popToRoot()
        XCTAssertTrue(coordinator.path.isEmpty)
    }
}
```
