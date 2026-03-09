# Benchmark: VIPER Missing Presenter Wiring (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation with deterministic stubs.
Avoid sleeps and network calls in tests.

```swift
import XCTest

struct User {
    let id: UUID
    let name: String
}

protocol ProfileInteracting {
    func loadUser() async throws -> User
}

struct StubProfileInteractor: ProfileInteracting {
    var load: () async throws -> User
    func loadUser() async throws -> User { try await load() }
}

@MainActor
final class ProfileInteractorTests: XCTestCase {
    func test_load_success_returnsUser() async throws {
        let interactor = StubProfileInteractor(load: { User(id: UUID(), name: "Alice") })

        let user = try await interactor.loadUser()

        XCTAssertEqual(user.name, "Alice")
    }

    func test_load_failure_returnsError() async {
        let interactor = StubProfileInteractor(load: { throw TestError.offline })

        do {
            _ = try await interactor.loadUser()
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func test_load_cancellation_cancelsTask() async {
        let interactor = StubProfileInteractor(load: { throw CancellationError() })

        do {
            _ = try await interactor.loadUser()
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
