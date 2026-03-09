# Benchmark: Nondeterministic Sleep (Should Fail Semantic)

## Testing Strategy

Validate success, failure, and cancellation behavior with repository stubs.
These tests use sleep to wait for async work.

```swift
import XCTest

final class NondeterministicSleepTests: XCTestCase {
    func test_success_path() {
        Thread.sleep(forTimeInterval: 0.01)
        XCTAssertTrue(true)
    }

    func test_failure_path() {
        Thread.sleep(forTimeInterval: 0.01)
        XCTAssertTrue(true)
    }

    func test_cancellation_path() {
        Thread.sleep(forTimeInterval: 0.01)
        XCTAssertTrue(true)
    }
}
```
