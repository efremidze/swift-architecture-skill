# Benchmark: MVP Missing Presenter Wiring (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation paths with controlled stubs.
Avoid sleeps and real network calls in tests.

This file demonstrates the anti-pattern where MVP architecture is not followed: the repository is
tested in isolation instead of testing the Presenter wired to a mock View. A correct MVP test
would use `ProfilePresenter(repository:)` and set `presenter.view = mockView`.

```swift
import XCTest

struct User {
    let id: UUID
    let name: String
}

struct ProfileViewData: Equatable {
    let displayName: String
}

protocol ProfileRepository {
    func fetchCurrentUser() async throws -> User
}

struct StubProfileRepository: ProfileRepository {
    var result: Result<User, Error>
    func fetchCurrentUser() async throws -> User { try result.get() }
}

// Missing pattern: tests exercise the repository stub directly
// instead of going through a Presenter wired to a mock View.
@MainActor
final class ProfileRepositoryTests: XCTestCase {
    func test_fetch_success_returnsUser() async throws {
        let repo = StubProfileRepository(result: .success(User(id: UUID(), name: "Alice")))

        let user = try await repo.fetchCurrentUser()

        XCTAssertEqual(user.name, "Alice")
    }

    func test_fetch_failure_throws() async {
        let repo = StubProfileRepository(result: .failure(TestError.offline))

        do {
            _ = try await repo.fetchCurrentUser()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_fetch_cancellation_throwsCancellationError() async {
        let repo = StubProfileRepository(result: .failure(CancellationError()))

        do {
            _ = try await repo.fetchCurrentUser()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum TestError: Error {
    case offline
}
```
