# Clean Architecture Playbook (Swift + SwiftUI/UIKit)

Use this reference when a Swift codebase needs strict layer boundaries, clear dependency direction, and use-case-driven business logic.

## Core Dependency Rule

Dependencies point inward:

```text
Frameworks / UI
    ->
Interface Adapters
    ->
Use Cases
    ->
Entities (Domain)
```

Rules:
- inner layers must not import or depend on outer layers
- domain remains pure Swift
- frameworks are implementation details and replaceable

## Canonical Layer Layout

```text
Domain/
  Entities/
  UseCases/
Data/
  Repositories/
  API/
  Persistence/
Presentation/
  Features/
App/
```

Guidance:
- keep entities and use-case protocols in `Domain`
- keep repository implementations and external adapters in `Data`
- keep views/view models/controllers in `Presentation`
- keep DI composition root and app bootstrap in `App`

## Entities

Entities model core business concepts and rules.

```swift
struct User: Equatable {
    let id: UUID
    let name: String
}
```

Rules:
- no UIKit/SwiftUI imports
- no persistence or network behavior
- avoid framework-specific types unless unavoidable

## Use Cases

Use cases orchestrate business actions through abstractions.

```swift
protocol LoadUserUseCase {
    func execute(id: UUID) async throws -> User
}

final class LoadUser: LoadUserUseCase {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws -> User {
        try await repository.fetch(id: id)
    }
}
```

Rules:
- one business responsibility per use case
- no UI details
- no direct framework usage unless abstracted

## Repository Boundary

Define repository protocols in `Domain`; implement them in `Data`.

```swift
protocol UserRepository {
    func fetch(id: UUID) async throws -> User
}
```

Data-layer implementations can coordinate:
- API clients
- local persistence
- mapping DTOs to domain entities

## Dependency Injection Pattern

Compose live dependencies in the app or feature assembly layer.

```swift
enum UserFeatureAssembly {
    static func makeLoadUserUseCase() -> LoadUserUseCase {
        let repository = LiveUserRepository(api: .live, store: .live)
        return LoadUser(repository: repository)
    }
}
```

Rules:
- inject protocols into use cases and presentation
- avoid global singletons as hidden dependencies

## Presentation Boundary

Presentation depends on use-case abstractions, not data implementations.

Expected flow:
- View triggers intent/event
- ViewModel/Presenter calls `UseCase`
- UseCase returns domain entities
- Presentation maps entities to view state

## Anti-Patterns and Fixes

1. God use case:
- Smell: single 500+ line use case handling many responsibilities.
- Fix: split by business capability and compose use cases.

2. Presentation imports data layer:
- Smell: feature view model directly uses `LiveRepository` or API client.
- Fix: depend on use-case protocol only.

3. Domain depends on frameworks:
- Smell: domain entities use UI/network/persistence frameworks.
- Fix: keep domain pure and move adapters outward.

4. Repository leaks transport types:
- Smell: presentation receives DTO/network models.
- Fix: map external models to domain entities in data layer.

5. Testing through real infrastructure:
- Smell: unit tests require network/db.
- Fix: test use cases with mocked/stub repositories.

## Testing Strategy

Prioritize:
- use-case unit tests with repository stubs
- mapper tests (DTO <-> domain) in data layer
- presentation tests with mocked use cases

Rules:
- avoid network in unit tests
- assert business behavior at use-case boundary
- keep async tests deterministic using controlled stubs

## When to Prefer Clean Architecture

Prefer when:
- app/domain complexity is medium to large
- multiple teams need stable boundaries
- long-term maintainability and replaceable infrastructure matter

Prefer lighter layering when:
- app is small and short-lived
- strict layering overhead is higher than expected benefit

## PR Review Checklist

- Dependency direction points inward only.
- Domain layer is framework-independent.
- Use cases encapsulate business rules and stay focused.
- Presentation does not import data implementations.
- Repository abstractions live at domain boundary.
- Tests isolate use cases from infrastructure.
