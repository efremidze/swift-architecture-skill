# Reactive Architecture Playbook (Swift + Combine/RxSwift)

Use this reference for stream-driven features (search, live updates, real-time feeds).

## Core Philosophy

```text
Input -> Publisher/Observable chain -> State -> UI
```

- Keep pipeline composition in ViewModel/Presenter, not in views.

## Canonical Combine Pattern

```swift
final class SearchViewModel<S: Scheduler>: ObservableObject
where S.SchedulerTimeType == DispatchQueue.SchedulerTimeType {
    @Published var query = ""
    @Published private(set) var results: [String] = []

    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService, scheduler: S) {
        $query
            .debounce(for: .milliseconds(300), scheduler: scheduler)
            .removeDuplicates()
            .map { query in
                service.search(query)
                    .replaceError(with: [])
            }
            .switchToLatest()
            .receive(on: scheduler)
            .sink { [weak self] values in
                self?.results = values
            }
            .store(in: &cancellables)
    }
}
```

- Debounce user text input
- Remove duplicates where meaningful
- Hop to main thread before UI-bound state writes
- Keep cancellables tied to lifecycle

## UI Integration by Stack

### SwiftUI

- Keep operator chains in `ObservableObject`/`@Observable` types, not in `View`.
- Bind UI input (`TextField`, toggle, selection) to published inputs on the model.

### UIKit (Combine)

- Keep pipelines in Presenter/ViewModel.
- Map delegate/target-action callbacks to input subjects.
- Render from a single state subscription.

```swift
import Combine
import UIKit

@MainActor
final class SearchPresenter<S: Scheduler> where S.SchedulerTimeType == DispatchQueue.SchedulerTimeType {
    let state = CurrentValueSubject<SearchResultState, Never>(.loaded([]))
    private let query = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService, scheduler: S) {
        query
            .debounce(for: .milliseconds(300), scheduler: scheduler)
            .removeDuplicates()
            .map { value in
                service.search(value)
                    .map(SearchResultState.loaded)
                    .catch { Just(.failed($0.localizedDescription)) }
            }
            .switchToLatest()
            .sink { [weak self] in self?.state.send($0) }
            .store(in: &cancellables)
    }

    func queryChanged(_ text: String) { query.send(text) }
}

// In production, pass DispatchQueue.main as the scheduler.

final class SearchViewController: UIViewController, UISearchBarDelegate {
    private let presenter: SearchPresenter<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()

    init(presenter: SearchPresenter<DispatchQueue>) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.state
            .sink { [weak self] in self?.render($0) }
            .store(in: &cancellables)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter.queryChanged(searchText)
    }

    private func render(_ state: SearchResultState) {
        // Render labels/list/error from stream state.
    }
}
```

## Operator Guidance

- `debounce`: stabilize noisy user input (search fields)
- `throttle`: limit high-frequency events (scroll, sensor)
- `flatMap`: merge concurrent async work when all responses matter
- `switchToLatest`: keep only newest request (typeahead/search)
- `share`: avoid duplicate side effects for multiple subscribers
- `catch`: recover from recoverable errors with fallback streams

Prefer `switchToLatest` over nested subscriptions for request replacement flows.

## RxSwift Mapping Notes

- `AnyPublisher` <-> `Observable`
- `AnyCancellable` <-> `DisposeBag`
- `receive(on:)` <-> `observe(on:)`
- `subscribe(on:)`: apply intentionally to offload heavy work off main thread

## Error Handling Pattern

```swift
protocol SearchService {
    func search(_ query: String) -> AnyPublisher<[String], Error>
}

enum SearchResultState: Equatable {
    case loaded([String])
    case failed(String)
}

func searchState(
    query: String,
    service: SearchService
) -> AnyPublisher<SearchResultState, Never> {
    service.search(query)
        .map(SearchResultState.loaded)
        .catch { Just(.failed($0.localizedDescription)) }
        .eraseToAnyPublisher()
}
```

- Transient failures: recover with fallback state; don't terminate the pipeline.

## Anti-Patterns and Fixes

1. Nested subscriptions:
- Smell: subscribe inside subscribe, difficult cancellation and reasoning.
- Fix: compose with `flatMap`/`switchToLatest`.

2. Missing cancellation/disposal:
- Smell: stream continues after screen deallocation or rebind.
- Fix: store `AnyCancellable` or use `DisposeBag` lifecycle correctly.

3. Business logic in view:
- Smell: view constructs pipelines and calls services directly.
- Fix: move stream orchestration to Presenter/ViewModel layer.

4. UI thread violations:
- Smell: publishing UI-bound state off main thread.
- Fix: apply `receive(on:)` / `observe(on:)` before UI mutations.

5. Unbounded fan-out:
- Smell: many subscribers trigger duplicate network calls.
- Fix: use `share`/multicasting where side effects should be single-execution.

## Testing Strategy

Inject a controlled scheduler to drive debounce/throttle. Assert emitted state sequences, not internal operator details. Use `PassthroughSubject` for service responses to simulate success, error fallback, and `switchToLatest` request replacement.

```swift
import Combine
import CombineSchedulers
import XCTest

final class SearchViewModelTests: XCTestCase {
    func test_queryEmitsResults() {
        let subject = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { _ in subject.eraseToAnyPublisher() }
        // Requires Point-Free's CombineSchedulers package.
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results.dropFirst().sink { collected.append($0) }

        vm.query = "swift"
        scheduler.advance(by: .milliseconds(300))
        subject.send(["SwiftUI", "Swift"])
        subject.send(completion: .finished)
        scheduler.advance()

        XCTAssertEqual(collected, [["SwiftUI", "Swift"]])
        cancellable.cancel()
    }

    func test_errorFallsBackToEmptyResults() {
        let subject = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { _ in subject.eraseToAnyPublisher() }
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results.dropFirst().sink { collected.append($0) }

        vm.query = "swift"
        scheduler.advance(by: .milliseconds(300))
        subject.send(completion: .failure(TestError.offline))
        scheduler.advance()

        XCTAssertEqual(collected, [[]])
        cancellable.cancel()
    }

    func test_switchToLatest_ignoresStaleInFlightResponse() {
        let first = PassthroughSubject<[String], Error>()
        let second = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService { query in
            switch query {
            case "sw": return first.eraseToAnyPublisher()
            case "swift": return second.eraseToAnyPublisher()
            default: return Empty<[String], Error>().eraseToAnyPublisher()
            }
        }
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results.dropFirst().sink { collected.append($0) }

        vm.query = "sw"
        scheduler.advance(by: .milliseconds(300))
        vm.query = "swift"
        scheduler.advance(by: .milliseconds(300))

        first.send(["stale"])
        second.send(["fresh"])
        scheduler.advance()

        XCTAssertEqual(collected, [["fresh"]])
        cancellable.cancel()
    }
}

struct StubSearchService: SearchService {
    let searchHandler: (String) -> AnyPublisher<[String], Error>
    func search(_ query: String) -> AnyPublisher<[String], Error> { searchHandler(query) }
}

private enum TestError: Error { case offline }
```

## When to Prefer Reactive Architecture

- Feature is stream-heavy: search, live feeds, real-time updates, typeahead.
- Composable async pipelines (debounce, switchToLatest, share) provide clearer intent than imperative callbacks.

## PR Review Checklist

- Streams are composed without nested subscriptions.
- Cancellation/disposal is lifecycle-safe.
- UI-bound updates are marshaled to main thread.
- Operators match intent (`debounce`, `throttle`, `switchToLatest`, `share`).
- Views/controllers do not hold business pipeline logic.
- Error handling recovers at stream boundaries; transient failures don't terminate the pipeline.
