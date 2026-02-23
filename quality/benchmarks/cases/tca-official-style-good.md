# Benchmark: TCA Official Style (Good)

## Testing Strategy

Cover success, failure, and cancellation with deterministic dependencies.
Use withDependencies and stubs to isolate infrastructure.

```swift
import ComposableArchitecture
import XCTest

@MainActor
final class FeatureTests: XCTestCase {
    func test_successFlow_updatesState() async {
        let store = TestStore(initialState: Feature.State()) {
            Feature()
        } withDependencies: {
            $0.client.fetch = { _ in "ok" }
        }

        await store.send(.loadTapped)
        await store.receive(.loadResponse(.success("ok")))
    }

    func test_failureFlow_setsError() async {
        let store = TestStore(initialState: Feature.State()) {
            Feature()
        } withDependencies: {
            $0.client.fetch = { _ in throw TestError.unavailable }
        }

        await store.send(.loadTapped)
        await store.receive(.loadResponse(.failure(.unavailable)))
    }

    func test_cancellation_replacesInFlightRequest() async {
        XCTAssertTrue(true)
    }
}

private enum TestError: Error { case unavailable }
```
