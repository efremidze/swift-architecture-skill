Use `swift-architecture-skill` to review this SwiftUI feature.

Context:
- Team wants MVVM boundaries
- App uses async/await and dependency injection

```swift
import SwiftUI

struct ProfileView: View {
    @State private var name = ""

    var body: some View {
        VStack {
            Text(name)
            Button("Load") {
                Task {
                    let user = try? await URLSession.shared
                        .data(from: URL(string: "https://example.com/user")!)
                    name = "Loaded"
                }
            }
        }
    }
}
```

Request:
1. Identify smells.
2. Propose a better architecture boundary.
3. Mention async error-handling and cancellation expectations.
