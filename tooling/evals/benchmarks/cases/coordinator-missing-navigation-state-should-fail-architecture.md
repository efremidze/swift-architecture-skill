# Benchmark: Coordinator Missing Navigation State (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation paths with deterministic stubs.
Avoid sleeps and real network calls in tests.

```swift
import XCTest

struct User {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func fetchUser(id: UUID) async throws -> User
}

struct StubUserRepository: UserRepository {
    var result: Result<User, Error>
    func fetchUser(id: UUID) async throws -> User { try result.get() }
}

// Missing pattern: tests exercise repository directly without
// verifying that coordinator navigation state changes occur.
@MainActor
final class UserRepositoryTests: XCTestCase {
    func test_fetchUser_success_returnsUser() async throws {
        let id = UUID()
        let repo = StubUserRepository(result: .success(User(id: id, name: "Alice")))

        let user = try await repo.fetchUser(id: id)

        XCTAssertEqual(user.name, "Alice")
    }

    func test_fetchUser_failure_throws() async {
        let repo = StubUserRepository(result: .failure(TestError.notFound))

        do {
            _ = try await repo.fetchUser(id: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_fetchUser_cancellation_throwsCancellationError() async {
        let repo = StubUserRepository(result: .failure(CancellationError()))

        do {
            _ = try await repo.fetchUser(id: UUID())
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum TestError: Error {
    case notFound
}
```
