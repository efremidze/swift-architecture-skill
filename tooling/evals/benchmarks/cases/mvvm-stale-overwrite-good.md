# Benchmark: MVVM Stale Overwrite (Good)

## Testing Strategy

Validate success, failure, and cancellation/stale overwrite behavior.
Use repository stubs and controlled continuations for deterministic async tests.

```swift
import XCTest

@MainActor
final class FeedViewModelTests: XCTestCase {
    func test_load_success_setsLoaded() async {
        let sut = FeedViewModel(repository: StubRepository(sequence: [["latest"]]))
        await sut.load()

        XCTAssertEqual(sut.state.items.map(\.title), ["latest"])
        XCTAssertNil(sut.state.errorMessage)
    }

    func test_load_failure_setsFailed() async {
        let sut = FeedViewModel(repository: StubRepository(error: TestError.offline))
        await sut.load()

        XCTAssertNotNil(sut.state.errorMessage)
    }

    func test_load_cancellation_ignoresStaleOverwrite() async {
        let stale = ["stale"]
        let latest = ["latest"]

        let sut = FeedViewModel(repository: StubRepository(sequence: [stale, latest], delayedFirstResponse: true))
        async let requestA: Void = sut.load() // request A
        await sut.load() // request B
        await requestA

        // stale-overwrite-assert: latest wins
        XCTAssertEqual(sut.state.items.map(\.title), ["latest"])
    }
}

private enum TestError: Error {
    case offline
}
```
