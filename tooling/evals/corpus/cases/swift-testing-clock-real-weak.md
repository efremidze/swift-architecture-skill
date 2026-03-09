# Real-World Corpus: Swift Testing Clock API (Expected Fail)

Source:
- https://raw.githubusercontent.com/swiftlang/swift-testing/main/Tests/TestingTests/ClockTests.swift

## Testing Strategy

These are deterministic clock behavior tests from a real project, but they do not target failure and cancellation/stale architectural concerns.

```swift
@testable @_spi(Experimental) @_spi(ForToolsIntegrationOnly) import Testing

@Suite("Clock API Tests")
struct ClockTests {
  @Test("Clock.Instant basics")
  func clockInstant() async throws {
    let instant1 = Test.Clock.Instant.now
    try await Test.Clock.sleep(for: .nanoseconds(50_000_000))
    let instant2 = Test.Clock.Instant.now

    #expect(instant1 < instant2)
  }

  @Test("Clock.sleep(until:tolerance:) method")
  func sleepUntilTolerance() async throws {
    let instant1 = SuspendingClock.Instant(Test.Clock.Instant.now)
    try await Test.Clock().sleep(until: .now.advanced(by: .milliseconds(50)), tolerance: nil)
    let instant2 = Test.Clock.Instant.now

    #expect(SuspendingClock.Instant(instant2) > instant1)
  }
}
```
