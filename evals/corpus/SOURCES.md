# Real-World Corpus Sources

These corpus fixtures are direct excerpts from upstream open-source projects:

- pointfreeco/swift-composable-architecture
  - https://raw.githubusercontent.com/pointfreeco/swift-composable-architecture/74a5fa0d02b17ba5bbd9743dc49b4d7f3bbbed96/Tests/ComposableArchitectureTests/EffectCancellationTests.swift
  - https://raw.githubusercontent.com/pointfreeco/swift-composable-architecture/74a5fa0d02b17ba5bbd9743dc49b4d7f3bbbed96/Tests/ComposableArchitectureTests/EffectCancellationIsolationTests.swift
- ReactiveX/RxSwift
  - https://raw.githubusercontent.com/ReactiveX/RxSwift/5734ad2b6d7d4c0656df3d09ca4ce54fa3c09913/Tests/RxSwiftTests/Observable+SwitchTests.swift
  - https://raw.githubusercontent.com/ReactiveX/RxSwift/5734ad2b6d7d4c0656df3d09ca4ce54fa3c09913/Tests/RxBlockingTests/Observable+BlockingTest.swift
- swiftlang/swift-testing
  - https://raw.githubusercontent.com/swiftlang/swift-testing/2a16d3d2ccc3a5a477613e4e6518712699315755/Tests/TestingTests/ClockTests.swift

The goal is corpus-level validation against real project snippets, distinct from synthetic benchmark fixtures in `evals/benchmarks/`.
