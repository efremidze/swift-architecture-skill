Use `swift-architecture-skill` to review this VIPER wiring.

Context:
- Large UIKit codebase
- Concern: memory leaks during repeated navigation

```swift
protocol ProfileView: AnyObject {}

final class ProfilePresenter {
    var view: ProfileView?
    let router: ProfileRouter

    init(router: ProfileRouter) {
        self.router = router
    }
}

final class ProfileRouter {
    var presenter: ProfilePresenter?
}

func build() {
    let router = ProfileRouter()
    let presenter = ProfilePresenter(router: router)
    router.presenter = presenter
}
```

Request:
1. Identify architectural smell(s).
2. Recommend VIPER-correct ownership rules.
3. Provide concrete fix guidance.
