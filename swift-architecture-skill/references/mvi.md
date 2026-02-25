# MVI Playbook (Swift + SwiftUI/UIKit)

Use this reference for strict unidirectional flow and deterministic state transitions.

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
enum Loadable<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

struct CounterState: Equatable {
    var load: Loadable<Int> = .idle

    var count: Int {
        guard case .loaded(let value) = load else { return 0 }
        return value
    }
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

Action reducer for completing async transitions:

```swift
func reduce(state: inout CounterState, action: CounterAction) {
    switch action {
    case .incrementResponse(.success(let value)):
        state.load = .loaded(value)
    case .incrementResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    case .decrementResponse(.success(let value)):
        state.load = .loaded(value)
    case .decrementResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    case .resetResponse(.success(let value)):
        state.load = .loaded(value)
    case .resetResponse(.failure(let error)):
        state.load = .failed(error.localizedDescription)
    }
}
```

### Effect

- Encapsulate async side effects.
- Keep effect execution in the store.

```swift
enum Effect<Action> {
    case none
    case run(() async throws -> Action)
    case cancellable(id: AnyHashable, () async throws -> Action)
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
        state.load = .loading
        return .run {
            do {
                let value = try await service.increment()
                return .incrementResponse(.success(value))
            } catch {
                return .incrementResponse(.failure(error))
            }
        }
    case .decrementTapped:
        state.load = .loading
        return .run {
            do {
                let value = try await service.decrement()
                return .decrementResponse(.success(value))
            } catch {
                return .decrementResponse(.failure(error))
            }
        }
    case .resetTapped:
        state.load = .loading
        return .run {
            do {
                let value = try await service.reset()
                return .resetResponse(.success(value))
            } catch {
                return .resetResponse(.failure(error))
            }
        }
    }
}
```

This signature is a pragmatic shortcut: passing `service` into `reduce` keeps call sites simple, but the reducer is environment-coupled. If you want stricter MVI purity, make `reduce` return effect descriptors and run them outside the reducer.

```swift
enum CounterEffect {
    case increment
    case decrement
    case reset
}

func reduce(state: inout CounterState, intent: CounterIntent) -> CounterEffect? {
    switch intent {
    case .incrementTapped:
        state.load = .loading
        return .increment
    case .decrementTapped:
        state.load = .loading
        return .decrement
    case .resetTapped:
        state.load = .loading
        return .reset
    }
}

func run(_ effect: CounterEffect, service: CounterServicing) async -> CounterAction {
    do {
        switch effect {
        case .increment:
            return .incrementResponse(.success(try await service.increment()))
        case .decrement:
            return .decrementResponse(.success(try await service.decrement()))
        case .reset:
            return .resetResponse(.success(try await service.reset()))
        }
    } catch {
        switch effect {
        case .increment:
            return .incrementResponse(.failure(error))
        case .decrement:
            return .decrementResponse(.failure(error))
        case .reset:
            return .resetResponse(.failure(error))
        }
    }
}
```

Adapter pattern for wiring the pure `reduce/run` pair into `Store`:

```swift
@MainActor
func makeCounterStore(service: CounterServicing) -> Store<CounterState, CounterIntent, CounterAction> {
    Store(
        initial: CounterState(),
        reduceIntent: { state, intent in
            guard let effect = reduce(state: &state, intent: intent) else { return nil }
            return .run {
                await run(effect, service: service)
            }
        },
        reduceAction: { state, action in
            reduce(state: &state, action: action)
        }
    )
}
```

## Store Pattern

- Keep store on main actor for UI mutation safety.
- Receive `Intent`, run reducer, execute `Effect`, dispatch `Action`.
- Add cancellation and request versioning for concurrent requests.
- Map all expected service failures to explicit failure actions; `onUnexpectedError` should be a bug hook, not a business-error path.

```swift
@MainActor
final class Store<State, Intent, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reduceIntent: (inout State, Intent) -> Effect<Action>?
    private let reduceAction: (inout State, Action) -> Void
    private let onUnexpectedError: @MainActor (Error) -> Void
    private var activeTasks: [AnyHashable: Task<Void, Never>] = [:]

    init(
        initial: State,
        reduceIntent: @escaping (inout State, Intent) -> Effect<Action>?,
        reduceAction: @escaping (inout State, Action) -> Void,
        onUnexpectedError: @escaping @MainActor (Error) -> Void = { error in
            assertionFailure("Unexpected unmodeled effect error: \(error)")
        }
    ) {
        self.state = initial
        self.reduceIntent = reduceIntent
        self.reduceAction = reduceAction
        self.onUnexpectedError = onUnexpectedError
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
                } catch is CancellationError {
                    // Task was cancelled; no state update.
                } catch {
                    onUnexpectedError(error)
                }
            }
        case .cancellable(let id, let operation):
            activeTasks[id]?.cancel()
            activeTasks[id] = Task {
                do {
                    let action = try await operation()
                    reduceAction(&state, action)
                } catch is CancellationError {
                    // Cancelled by a newer request for the same id.
                } catch {
                    onUnexpectedError(error)
                }
                activeTasks[id] = nil
            }
        }
    }

    deinit {
        for task in activeTasks.values { task.cancel() }
    }
}
```

Map expected service failures to explicit failure actions; reserve `onUnexpectedError` for true fallthrough faults (for example decoding bugs, violated invariants, or effect wiring mistakes). If this handler fires for normal API failures, treat that as a modeling bug and add an explicit failure action path.

## Composed Reducers

Split reducers by feature and compose them.

```swift
enum AppAction {
    case counter(CounterAction)
    case settings(SettingsAction)
}

func appReduce(
    state: inout AppState,
    intent: AppIntent,
    services: AppServices
) -> Effect<AppAction>? {
    switch intent {
    case .counter(let counterIntent):
        return counterReduce(
            state: &state.counter,
            intent: counterIntent,
            service: services.counter
        )?.map(AppAction.counter)
    case .settings(let settingsIntent):
        return settingsReduce(
            state: &state.settings,
            intent: settingsIntent,
            service: services.settings
        )?.map(AppAction.settings)
    }
}
```

Add a `map` helper on `Effect` to lift child actions into parent actions:

```swift
extension Effect {
    func map<B>(_ transform: @escaping (Action) -> B) -> Effect<B> {
        switch self {
        case .none:
            return .none
        case .run(let operation):
            return .run {
                let action = try await operation()
                return transform(action)
            }
        case .cancellable(let id, let operation):
            return .cancellable(id: id) {
                let action = try await operation()
                return transform(action)
            }
        }
    }
}
```

Composition tradeoff: a single app-wide `AppIntent`/`AppAction` can become deeply nested as feature count grows. Prefer feature-scoped stores where practical, and compose only at flow boundaries (for example tab root, checkout flow, onboarding) instead of forcing one global mega-enum.

## View Guidance

- Render `store.state` only.
- Send user events through `store.send(intent)`.
- Never mutate domain state directly in views.

### SwiftUI Integration

```swift
struct CounterView: View {
    @StateObject var store: Store<CounterState, CounterIntent, CounterAction>

    var body: some View {
        VStack {
            Text("Count: \(store.state.count)")
            if case .loading = store.state.load { ProgressView() }
            Button("+") { store.send(.incrementTapped) }
            Button("-") { store.send(.decrementTapped) }
            Button("Reset") { store.send(.resetTapped) }
        }
    }
}
```

If you target iOS 17+ for SwiftUI-first features, you can replace `ObservableObject`/`@Published` stores with `@Observable` stores (as in the MVVM playbook) and use `@State` + `@Bindable` in views. Keep `ObservableObject` when the same store must expose Combine publishers to UIKit.

### UIKit Integration

In UIKit, subscribe once, render from state, and map control events to intents.

```swift
import Combine
import UIKit

final class CounterViewController: UIViewController {
    private let store: Store<CounterState, CounterIntent, CounterAction>
    private var cancellables = Set<AnyCancellable>()

    init(store: Store<CounterState, CounterIntent, CounterAction>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        store.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    @objc private func incrementTapped() {
        store.send(.incrementTapped)
    }

    private func render(_ state: CounterState) {
        title = "Count: \(state.count)"
        // Update labels/buttons/loading from state only.
    }
}
```

UIKit rules:
- keep all UI writes in `render(_:)`
- convert delegate/target-action callbacks into `Intent`

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
- Keep tests deterministic with controlled services, schedulers, or clocks.
- Assert state-machine behavior, not view details.

Example test suite:

```swift
import XCTest

struct StubCounterService: CounterServicing {
    func increment() async throws -> Int { 1 }
    func decrement() async throws -> Int { 0 }
    func reset() async throws -> Int { 0 }
}

final class CounterReducerTests: XCTestCase {
    func test_intentIncrement_setsLoading_andReturnsEffect() {
        var state = CounterState()
        let service = StubCounterService()

        let effect = reduce(
            state: &state,
            intent: .incrementTapped,
            service: service
        )

        XCTAssertEqual(state.load, .loading)
        XCTAssertNotNil(effect)
    }

    func test_actionFailure_setsError_andStopsLoading() {
        var state = CounterState(load: .loaded(3))

        reduce(state: &state, action: .incrementResponse(.failure(TestError.offline)))

        XCTAssertEqual(state.count, 0)
        if case .failed = state.load {
            // expected
        } else {
            XCTFail("Expected failed state")
        }
    }
}

struct SearchState: Equatable {
    var latestRequestID: UUID?
    var results: [String] = []
}

enum SearchAction {
    case response(requestID: UUID, Result<[String], Error>)
}

func reduce(state: inout SearchState, action: SearchAction) {
    switch action {
    case .response(let requestID, .success(let results)):
        guard requestID == state.latestRequestID else { return }
        state.results = results
    case .response:
        break
    }
}

final class SearchReducerTests: XCTestCase {
    func test_matchingLatestRequest_updatesResults() {
        let requestID = UUID()
        var state = SearchState(latestRequestID: requestID, results: [])

        reduce(
            state: &state,
            action: .response(requestID: requestID, .success(["new"]))
        )

        XCTAssertEqual(state.results, ["new"])
    }

    func test_staleResponse_isIgnored() {
        let latestID = UUID()
        let staleID = UUID()
        var state = SearchState(latestRequestID: latestID, results: ["current"])

        reduce(
            state: &state,
            action: .response(requestID: staleID, .success(["old"]))
        )

        XCTAssertEqual(state.results, ["current"])
    }
}

private enum TestError: Error {
    case offline
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
