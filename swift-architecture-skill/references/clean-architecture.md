# Clean Architecture Playbook (Swift + SwiftUI/UIKit)

Use this reference when a Swift codebase needs strict layer boundaries and use-case-driven business logic.

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
- no SwiftUI/UIKit imports
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
        let repository = LiveUserRepository(api: .live)
        return LoadUser(repository: repository)
    }
}
```

Rules:
- inject protocols into use cases and presentation
- avoid global singletons as hidden dependencies

## DTO to Domain Mapping

Map external models to domain entities at the data-layer boundary, in mappers or repository implementations.

```swift
struct UserDTO: Decodable {
    let id: String
    let full_name: String
    let created_at: String
}

enum UserMapper {
    static func toDomain(_ dto: UserDTO) throws -> User {
        guard let id = UUID(uuidString: dto.id) else {
            throw MappingError.invalidID(dto.id)
        }
        return User(id: id, name: dto.full_name)
    }
}

enum MappingError: Error {
    case invalidID(String)
}

final class LiveUserRepository: UserRepository {
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func fetch(id: UUID) async throws -> User {
        let dto = try await api.fetchUser(id: id)
        return try UserMapper.toDomain(dto)
    }
}
```

Rules:
- never expose DTOs beyond the data layer
- test mappers independently for edge cases and invalid input
- keep mapping pure and side-effect-free

## Concurrency and Cancellation

Use structured concurrency in use cases and let cancellation propagate through async calls.

```swift
final class LoadUserProfile: LoadUserProfileUseCase {
    private let userRepo: UserRepository
    private let postsRepo: PostsRepository

    init(userRepo: UserRepository, postsRepo: PostsRepository) {
        self.userRepo = userRepo
        self.postsRepo = postsRepo
    }

    func execute(id: UUID) async throws -> UserProfile {
        async let user = userRepo.fetch(id: id)
        async let posts = postsRepo.fetchRecent(userID: id)
        return try await UserProfile(user: user, posts: posts)
    }
}
```

Rules:
- prefer `async let` for concurrent independent fetches
- cancellation propagates automatically through `try await`
- use `Task.checkCancellation()` before expensive work if needed
- in presentation, cancel tasks on view disappearance or new request

## Presentation Boundary

Presentation depends on use-case abstractions, not data implementations.

Expected flow:
- View triggers intent/event
- Presentation layer calls `UseCase`
- UseCase returns domain entities
- Presentation maps entities to view state

SwiftUI adaptation:
- use `@Observable`/`ObservableObject` ViewModels that expose view state
- trigger use cases from intent methods on the ViewModel
- keep SwiftUI views declarative and free of use-case/repository calls

UIKit adaptation:
- use Presenter/ViewModel objects owned by view controllers
- convert delegate/target-action events into presenter intents
- keep controllers responsible for rendering only; business coordination stays in presenter/use case layers

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

```swift
struct StubUserRepository: UserRepository {
    var result: Result<User, Error>

    func fetch(id: UUID) async throws -> User {
        try result.get()
    }
}

@MainActor
final class LoadUserTests: XCTestCase {
    func test_execute_returnsUser() async throws {
        let expected = User(id: UUID(), name: "Alice")
        let sut = LoadUser(repository: StubUserRepository(result: .success(expected)))
        let user = try await sut.execute(id: expected.id)
        XCTAssertEqual(user, expected)
    }

    func test_execute_propagatesFailure() async {
        let sut = LoadUser(repository: StubUserRepository(result: .failure(TestError.notFound)))
        do {
            _ = try await sut.execute(id: UUID())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}

private enum TestError: Error { case notFound }
```

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
