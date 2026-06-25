# Real-World Corpus: Clean Architecture Use Case Boundary (Good)

Source:
- Synthetic — representative of production Clean Architecture testing patterns in Swift

## Testing Strategy

Tests operate at the use case boundary using a stub repository protocol.
The domain layer has no dependency on UIKit or SwiftUI.
Success, failure, and cancellation are all covered with deterministic stubs and no sleeps.

```swift
import XCTest

// MARK: - Domain

struct User: Equatable {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func fetchUser(id: UUID) async throws -> User
}

final class LoadUser {
    private let repository: UserRepository
    init(repository: UserRepository) { self.repository = repository }
    func execute(id: UUID) async throws -> User {
        try await repository.fetchUser(id: id)
    }
}

// MARK: - Stubs

struct StubUserRepository: UserRepository {
    var result: Result<User, Error>
    func fetchUser(id: UUID) async throws -> User { try result.get() }
}

struct SlowUserRepository: UserRepository {
    func fetchUser(id: UUID) async throws -> User {
        try await Task.sleep(nanoseconds: 10_000_000_000)
        return User(id: id, name: "Slow")
    }
}

// MARK: - Tests

final class LoadUserTests: XCTestCase {
    func test_execute_success_returnsUser() async throws {
        let expected = User(id: UUID(), name: "Alice")
        let useCase = LoadUser(repository: StubUserRepository(result: .success(expected)))
        let result = try await useCase.execute(id: expected.id)
        XCTAssertEqual(result, expected)
    }

    func test_execute_failure_throwsRepositoryError() async {
        struct RepoError: Error {}
        let useCase = LoadUser(repository: StubUserRepository(result: .failure(RepoError())))
        do {
            _ = try await useCase.execute(id: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is RepoError)
        }
    }

    func test_execute_cancellation_throwsCancellationError() async {
        let useCase = LoadUser(repository: SlowUserRepository())
        let task = Task { try await useCase.execute(id: UUID()) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```
