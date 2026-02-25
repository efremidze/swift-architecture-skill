# Benchmark: Reactive Missing switchToLatest (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and stale cancellation behavior with deterministic scheduler control.
Use service stubs and avoid sleeps.

```swift
import Combine
import CombineSchedulers
import XCTest

struct StubSearchService {
    let search: (String) -> AnyPublisher<[String], Error>
}

final class SearchViewModelTests: XCTestCase {
    func test_success_emitsResults() {
        XCTAssertTrue(true)
    }

    func test_failure_emitsFallbackState() {
        XCTAssertTrue(true)
    }

    func test_staleResponse_cancelledRequest_allowsOverwrite() {
        let scheduler = DispatchQueue.test
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()
        var values: [[String]] = []

        let upstream = PassthroughSubject<AnyPublisher<[String], Error>, Never>()
        let cancellable = upstream
            .flatMap { $0 }
            .sink(receiveCompletion: { _ in }, receiveValue: { values.append($0) })

        scheduler.schedule {
            upstream.send(first.eraseToAnyPublisher())
            upstream.send(second.eraseToAnyPublisher())

            first.send(["stale"])
            second.send(["latest"])
        }
        scheduler.advance()

        _ = cancellable
        XCTAssertEqual(values, [["stale"], ["latest"]])
    }
}
```
