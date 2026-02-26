# Benchmark: Clean Architecture Missing Use Case Boundary (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation with deterministic repository stubs.
Avoid network calls and avoid sleeps in unit tests.

```swift
import XCTest

struct User: Equatable {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func fetch(id: UUID) async throws -> User
}

struct StubUserRepository: UserRepository {
    var result: Result<User, Error>

    func fetch(id: UUID) async throws -> User {
        try result.get()
    }
}

@MainActor
final class UserRepositoryTests: XCTestCase {
    func test_fetch_success_returnsUser() async throws {
        let expected = User(id: UUID(), name: "Alice")
        let repository = StubUserRepository(result: .success(expected))

        let user = try await repository.fetch(id: expected.id)

        XCTAssertEqual(user, expected)
    }

    func test_fetch_failure_returnsError() async {
        let repository = StubUserRepository(result: .failure(TestError.notFound))

        do {
            _ = try await repository.fetch(id: UUID())
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_fetch_cancellation_cancelledTask_throwsCancellation() async {
        let repository = BlockingUserRepository()
        let task = Task { try await repository.fetch(id: UUID()) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

actor BlockingUserRepository: UserRepository {
    func fetch(id: UUID) async throws -> User {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return User(id: id, name: "")
    }
}

private enum TestError: Error {
    case notFound
}
```
