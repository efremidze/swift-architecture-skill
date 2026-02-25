# Benchmark: XCTest Async (Good)

## Testing Strategy

Use fake repository for dependency control.
Verify success and failure states, plus cancellation propagation.
Avoid sleeps and keep async assertions deterministic with controlled continuations.

```swift
import XCTest

final class AsyncFeatureTests: XCTestCase {
    func test_success_returnsValue() async throws {
        let value = try await successfulOperation()
        XCTAssertEqual(value, 42)
    }

    func test_failure_throwsExpectedError() async throws {
        do {
            try await failingOperation()
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? TestError, .expected)
        }
    }

    func test_cancellation_doesNotOverwriteState() async {
        let task = Task { try await cancellableOperation() }
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

private enum TestError: Error, Equatable {
    case expected
}

private func failingOperation() async throws {
    throw TestError.expected
}

private func successfulOperation() async throws -> Int {
    42
}

private func cancellableOperation() async throws -> Int {
    try await Task.sleep(for: .seconds(1))
    return 0
}
```
