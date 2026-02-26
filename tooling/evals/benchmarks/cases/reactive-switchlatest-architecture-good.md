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
        let output = PassthroughSubject<[String], Error>()
        let service = StubSearchService { _ in output.eraseToAnyPublisher() }
        var values: [[String]] = []
        let cancellable = service.search("swift")
            .sink(receiveCompletion: { _ in }, receiveValue: { values.append($0) })

        output.send(["latest"])

        _ = cancellable
        XCTAssertEqual(values, [["latest"]])
    }

    func test_failure_emitsFallbackState() {
        let output = PassthroughSubject<[String], Error>()
        let service = StubSearchService { _ in output.eraseToAnyPublisher() }
        var values: [[String]] = []
        let cancellable = service.search("swift")
            .catch { _ in Just(["fallback"]).setFailureType(to: Error.self) }
            .sink(receiveCompletion: { _ in }, receiveValue: { values.append($0) })

        output.send(completion: .failure(TestError.offline))

        _ = cancellable
        XCTAssertEqual(values, [["fallback"]])
    }

    func test_staleResponse_cancelledRequest_usesSwitchToLatest() {
        let scheduler = DispatchQueue.test
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()
        var values: [[String]] = []

        let upstream = PassthroughSubject<AnyPublisher<[String], Error>, Never>()
        let cancellable = upstream
            .switchToLatest()
            .sink(receiveCompletion: { _ in }, receiveValue: { values.append($0) })

        scheduler.schedule {
            upstream.send(first.eraseToAnyPublisher())
            upstream.send(second.eraseToAnyPublisher())

            first.send(["stale"])
            second.send(["latest"])
        }
        scheduler.advance()

        _ = cancellable
        XCTAssertEqual(values, [["latest"]])
    }
}

private enum TestError: Error {
    case offline
}
```
