Use `swift-architecture-skill` to review this Clean Architecture snippet.

Context:
- Team wants strict dependency rule
- Domain layer should not depend on UI frameworks

```swift
import Foundation
import SwiftUI

struct OrderSummaryUseCase {
    func makeBadgeText(total: Double) -> Text {
        Text("Total: \(total)")
    }
}
```

Request:
1. Identify the dependency issue.
2. Provide a boundary-correct fix.
3. Keep recommendation practical for a staged refactor.
