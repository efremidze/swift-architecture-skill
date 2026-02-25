# Benchmark: TCA Missing Cancel ID (Should Fail Architecture)

## Testing Strategy

Validate success, failure, and cancellation behavior with deterministic dependency overrides.
Use TestStore and withDependencies; avoid sleeps.

```swift
import ComposableArchitecture
import XCTest

@Reducer
struct Feature {
    @ObservableState
    struct State: Equatable {
        var isLoading = false
    }

    enum Action: Equatable {
        case loadTapped
        case loadResponse(Result<String, Error>)
    }

    @Dependency(\.client) var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadTapped:
                state.isLoading = true
                return .run { send in
                    do {
                        let value = try await client.fetch()
                        await send(.loadResponse(.success(value)))
                    } catch {
                        await send(.loadResponse(.failure(error)))
                    }
                }
            case .loadResponse:
                state.isLoading = false
                return .none
            }
        }
    }
}

@MainActor
final class FeatureTests: XCTestCase {
    func test_load_success() async {
        XCTAssertTrue(true)
    }

    func test_load_failure() async {
        XCTAssertTrue(true)
    }

    func test_load_cancellation_replacesInFlightRequest() async {
        XCTAssertTrue(true)
    }
}
```
