# TCA Playbook (Swift + SwiftUI/UIKit)

Use this reference for strict unidirectional flow, strong composition, and `TestStore`-driven testing.

## Mental Model

```text
View -> store.send(Action)
Reducer(State, Action) -> state mutation + Effect<Action>
Effect emits Action -> reducer
```

- Value-based state
- Reducer-driven decisions
- Isolated side effects via effects
- Dependency injection through TCA dependencies
- Feature composition with scoped reducers

## Canonical Feature Shape

```swift
import ComposableArchitecture

@Reducer
struct CounterFeature {
  enum CancelID { case fact }

  enum FactError: Error, Equatable {
    case unavailable
  }

  @ObservableState
  struct State: Equatable {
    var count = 0
    var isLoading = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: Equatable {
    case incrementTapped
    case decrementTapped
    case factButtonTapped
    case factResponse(Result<String, FactError>)
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  @Dependency(\.numberFact) var numberFact

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementTapped:
        state.count += 1
        return .none

      case .decrementTapped:
        state.count -= 1
        return .none

      case .factButtonTapped:
        state.isLoading = true
        let n = state.count
        return .run { send in
          do {
            let fact = try await numberFact.fetch(n)
            await send(.factResponse(.success(fact)))
          } catch is CancellationError {
            // Cancellation is expected when a new request replaces this one.
          } catch {
            await send(.factResponse(.failure(.unavailable)))
          }
        }
        .cancellable(id: CancelID.fact, cancelInFlight: true)

      case .factResponse(.success(let fact)):
        state.isLoading = false
        state.alert = AlertState { TextState(fact) }
        return .none

      case .factResponse(.failure):
        state.isLoading = false
        state.alert = AlertState { TextState("Could not load fact.") }
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
```

## View Integration

- Send actions from the view
- Never mutate business state directly in the view
- Observe the smallest practical state slice

```swift
struct CounterView: View {
  @Bindable var store: StoreOf<CounterFeature>

  var body: some View {
    VStack {
      Text("Count: \(store.count)")
      Button("+") { store.send(.incrementTapped) }
      Button("-") { store.send(.decrementTapped) }
      Button("Fact") { store.send(.factButtonTapped) }
      if store.isLoading { ProgressView() }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
```

// TCA < 1.7: wrap with `WithViewStore(store, observe: { $0 }) { viewStore in ... }` and use `viewStore.send` / `viewStore.count`.

**UIKit:** Hold a `ViewStore` in the view controller, subscribe to `viewStore.publisher`, and render state in a single `render(_:)` method. Map target-action callbacks to `viewStore.send(.action)`.

## Composition Patterns

- Use `Scope(state:action:)` for parent-child feature composition
- Use `IdentifiedArrayOf` + `.forEach` for stable-identity collections

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var counter = CounterFeature.State()
  }

  enum Action: Equatable {
    case counter(CounterFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.counter, action: \.counter) {
      CounterFeature()
    }
  }
}
```

## Dependency Rules

- Keep dependency surfaces small and capability-focused
- Inject via `@Dependency`
- Never place dependencies in state
- Avoid singleton calls in reducers

```swift
struct NumberFactClient {
  var fetch: @Sendable (Int) async throws -> String
}

extension NumberFactClient: DependencyKey {
  static let liveValue = Self(fetch: { number in
    "\(number) is a good number."
  })

  static let testValue = Self(fetch: { _ in
    "Test fact"
  })
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}
```

## Effects and Concurrency

- Use `.run` for async work; send results back as actions
- Add `.cancellable(id:cancelInFlight:)` for re-entrant requests
- Add request versioning when cancellation alone is insufficient

## Navigation Pattern

- `@Presents var alert: AlertState<Action.Alert>?`
- `destination: Destination.State?`
- Attach a matching `.ifLet` reducer for each presentation action (`alert`, `destination`, etc.)

## Testing with `TestStore`

Use `TestStore` for deterministic action/state assertions. Inject `withDependencies` to control service responses. Use `TestClock` for time-dependent cancellation tests.

```swift
import XCTest
import ComposableArchitecture

@MainActor
final class CounterFeatureTests: XCTestCase {
  func testIncrement() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    }

    await store.send(.incrementTapped) {
      $0.count = 1
    }
  }

  func testFactSuccess() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in "42 is great" }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.success("42 is great"))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("42 is great") }
    }
  }

  func testFactFailure() async {
    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in throw CounterFeature.FactError.unavailable }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.receive(.factResponse(.failure(.unavailable))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("Could not load fact.") }
    }
  }

  func testFactCancellation_replacesInFlightRequest() async {
    let clock = TestClock()

    actor Sequence {
      var values = ["first", "second"]
      func next() -> String { values.removeFirst() }
    }
    let sequence = Sequence()

    let store = TestStore(initialState: CounterFeature.State()) {
      CounterFeature()
    } withDependencies: {
      $0.numberFact.fetch = { _ in
        let value = await sequence.next()
        try await clock.sleep(for: .seconds(1))
        return value
      }
    }

    await store.send(.factButtonTapped) {
      $0.isLoading = true
    }
    await store.send(.factButtonTapped)

    await clock.advance(by: .seconds(1))

    await store.receive(.factResponse(.success("second"))) {
      $0.isLoading = false
      $0.alert = AlertState { TextState("second") }
    }
  }
}
```

## Anti-Patterns and Fixes

1. Massive feature with no composition:
- Smell: giant reducer handling unrelated domains.
- Fix: split into child reducers and compose via `Scope`.

2. Reference types in state:
- Smell: class instances or shared mutable collections in state.
- Fix: keep state value-based and equatable.

3. Business work in views:
- Smell: view calls services or transforms domain data.
- Fix: move logic to reducer/effects and expose render-ready state.

4. Side effects directly in reducer:
- Smell: analytics/network calls inline without effect boundary.
- Fix: route through dependencies and effects.

5. Duplicate state outside store:
- Smell: local `@State` mirrors store state.
- Fix: keep single source of truth in store.

6. Over-observing large state:
- Smell: broad observation triggers unnecessary re-renders.
- Fix: observe scoped state and split view/store boundaries.

7. Missing cancellation:
- Smell: overlapping effects overwrite current intent.
- Fix: use `.cancellable(id:cancelInFlight:)` and request IDs when needed.

## When to Prefer TCA

- App has many stateful workflows requiring strong composition, modular scaling, and `TestStore`-driven test determinism.
- TCA dependency is already in the project or the team is committed to UDF discipline.

## PR Review Checklist

- State is value-based and equatable.
- Reducer avoids direct side effects.
- Dependencies are injected and overrideable in tests.
- Features compose with `Scope`/`forEach`.
- Navigation is modeled in state.
- Views render and send actions only.
