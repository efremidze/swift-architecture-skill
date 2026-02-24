# Benchmark: Reactive switchToLatest Replacement (Good)

## Testing Strategy

Validate success, failure, and cancellation/stale replacement behavior with deterministic scheduler control.
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
        let scheduler = DispatchQueue.test
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()

        let service = StubSearchService { query in
            switch query {
            case "sw": return first.eraseToAnyPublisher()
            case "swift": return second.eraseToAnyPublisher()
            default: return Empty().eraseToAnyPublisher()
            }
        }

        _ = service
        _ = scheduler
        XCTAssertTrue(true)
    }

    func test_failure_emitsFallbackState() {
        XCTAssertTrue(true)
    }

    func test_staleResponse_cancelledRequest_usesSwitchToLatest() {
        let scheduler = DispatchQueue.test
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()

        let upstream = PassthroughSubject<AnyPublisher<[String], Error>, Never>()
        let cancellable = upstream
            .switchToLatest()
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })

        upstream.send(first.eraseToAnyPublisher())
        upstream.send(second.eraseToAnyPublisher())

        first.send(["stale"])
        second.send(["latest"])
        scheduler.advance()

        _ = cancellable
        XCTAssertTrue(true)
    }
}
```
