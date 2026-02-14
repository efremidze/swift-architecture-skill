# MVI Playbook (Swift + SwiftUI/UIKit)

Use this reference when strict unidirectional data flow and deterministic state transitions are required.

## Mental Model

```text
Intent -> Reducer -> New State -> View
                 -> Effect -> Action -> Reducer
```

Core rules:
- Keep one source of truth: `State`.
- Keep reducer logic deterministic.
- Isolate side effects in `Effect`.
- Feed effect output back as `Action`.

## Core Types

### State

- Use value types (`struct`) only.
- Keep state equatable/serializable where practical.
- Store canonical state, not redundant derived values.

```swift
struct CounterState: Equatable {
    var count = 0
    var isLoading = false
    var error: String?
}
```

### Intent

- Represent user-driven input only.
- Do not use intents for network responses.

```swift
enum CounterIntent {
    case incrementTapped
    case decrementTapped
    case resetTapped
}
```

### Action

- Represent internal events and effect results.
- Reducer handles actions to complete async loops.

```swift
enum CounterAction {
    case incrementResponse(Result<Int, Error>)
    case decrementResponse(Result<Int, Error>)
    case resetResponse(Result<Int, Error>)
}
```

### Effect

- Encapsulate async side effects.
- Keep effect execution in the store.

```swift
enum Effect<Action> {
    case none
    case run(() async throws -> Action)
}
```

## Reducer Pattern

- Reducer over `Intent`: mutate state for immediate transitions and optionally return effect.
- Reducer over `Action`: finish transition from effect output.
- Avoid direct side effects inside reducer branches.

```swift
protocol CounterServicing {
    func increment() async throws -> Int
    func decrement() async throws -> Int
    func reset() async throws -> Int
}

func reduce(
    state: inout CounterState,
    intent: CounterIntent,
    service: CounterServicing
) -> Effect<CounterAction>? {
    switch intent {
    case .incrementTapped:
        state.isLoading = true
        return .run {
            let value = try await service.increment()
            return .incrementResponse(.success(value))
        }
    case .decrementTapped:
        state.isLoading = true
        return .run {
            let value = try await service.decrement()
            return .decrementResponse(.success(value))
        }
    case .resetTapped:
        state.isLoading = true
        return .run {
            let value = try await service.reset()
            return .resetResponse(.success(value))
        }
    }
}
```

## Store Pattern

- Keep store on main actor for UI mutation safety.
- Receive `Intent`, run reducer, execute `Effect`, dispatch `Action`.
- Add cancellation and request versioning for concurrent requests.

```swift
@MainActor
final class Store<State, Intent, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reduceIntent: (inout State, Intent) -> Effect<Action>?
    private let reduceAction: (inout State, Action) -> Void

    init(
        initial: State,
        reduceIntent: @escaping (inout State, Intent) -> Effect<Action>?,
        reduceAction: @escaping (inout State, Action) -> Void
    ) {
        self.state = initial
        self.reduceIntent = reduceIntent
        self.reduceAction = reduceAction
    }

    func send(_ intent: Intent) {
        guard let effect = reduceIntent(&state, intent) else { return }
        handle(effect)
    }

    private func handle(_ effect: Effect<Action>) {
        switch effect {
        case .none:
            break
        case .run(let operation):
            Task {
                do {
                    let action = try await operation()
                    reduceAction(&state, action)
                } catch {
                    // Map to failure action as needed.
                }
            }
        }
    }
}
```

## View Guidance

- Render `store.state` only.
- Send user events through `store.send(intent)`.
- Never mutate domain state directly in views.

```swift
struct CounterView: View {
    @StateObject var store: Store<CounterState, CounterIntent, CounterAction>

    var body: some View {
        VStack {
            Text("Count: \(store.state.count)")
            if store.state.isLoading { ProgressView() }
            Button("+") { store.send(.incrementTapped) }
            Button("-") { store.send(.decrementTapped) }
            Button("Reset") { store.send(.resetTapped) }
        }
    }
}
```

## Concurrency Rules

- Track active tasks by intent/effect key where duplicate requests are possible.
- Cancel stale in-flight work before starting a newer request.
- Use request IDs when responses can arrive out-of-order.
- Keep shared mutable service state in actors.

## Anti-Patterns and Fixes

1. Side effects inside reducer:
- Smell: analytics/network calls directly in reducer branch.
- Fix: emit `Effect` and handle through action loop.

2. Intent and action merged:
- Smell: one enum for both user input and effect output.
- Fix: separate `Intent` and `Action`.

3. Multiple sources of truth:
- Smell: local `@State` mirrors store state.
- Fix: keep canonical state in store only.

4. Derived fields stored redundantly:
- Smell: persisted `isEven` with `count`.
- Fix: compute derived properties.

5. Monolithic reducer:
- Smell: very large switch spanning unrelated domains.
- Fix: split reducers by feature and combine.

## Testing Expectations

- Unit test intent reducer transitions.
- Unit test action reducer success/failure transitions.
- Verify cancellation and stale-response handling.
- Assert state-machine behavior, not view details.

Example first test:

```swift
struct StubCounterService: CounterServicing {
    func increment() async throws -> Int { 1 }
    func decrement() async throws -> Int { 0 }
    func reset() async throws -> Int { 0 }
}

func test_increment_setsLoading_andReturnsEffect() {
    var state = CounterState()
    let service = StubCounterService()
    let effect = reduce(
        state: &state,
        intent: .incrementTapped,
        service: service
    )
    XCTAssertTrue(state.isLoading)
    XCTAssertNotNil(effect)
}
```

## When to Prefer MVI

Prefer MVI for:
- complex state machines
- heavy concurrency/effect orchestration
- high determinism and testability requirements

Prefer MVVM when:
- screen complexity is moderate
- lower boilerplate is more important than strict state-machine modeling

## PR Review Checklist

- State is value-based and canonical.
- Reducers are deterministic and side-effect free.
- Effects are isolated and mapped back into actions.
- Cancellation/versioning exists for concurrent requests.
- View sends intents only; no direct business mutation.
- Reducer tests cover success, failure, and cancellation.
