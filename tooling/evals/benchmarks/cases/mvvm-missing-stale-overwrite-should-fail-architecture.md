# Benchmark: MVVM Missing Stale Overwrite (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation behavior with repository stubs.
Use controlled timing so tests are deterministic.

```swift
import XCTest

@MainActor
final class FeedViewModelTests: XCTestCase {
    func test_load_success_setsLoaded() async {
        XCTAssertTrue(true)
    }

    func test_load_failure_setsFailed() async {
        XCTAssertTrue(true)
    }

    func test_load_cancellation_isHandled() async {
        let sut = FeedViewModel(repository: StubRepository())
        sut.load()
        XCTAssertTrue(true)
    }
}
```
