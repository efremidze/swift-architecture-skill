# Benchmark: MVI Missing Request ID Gate (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and stale-response cancellation behavior with deterministic stubs.
Use reducer tests with controlled actions and avoid sleeps.

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
    case .searchResponse(_, .success(let results)):
        state.results = results
    case .searchResponse(_, .failure(let error)):
        state.errorMessage = String(describing: error)
    }
}

final class SearchReducerTests: XCTestCase {
    func test_success_updatesResults() {
        var state = SearchState(latestRequestID: UUID())

        reduce(state: &state, action: .searchResponse(requestID: UUID(), .success(["latest"])))

        XCTAssertEqual(state.results, ["latest"])
    }

    func test_failure_updatesError() {
        var state = SearchState(latestRequestID: UUID())

        reduce(state: &state, action: .searchResponse(requestID: UUID(), .failure(TestError.offline)))

        XCTAssertNotNil(state.errorMessage)
    }

    func test_staleResponse_cancelledRequest_isAppliedWithoutRequestIDGate() {
        let latestID = UUID()
        let staleID = UUID()
        var state = SearchState(latestRequestID: latestID, results: ["current"])

        reduce(state: &state, action: .searchResponse(requestID: staleID, .success(["stale"])))

        XCTAssertEqual(state.results, ["stale"])
    }
}

private enum TestError: Error {
    case offline
}
```
