# Clean Architecture Playbook (Swift + SwiftUI/UIKit)

Use this reference when a Swift codebase needs strict layer boundaries and use-case-driven business logic.

## Core Dependency Rule

```text
Frameworks / UI
    ->
Interface Adapters
    ->
Use Cases
    ->
Entities (Domain)
```

- Inner layers must not import or depend on outer layers
- Domain remains pure Swift
- Frameworks are implementation details and replaceable

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

- Keep entities and use-case protocols in `Domain`
- Keep repository implementations and external adapters in `Data`
- Keep views/view models/controllers in `Presentation`
- Keep DI composition root and app bootstrap in `App`

## Entities

```swift
struct User: Equatable {
    let id: UUID
    let name: String
}
```

- No SwiftUI/UIKit imports
- No persistence or network behavior
- Avoid framework-specific types unless unavoidable

## Use Cases

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

- One business responsibility per use case
- No UI details
- No direct framework usage unless abstracted

## Repository Boundary

```swift
protocol UserRepository {
    func fetch(id: UUID) async throws -> User
}
```

- API clients
- Local persistence
- Mapping DTOs to domain entities

## Dependency Injection Pattern

```swift
enum UserFeatureAssembly {
    static func makeLoadUserUseCase() -> LoadUserUseCase {
        let repository = LiveUserRepository(api: .live)
        return LoadUser(repository: repository)
    }
}
```

- Inject protocols into use cases and presentation
- Avoid global singletons as hidden dependencies

## DTO to Domain Mapping

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

- Never expose DTOs beyond the data layer
- Test mappers independently for edge cases and invalid input
- Keep mapping pure and side-effect-free

## Concurrency and Cancellation

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

- Prefer `async let` for concurrent independent fetches
- Cancellation propagates automatically through `try await`
- Use `Task.checkCancellation()` before expensive work if needed
- In presentation, cancel tasks on view disappearance or new request

## Presentation Boundary

- View triggers intent/event
- Presentation layer calls `UseCase`
- UseCase returns domain entities
- Presentation maps entities to view state

**SwiftUI:**
- Use `@Observable`/`ObservableObject` ViewModels that expose view state
- Trigger use cases from intent methods on the ViewModel
- Keep SwiftUI views declarative and free of use-case/repository calls

**UIKit:**
- Use Presenter/ViewModel objects owned by view controllers
- Convert delegate/target-action events into presenter intents
- Keep controllers responsible for rendering only; business coordination stays in presenter/use case layers

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

Prioritize use-case unit tests with stub repositories, mapper tests (DTO ↔ domain), and presentation tests with mocked use cases. Assert business behavior at use-case boundaries; test cancellation propagation for long-running operations.

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

    func test_execute_cancellationPropagates() async {
        let sut = LoadUser(repository: BlockingUserRepository())
        // Deterministic because this test class is @MainActor:
        // Task { ... } inherits main-actor isolation and does not start executing
        // until the main actor yields at await task.value, so cancellation is
        // observed immediately. Without @MainActor this pattern is racy.
        let task = Task { try await sut.execute(id: UUID()) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor BlockingUserRepository: UserRepository {
    func fetch(id: UUID) async throws -> User {
        try await Task.sleep(for: .seconds(60))
        return User(id: id, name: "")
    }
}

private enum TestError: Error { case notFound }
```

## When to Prefer Clean Architecture

- Medium-to-large domain where multiple teams need stable, independently testable layer boundaries.
- Long-term maintainability and replaceable infrastructure (swap API clients, persistence engines) are priorities.

## PR Review Checklist

- Dependency direction points inward only.
- Domain layer is framework-independent.
- Use cases encapsulate business rules and stay focused.
- Presentation does not import data implementations.
- Repository abstractions live at domain boundary.
