# Reactive Architecture Playbook (Swift + Combine/RxSwift)

Use this reference for stream-driven features (search, live updates, real-time feeds).

## Core Philosophy

Model inputs, transforms, and outputs as streams.

```text
Input -> Publisher/Observable chain -> State -> UI
```

Keep stream composition in presentation or a dedicated reactive layer, not in views.

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

In production, pass `DispatchQueue.main` as the scheduler.

Rules:
- debounce user text input
- remove duplicates where meaningful
- hop to main thread before UI-bound state writes
- keep cancellables tied to lifecycle

## UI Integration by Stack

### SwiftUI Pattern

- Keep operator chains in `ObservableObject`/`@Observable` types, not in `View`.
- Bind UI input (`TextField`, toggle, selection) to published inputs on the model.

### UIKit Pattern (Combine)

- Keep pipelines in Presenter/ViewModel.
- Map delegate/target-action callbacks into input subjects.
- Render from a single state subscription.

```swift
import Combine
import UIKit

@MainActor
final class SearchPresenter {
    let state = CurrentValueSubject<SearchResultState, Never>(.loaded([]))
    private let query = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService) {
        query
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
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

final class SearchViewController: UIViewController, UISearchBarDelegate {
    private let presenter: SearchPresenter
    private var cancellables = Set<AnyCancellable>()

    init(presenter: SearchPresenter) {
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

Combine and RxSwift mapping:
- `AnyPublisher` <-> `Observable`
- `AnyCancellable` <-> `DisposeBag`
- `receive(on:)` <-> `observe(on:)`
- `subscribe(on:)` semantics should be applied intentionally to offload heavy work

## Error Handling Pattern

Recover in stream boundaries and expose user-safe state:

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

For transient failures, prefer fallback state over terminating the stream.

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

Test stream behavior deterministically:
- input -> expected output transitions
- debounce/throttle behavior with controlled schedulers
- cancellation behavior for replaced requests
- error fallback behavior

Rules:
- inject schedulers/time providers for tests
- avoid real-time sleeps when possible
- assert emitted state sequence, not internal operator details

```swift
import Combine
import CombineSchedulers
import XCTest

final class SearchViewModelTests: XCTestCase {
    func test_queryEmitsResults() {
        let subject = PassthroughSubject<[String], Error>()
        let stubService = StubSearchService(subject: subject)
        // Requires Point-Free's CombineSchedulers package.
        let scheduler = DispatchQueue.test
        let vm = SearchViewModel(service: stubService, scheduler: scheduler.eraseToAnyScheduler())

        var collected: [[String]] = []
        let cancellable = vm.$results
            .dropFirst()
            .sink { collected.append($0) }

        vm.query = "swift"

        // Advance past debounce interval.
        scheduler.advance(by: .milliseconds(300))

        // Simulate service response.
        subject.send(["SwiftUI", "Swift"])
        subject.send(completion: .finished)

        // Advance to process receive(on:).
        scheduler.advance()

        XCTAssertEqual(collected, [["SwiftUI", "Swift"]])
        cancellable.cancel()
    }
}

struct StubSearchService: SearchService {
    let subject: PassthroughSubject<[String], Error>
    func search(_ query: String) -> AnyPublisher<[String], Error> {
        subject.eraseToAnyPublisher()
    }
}
```

The canonical `SearchViewModel` already supports scheduler injection for tests.

## When to Prefer Reactive Architecture

Prefer when:
- feature is event-heavy and stream-oriented
- real-time updates and transformations are core behavior
- composable async pipelines provide clarity over imperative callbacks

Prefer MVI/TCA when:
- explicit state-machine and strict reducer flow are primary requirements

## PR Review Checklist

- Streams are composed without nested subscriptions.
- Cancellation/disposal is lifecycle-safe.
- UI-bound updates are marshaled to main thread.
- Operators match intent (`debounce`, `throttle`, `switchToLatest`, `share`).
- Views/controllers do not hold business pipeline logic.
- Error handling keeps UX resilient for transient failures.
