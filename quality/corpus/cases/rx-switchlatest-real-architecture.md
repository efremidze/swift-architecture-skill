# Real-World Corpus: RxSwift switchLatest (Architecture Check)

Source:
- https://raw.githubusercontent.com/ReactiveX/RxSwift/main/Tests/RxSwiftTests/Observable+SwitchTests.swift

## Testing Strategy

Real-world Rx tests validate success and failure event sequences with deterministic scheduler control.
This snippet demonstrates switchLatest replacement behavior for stale inner streams.

```swift
import RxSwift
import RxTest
import XCTest

class ObservableSwitchTest: RxTest {}

extension ObservableSwitchTest {
    func testSwitch_Data() {
        let scheduler = TestScheduler(initialClock: 0)

        let ys1 = scheduler.createColdObservable([
            .next(10, 101),
            .next(20, 102),
            .completed(230)
        ])

        let ys2 = scheduler.createColdObservable([
            .next(10, 201),
            .next(20, 202),
            .completed(50)
        ])

        let xs = scheduler.createHotObservable(
            .next(300, ys1),
            .next(400, ys2),
            .completed(600)
        )

        let res = scheduler.start {
            xs.switchLatest()
        }

        XCTAssertEqual(res.events.count, 4)
    }

    func testSwitch_InnerThrows() {
        let scheduler = TestScheduler(initialClock: 0)

        let ys1 = scheduler.createColdObservable([
            .next(10, 101),
            .completed(230)
        ])

        let ys2 = scheduler.createColdObservable([
            .next(10, 201),
            .error(50, testError)
        ])

        let xs = scheduler.createHotObservable(
            .next(300, ys1),
            .next(400, ys2),
            .completed(600)
        )

        let res = scheduler.start {
            xs.switchLatest()
        }

        XCTAssertEqual(res.events.last?.value.error != nil, true)
    }
}
```
