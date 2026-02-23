# Benchmark Source Anchors

This suite is inspired by testing patterns from primary sources:

- Swift Testing and XCTest patterns: https://developer.apple.com/documentation/testing
- Swift Concurrency cancellation behavior: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Task-Cancellation
- The Composable Architecture testing patterns: https://github.com/pointfreeco/swift-composable-architecture
- Reactive switch/latest-request behavior: https://reactivex.io/documentation/operators/switch.html
- Clean Architecture dependency boundaries: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

Cases are intentionally minimized and adapted into neutral benchmark fixtures for validator evaluation.
Architecture-specific fixtures also assert pattern-level expectations (for example: TCA cancel IDs and MVVM stale-overwrite protections).
