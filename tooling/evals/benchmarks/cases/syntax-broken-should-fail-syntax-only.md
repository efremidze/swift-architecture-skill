# Benchmark: Syntax Broken (Should Fail Syntax Only)

## Testing Strategy

Validate success, failure, and cancellation with stub dependencies and deterministic scheduler.

```swift
import XCTest

final class BrokenSyntaxTests: XCTestCase {
    func test_success_path() {
        XCTAssertEqual(1, 1
    }

    func test_failure_path() {
        XCTAssertTrue(true)
    }

    func test_cancellation_path() {
        XCTAssertTrue(true)
    }
}
```
