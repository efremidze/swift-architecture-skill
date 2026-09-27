# Async, Cancellation, and Error Mapping (Shared)

Cross-cutting async rules that apply to every playbook. Each playbook shows how these rules map onto its own types (ViewModel, Presenter, Store, Reducer, Interactor, pipeline); this file defines the rules and the shared error-mapping convention its snippets use.

## Contents
- [Core Rules](#core-rules)
- [Cancel-Before-Start Pattern](#cancel-before-start-pattern)
- [Stale-Response Guards](#stale-response-guards)
- [User-Facing Error Mapping](#user-facing-error-mapping)
- [Testing Expectations](#testing-expectations)

## Core Rules

- Mutate UI-bound state on `@MainActor`.
- Own one task handle per re-entrant intent (load, refresh, search) and cancel it before starting a new one.
- Treat `CancellationError` as a normal exit, not a failure: do not surface it to the user.
- When cancellation alone cannot stop a late write (out-of-order responses, work already past its last suspension point), gate the write with a request identity.
- Let cancellation propagate through `try await`; call `Task.checkCancellation()` before expensive non-async work.
- Keep shared mutable service state in actors.
- Cancel owned tasks when the owner's lifetime ends (view disappearance, `deinit`, module teardown).

## Cancel-Before-Start Pattern

```swift
@MainActor
final class FeatureModel {
    private(set) var state: FeatureState = .idle
    private let repository: FeatureRepository
    private var loadTask: Task<Void, Never>?

    init(repository: FeatureRepository) {
        self.repository = repository
    }

    func load() {
        loadTask?.cancel()
        state = .loading
        loadTask = Task { [weak self, repository] in
            do {
                let items = try await repository.fetch()
                guard !Task.isCancelled else { return }
                self?.state = .loaded(items)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(userMessage(for: error))
            }
        }
    }
}
```

Notes:
- Capture `self` weakly so a long-running task does not keep the model alive (the model retains `loadTask`, so a strong capture forms a cycle until the task finishes).
- Check `Task.isCancelled` before every write: a dependency may return normally or throw a non-cancellation error after being cancelled.
- `load()` starts an unstructured task, so cancelling a caller (including SwiftUI's `.task` modifier) does not cancel `loadTask`. To stop work when the screen goes away, expose a `cancel()` that calls `loadTask?.cancel()` and call it from the owner's teardown (`onDisappear`, `viewDidDisappear`). Alternatively, make `load()` itself `async` (no stored task) and call it from `.task`, which then cancels it automatically.

## Stale-Response Guards

Use a request identity when a newer request must win regardless of completion order:

```swift
@MainActor
func search(_ query: String) async {
    let requestID = UUID()
    latestRequestID = requestID
    do {
        let results = try await repository.search(query)
        guard latestRequestID == requestID, !Task.isCancelled else { return } // a newer search started
        state = .loaded(results)
    } catch is CancellationError {
        return
    } catch {
        guard latestRequestID == requestID, !Task.isCancelled else { return }
        state = .failed(userMessage(for: error))
    }
}
```

Architecture equivalents: MVI/TCA carry the ID in the response action and compare it in the reducer; TCA can also use `.cancellable(id:cancelInFlight:)`; Combine/RxSwift use `switchToLatest`/`flatMapLatest`.

## User-Facing Error Mapping

Do not pass `error.localizedDescription` straight to the UI: it can leak implementation details and is not localized for your product. Map errors at the presentation boundary with one function per feature or app:

```swift
func userMessage(for error: Error) -> String {
    switch error {
    case let error as URLError where error.code == .notConnectedToInternet:
        return "You're offline. Check your connection and try again."
    default:
        return "Something went wrong. Please try again."
    }
}
```

Playbook snippets call `userMessage(for:)` wherever a failure reaches view state. Map expected domain failures to explicit states or actions; reserve the generic fallback for unexpected errors.

## Testing Expectations

For each re-entrant async intent, cover:
- success
- failure (the user-facing state, not the raw error)
- cancellation or stale response (an older result never overwrites a newer one)
