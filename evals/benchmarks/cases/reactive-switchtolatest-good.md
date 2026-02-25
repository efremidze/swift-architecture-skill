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
        let requests = PassthroughSubject<AnyPublisher<[String], Never>, Never>()
        let response = PassthroughSubject<[String], Never>()
        var values: [[String]] = []
        let cancellable = requests
            .switchToLatest()
            .sink(receiveValue: { values.append($0) })

        requests.send(response.eraseToAnyPublisher())
        response.send(["loaded"])

        _ = cancellable
        XCTAssertEqual(values, [["loaded"]])
    }

    func test_failure_emitsFallbackState() {
        enum TestError: Error { case offline }

        let response = PassthroughSubject<[String], Error>()
        var values: [[String]] = []
        let cancellable = response
            .catch { _ in Just(["fallback"]).setFailureType(to: Error.self) }
            .sink(receiveCompletion: { _ in }, receiveValue: { values.append($0) })

        response.send(completion: .failure(TestError.offline))

        _ = cancellable
        XCTAssertEqual(values, [["fallback"]])
    }

    func test_cancellation_ignoresStaleResponse() {
        let requests = PassthroughSubject<AnyPublisher<[String], Never>, Never>()
        let first = PassthroughSubject<[String], Never>()
        let second = PassthroughSubject<[String], Never>()
        var values: [[String]] = []
        let cancellable = requests
            .switchToLatest()
            .sink(receiveValue: { values.append($0) })

        requests.send(first.eraseToAnyPublisher())
        requests.send(second.eraseToAnyPublisher())
        first.send(["stale"])
        second.send(["latest"])

        _ = cancellable
        XCTAssertEqual(values, [["latest"]])
    }
}
```
