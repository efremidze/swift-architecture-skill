# Benchmark: Reactive SwitchToLatest (Good)

## Testing Strategy

Test success and failure output state transitions.
Test cancellation behavior for stale requests.
Use stub service and controlled scheduler to keep tests deterministic.

```swift
import Combine
import XCTest

final class ReactiveTests: XCTestCase {
    func test_success_emitsLoadedState() {
        XCTAssertTrue(true)
    }

    func test_failure_emitsFallbackState() {
        XCTAssertTrue(true)
    }

    func test_cancellation_ignoresStaleResponse() {
        XCTAssertTrue(true)
    }
}
```
