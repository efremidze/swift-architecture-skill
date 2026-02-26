# Benchmark: VIPER Presenter Wiring (Good)

## Testing Strategy

Validate success, failure, and cancellation behavior at presenter boundaries with deterministic interactor stubs.
Use mocked view and router collaborators and avoid sleeps.

```swift
import XCTest

struct User {
    let id: UUID
    let name: String
}

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
        } catch is CancellationError {
            // keep existing UI state on cancellation
        } catch {
            view?.show(name: "")
        }
    }

    func didTapSettings() {
        router.showSettings()
    }
}

@MainActor
final class MockProfileView: ProfileView {
    var shownName: String?
    func show(name: String) { shownName = name }
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
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { User(id: UUID(), name: "Alice") }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        await presenter.load()

        XCTAssertEqual(view.shownName, "Alice")
    }

    func test_load_failure_showsEmptyName() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw TestError.offline }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        await presenter.load()

        XCTAssertEqual(view.shownName, "")
    }

    func test_load_cancellation_doesNotOverwriteViewState() async {
        let view = MockProfileView()
        view.shownName = "Current"
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { throw CancellationError() }),
            router: SpyProfileRouter()
        )
        presenter.view = view

        await presenter.load()

        XCTAssertEqual(view.shownName, "Current")
    }

    func test_didTapSettings_routesToSettings() {
        let router = SpyProfileRouter()
        let presenter = ProfilePresenter(
            interactor: StubProfileInteractor(load: { User(id: UUID(), name: "") }),
            router: router
        )

        presenter.didTapSettings()

        XCTAssertTrue(router.didShowSettings)
    }
}

private enum TestError: Error {
    case offline
}
```
