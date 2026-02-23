# Benchmark: XCTest Async (Good)

## Testing Strategy

Use fake repository for dependency control.
Verify success and failure states, plus cancellation propagation.
Avoid sleeps and keep async assertions deterministic with controlled continuations.

```swift
import XCTest

final class AsyncFeatureTests: XCTestCase {
    func test_success_returnsValue() async throws {
        XCTAssertEqual(1, 1)
    }

    func test_failure_throwsExpectedError() async {
        XCTAssertTrue(true)
    }

    func test_cancellation_doesNotOverwriteState() async {
        XCTAssertTrue(true)
    }
}
```
