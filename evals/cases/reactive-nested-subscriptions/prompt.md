Use `swift-architecture-skill` to review this reactive implementation.

Context:
- Search feature with Combine
- Requirement: replace stale requests, avoid leaks

```swift
import Combine

final class SearchPresenter {
    private let query = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: SearchService) {
        query.sink { value in
            service.search(value).sink(
                receiveCompletion: { _ in },
                receiveValue: { results in
                    print(results)
                }
            ).store(in: &self.cancellables)
        }
        .store(in: &cancellables)
    }
}
```

Request:
1. Identify architecture/reactive smells.
2. Recommend a better stream composition pattern.
3. Mention cancellation behavior.
