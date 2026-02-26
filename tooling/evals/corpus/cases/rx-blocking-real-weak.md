# Real-World Corpus: RxBlocking Weak Coverage (Expected Fail)

Source:
- https://raw.githubusercontent.com/ReactiveX/RxSwift/main/Tests/RxBlockingTests/Observable+BlockingTest.swift

## Testing Strategy

These tests cover success and failure/timeouts but do not model cancellation or stale-response replacement behavior.

```swift
import RxBlocking
import RxSwift
import XCTest

class ObservableBlockingTest: RxTest {}

extension ObservableBlockingTest {
    func testToArray_return() {
        XCTAssertEqual(try Observable.just(42).toBlocking().toArray(), [42])
    }

    func testToArray_fail() {
        XCTAssertThrowsErrorEqual(try Observable<Int>.error(testError).toBlocking().toArray(), testError)
    }

    func testToArray_timeout() {
        XCTAssertThrowsError(try Observable<Int>.never().toBlocking(timeout: 0.01).toArray()) { error in
            XCTAssertErrorEqual(error, RxError.timeout)
        }
    }
}
```
