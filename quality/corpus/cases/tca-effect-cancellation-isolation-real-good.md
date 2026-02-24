# Real-World Corpus: TCA Cancellation Isolation (Good)

Source:
- https://raw.githubusercontent.com/pointfreeco/swift-composable-architecture/main/Tests/ComposableArchitectureTests/EffectCancellationIsolationTests.swift

## Testing Strategy

Real-world TCA reducer tests validate cancellation isolation and stale-work replacement.
The reducer uses an explicit cancellation ID with cancel-in-flight behavior.

```swift
import ComposableArchitecture
import Testing

@Suite
struct EffectCancellationIsolationTests {
  @Test
  func testIsolation1() async {
    let store = await TestStore(initialState: Feature.State()) {
      Feature()
    }
    await store.send(.start)
    await store.receive(\.response) { $0.value = 42 }
    await store.send(.stop)
  }

  @Test
  func testIsolation2() async {
    let store = await TestStore(initialState: Feature.State()) {
      Feature()
    }
    await store.send(.start)
    await store.receive(\.response) { $0.value = 42 }
    await store.send(.stop)
  }
}

@Reducer
private struct Feature {
  struct State: Equatable { var value = 0 }
  enum Action { case response(Int), start, stop }
  enum CancelID { case longLiving }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .response(let value):
        state.value = value
        return .none
      case .start:
        return .run { send in
          await send(.response(42))
          try await Task.never()
        }
        .cancellable(id: CancelID.longLiving, cancelInFlight: true)
      case .stop:
        return .cancel(id: CancelID.longLiving)
      }
    }
  }
}
```
