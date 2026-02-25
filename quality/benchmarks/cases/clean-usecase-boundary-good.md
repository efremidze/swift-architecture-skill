# Benchmark: Clean Architecture Use Case Boundary (Good)

## Testing Strategy

Validate success, failure, and cancellation propagation at the use-case boundary with repository stubs.
Keep async behavior deterministic and avoid sleeps in tests.

```swift
import XCTest

struct User: Equatable {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func fetch(id: UUID) async throws -> User
}

struct LoadUser {
    let repository: UserRepository

    func execute(id: UUID) async throws -> User {
        try await repository.fetch(id: id)
    }
}

struct StubUserRepository: UserRepository {
    var result: Result<User, Error>

    func fetch(id: UUID) async throws -> User {
        try result.get()
    }
}

@MainActor
final class LoadUserTests: XCTestCase {
    func test_execute_success_returnsUser() async throws {
        let expected = User(id: UUID(), name: "Alice")
        let sut = LoadUser(repository: StubUserRepository(result: .success(expected)))

        let user = try await sut.execute(id: expected.id)

        XCTAssertEqual(user, expected)
    }

    func test_execute_failure_propagatesError() async {
        let sut = LoadUser(repository: StubUserRepository(result: .failure(TestError.notFound)))

        do {
            _ = try await sut.execute(id: UUID())
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_execute_cancellation_cancelledTask_throwsCancellation() async {
        let sut = LoadUser(repository: BlockingUserRepository())
        let task = Task { try await sut.execute(id: UUID()) }
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
        await Task.yield()
        return User(id: id, name: "")
    }
}

private enum TestError: Error {
    case notFound
}
```
