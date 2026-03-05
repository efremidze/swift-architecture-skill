# Benchmark: MVP Presenter Passive View (Good)

## Testing Strategy

Test the Presenter in isolation with a mock View that conforms to the view protocol.
Wire the presenter to the mock view via `presenter.view = view`.
Cover success, failure, and cancellation paths using controlled stubs without sleeps.

```swift
import XCTest

struct User {
    let id: UUID
    let name: String
}

struct ProfileViewData: Equatable {
    let displayName: String
}

extension ProfileViewData {
    init(user: User) {
        self.displayName = user.name
    }
}

protocol ProfileView: AnyObject {
    func show(profile: ProfileViewData)
    func showError(message: String)
}

protocol ProfileRepository {
    func fetchCurrentUser() async throws -> User
}

struct StubProfileRepository: ProfileRepository {
    var result: Result<User, Error>
    func fetchCurrentUser() async throws -> User { try result.get() }
}

@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let repository: ProfileRepository
    private var loadTask: Task<Void, Never>?

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func load() {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let user = try await repository.fetchCurrentUser()
                try Task.checkCancellation()
                view?.show(profile: ProfileViewData(user: user))
            } catch is CancellationError {
                // keep existing view state on cancellation
            } catch {
                view?.showError(message: "Failed to load profile.")
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

@MainActor
final class MockProfileView: ProfileView {
    var shownViewData: ProfileViewData?
    var shownError: String?

    func show(profile: ProfileViewData) { shownViewData = profile }
    func showError(message: String) { shownError = message }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice")
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .success(user))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Alice")
        XCTAssertNil(view.shownError)
    }

    func test_load_failure_showsError() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(TestError.offline))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertNotNil(view.shownError)
        XCTAssertNil(view.shownViewData)
    }

    func test_load_cancellation_doesNotOverwriteViewState() async {
        let existing = User(id: UUID(), name: "Existing")
        let view = MockProfileView()
        view.show(profile: ProfileViewData(user: existing))
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(CancellationError()))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Existing")
    }
}

private enum TestError: Error {
    case offline
}
```
