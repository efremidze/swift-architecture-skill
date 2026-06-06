# Real-World Corpus: MVVM Stale Task (Expected Fail)

Source:
- Synthetic — representative of common MVVM async patterns without in-flight task cancellation

## Testing Strategy

These tests cover success and failure paths but do not cancel in-flight tasks between loads,
leaving the ViewModel vulnerable to stale-response overwrites when requests resolve out of order.
No cancellation-focused test is present.

```swift
import XCTest

struct Item { let title: String }

protocol FeedRepository {
    func fetchItems() async throws -> [Item]
}

@MainActor
final class FeedViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    private let repository: FeedRepository

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await repository.fetchItems()
                items = result
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
}

struct StubFeedRepository: FeedRepository {
    var result: Result<[Item], Error>
    func fetchItems() async throws -> [Item] {
        try result.get()
    }
}

@MainActor
final class FeedViewModelTests: XCTestCase {
    func test_load_success_setsItems() async {
        let vm = FeedViewModel(repository: StubFeedRepository(result: .success([Item(title: "A")])))
        vm.load()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.items.map(\.title), ["A"])
    }

    func test_load_failure_setsError() async {
        struct E: Error {}
        let vm = FeedViewModel(repository: StubFeedRepository(result: .failure(E())))
        vm.load()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNotNil(vm.error)
    }
}
```
