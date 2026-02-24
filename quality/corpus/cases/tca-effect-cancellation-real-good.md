# Real-World Corpus: TCA Effect Cancellation (Good)

Source:
- https://raw.githubusercontent.com/pointfreeco/swift-composable-architecture/main/Tests/ComposableArchitectureTests/EffectCancellationTests.swift

## Testing Strategy

Real-world TCA tests cover success, failure, and cancellation behavior and include deterministic scheduling for delayed effects.
This source file also uses dependency overrides (`withDependencies`) in related tests.

```swift
import Combine
@_spi(Internals) import ComposableArchitecture
import XCTest

final class EffectCancellationTests: BaseTCATestCase {
  struct CancelID: Hashable {}

  func testCancellation() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect = Effect.publisher { subject }
      .cancellable(id: CancelID())

    let task = Task {
      for await n in effect.actions {
        values.withValue { $0.append(n) }
      }
    }

    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    Task.cancel(id: CancelID())

    subject.send(3)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    await task.value
  }

  func testCancelInFlight() async {
    let values = LockIsolated<[Int]>([])

    let subject = PassthroughSubject<Int, Never>()
    let effect1 = Effect.publisher { subject }
      .cancellable(id: CancelID(), cancelInFlight: true)

    let task1 = Task {
      for await n in effect1.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    subject.send(1)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1])

    let effect2 = Effect.publisher { subject }
      .cancellable(id: CancelID(), cancelInFlight: true)

    let task2 = Task {
      for await n in effect2.actions {
        values.withValue { $0.append(n) }
      }
    }
    await Task.megaYield()

    subject.send(3)
    await Task.megaYield()
    XCTAssertEqual(values.value, [1, 3])

    Task.cancel(id: CancelID())
    await task1.value
    await task2.value
  }

  func testCancellationAfterDelay_WithTestScheduler() async {
    let mainQueue = DispatchQueue.test
    let result = LockIsolated<Int?>(nil)

    let effect = Effect.publisher {
      Just(1)
        .delay(for: 2, scheduler: mainQueue)
    }
    .cancellable(id: CancelID())

    let task = Task {
      for await value in effect.actions {
        result.setValue(value)
      }
    }

    Task.cancel(id: CancelID())
    await task.value
  }
}
```
