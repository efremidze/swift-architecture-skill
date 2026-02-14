# VIPER Playbook (Swift + UIKit/SwiftUI)

Use this reference when strict separation of concerns is needed at feature level, especially in larger codebases or legacy UIKit modules.

## Core Components

- View: render UI and forward user actions
- Interactor: execute business logic and coordinate data access
- Presenter: transform entities into display-ready output and control view state
- Entity: domain models used by the feature
- Router: navigation and module assembly

Expected interaction:

```text
View -> Presenter -> Interactor -> Presenter -> View
Presenter -> Router (navigation)
```

## Canonical Feature Layout

```text
Feature/
  View/
  Presenter/
  Interactor/
  Entity/
  Router/
```

For modular repos, keep one VIPER module per feature to prevent cross-feature leakage.

## Responsibilities

### View

- Render data provided by Presenter.
- Forward user inputs (`didTap...`, `didAppear`, text changes).
- Avoid direct service/repository access.

### Presenter

- Own presentation flow for the feature.
- Ask Interactor for business results.
- Map entities to view models/display strings.
- Call Router for navigation.

### Interactor

- Execute business rules and use cases.
- Call repositories/services through protocols.
- Return domain results to Presenter.
- Avoid direct view or navigation concerns.

### Router

- Perform navigation transitions.
- Build and wire module dependencies.

### Entity

- Represent domain data and business invariants.
- Avoid UI and framework coupling where possible.

## Wiring Pattern

Use protocols at boundaries and keep references directional.

```swift
@MainActor
protocol ProfileView: AnyObject {
    func show(name: String)
}

protocol ProfileInteracting {
    func loadUser() async throws -> User
}

protocol ProfileRouting {
    func showSettings()
}

@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let interactor: ProfileInteracting
    private let router: ProfileRouting

    init(interactor: ProfileInteracting, router: ProfileRouting) {
        self.interactor = interactor
        self.router = router
    }

    func load() async {
        do {
            let user = try await interactor.loadUser()
            view?.show(name: user.name)
        } catch {
            view?.show(name: "")
        }
    }

    func didTapSettings() {
        router.showSettings()
    }
}
```

Keep `view` weak to avoid retain cycles.
Keep presenter/view updates on the main actor so UI calls are thread-safe.

## Assembly Guidance

Create modules via Router/Assembly factory:
- instantiate View, Presenter, Interactor, Router
- inject protocols, not concrete global singletons
- set references once during build

This centralizes wiring and reduces circular dependency mistakes.

## Anti-Patterns and Fixes

1. Massive Presenter:
- Smell: presenter contains business logic, formatting, networking, and navigation details.
- Fix: move business logic to Interactor and formatting helpers; keep Presenter orchestration-focused.

2. Interactor performing navigation:
- Smell: interactor directly pushes/presents screens.
- Fix: route navigation through Router called by Presenter.

3. Circular dependencies and strong cycles:
- Smell: View <-> Presenter <-> Router retain each other strongly.
- Fix: use boundary protocols and weak references where required.

4. View doing business work:
- Smell: View transforms data or calls services directly.
- Fix: move logic into Presenter/Interactor.

5. Router containing business logic:
- Smell: Router decides domain outcomes.
- Fix: keep Router limited to navigation and assembly.

## Testing Strategy

Prioritize isolated tests per component:
- Presenter tests with mocked View/Interactor/Router
- Interactor tests with mocked repositories/services
- Router tests for navigation triggers where feasible

Testing rules:
- assert interactions and outputs, not concrete implementations
- avoid network in unit tests
- verify presenter handles success and failure states

## When to Prefer VIPER

Prefer VIPER when:
- feature boundaries must be very explicit
- team needs strict role separation
- UIKit-heavy codebase benefits from modularized presentation flow

Prefer lighter patterns when:
- app is small or prototyping quickly
- ceremony cost outweighs architecture benefit

## PR Review Checklist

- Component responsibilities are respected (View/Interactor/Presenter/Router separated).
- Presenter does not own business logic implementation details.
- Interactor does not navigate.
- Router handles only navigation and module assembly.
- Boundary protocols avoid concrete coupling.
- Retain cycles are prevented with weak references where needed.
- Tests cover presenter orchestration and interactor business rules.
