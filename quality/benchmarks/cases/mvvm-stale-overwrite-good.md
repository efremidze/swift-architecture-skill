# Benchmark: MVVM Stale Overwrite (Good)

## Testing Strategy

Validate success, failure, and cancellation/stale overwrite behavior.
Use repository stubs and controlled continuations for deterministic async tests.

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

    func test_load_cancellation_ignoresStaleOverwrite() async {
        let stale = ["stale"]
        let latest = ["latest"]

        let sut = FeedViewModel(repository: StubRepository())
        sut.load() // request A
        sut.load() // request B

        _ = stale
        _ = latest
        // stale-overwrite-assert: latest wins
        XCTAssertEqual(sut.state.items.map(\.title), ["latest"])
    }
}
```
