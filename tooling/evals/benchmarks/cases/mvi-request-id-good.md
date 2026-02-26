# Benchmark: MVI Request ID Gate (Good)

## Testing Strategy

Validate success, failure, and stale-response cancellation behavior with deterministic service stubs.
Use controlled request IDs in reducer tests and avoid sleeps.

```swift
import XCTest

struct SearchState: Equatable {
    var latestRequestID: UUID?
    var results: [String] = []
    var errorMessage: String?
}

enum SearchAction {
    case searchStarted(requestID: UUID)
    case searchResponse(requestID: UUID, Result<[String], Error>)
}

func reduce(state: inout SearchState, action: SearchAction) {
    switch action {
    case .searchStarted(let requestID):
        state.latestRequestID = requestID
        state.errorMessage = nil
    case .searchResponse(let requestID, .success(let results)):
        guard requestID == state.latestRequestID else { return }
        state.results = results
    case .searchResponse(let requestID, .failure(let error)):
        guard requestID == state.latestRequestID else { return }
        state.errorMessage = String(describing: error)
    }
}

final class SearchReducerTests: XCTestCase {
    func test_success_latestRequest_updatesResults() {
        let requestID = UUID()
        var state = SearchState(latestRequestID: requestID)

        reduce(state: &state, action: .searchResponse(requestID: requestID, .success(["latest"])))

        XCTAssertEqual(state.results, ["latest"])
    }

    func test_failure_latestRequest_updatesError() {
        let requestID = UUID()
        var state = SearchState(latestRequestID: requestID)

        reduce(state: &state, action: .searchResponse(requestID: requestID, .failure(TestError.offline)))

        XCTAssertNotNil(state.errorMessage)
    }

    func test_staleResponse_cancelledRequest_isIgnored() {
        let latestID = UUID()
        let staleID = UUID()
        var state = SearchState(latestRequestID: latestID, results: ["current"])

        reduce(state: &state, action: .searchResponse(requestID: staleID, .success(["stale"])))

        XCTAssertEqual(state.results, ["current"])
    }
}

private enum TestError: Error {
    case offline
}
```
