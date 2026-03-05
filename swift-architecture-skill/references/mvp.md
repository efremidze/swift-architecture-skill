# MVP Playbook (Swift + SwiftUI/UIKit)

Use this reference when you need a passive View that delegates all logic to a Presenter, especially in UIKit codebases where direct testability of presentation logic is a priority.

## Core Boundaries

- Model: Domain entities and business rules. No UI dependencies.
- View: Passive renderer driven entirely by Presenter commands. Owns no logic.
- Presenter: Owns all presentation logic, maps Model data to display output, and drives View updates through a protocol.
- Services/Repositories: Side-effect boundaries (network, persistence) injected into Presenter.

Dependency direction:

```text
View -> Presenter (user actions)
Presenter -> View (via ViewProtocol, one-way commands)
Presenter -> Repository/Service (via protocols)
```

The key difference from MVVM: the View holds no observable state — it passively executes commands dispatched by the Presenter.

## Feature Structure

```text
App/
  Features/
    Profile/
      ProfileViewController.swift   (View)
      ProfilePresenter.swift
      ProfileViewProtocol.swift
      ProfileViewData.swift
      ProfileAssembly.swift
  Navigation/
    AppCoordinator.swift
Domain/
  Entities/
  Repositories/
Data/
  Repositories/
  API/
```

## View Protocol

Define the View as a weak protocol. The Presenter drives state through it.

```swift
@MainActor
protocol ProfileView: AnyObject {
    func showLoading(_ isLoading: Bool)
    func show(profile: ProfileViewData)
    func showError(message: String)
}
```

Rules:
- use `AnyObject` to allow weak references
- methods represent view commands, not state flags
- keep the protocol focused — one command per distinct UI concern

## View Data

Map domain entities to display-ready values in the Presenter, not the View.

```swift
struct ProfileViewData: Equatable {
    let displayName: String
    let badgeText: String?
    let formattedJoinDate: String
}
```

## Presenter Pattern

Own task management, cancel stale work, and gate updates by request identity.

```swift
@MainActor
final class ProfilePresenter {
    weak var view: ProfileView?
    private let repository: ProfileRepository
    private var loadTask: Task<Void, Never>?
    private var latestRequestID: UUID?

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func viewDidAppear() {
        load()
    }

    func load() {
        let requestID = UUID()
        latestRequestID = requestID
        loadTask?.cancel()
        view?.showLoading(true)

        loadTask = Task {
            do {
                let user = try await repository.fetchCurrentUser()
                try Task.checkCancellation()
                guard latestRequestID == requestID else { return }
                let viewData = ProfileViewData(user: user)
                view?.show(profile: viewData)
            } catch is CancellationError {
                // Cancelled by a newer request — do not update view.
            } catch {
                guard latestRequestID == requestID else { return }
                view?.showError(message: "Failed to load profile. Please try again.")
            }
            guard latestRequestID == requestID else { return }
            view?.showLoading(false)
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

extension ProfileViewData {
    init(user: User) {
        self.displayName = user.name
        self.badgeText = user.isPremium ? "Premium" : nil
        self.formattedJoinDate = user.joinDate.formatted(.dateTime.year().month())
    }
}
```

Rules:
- `view` is `weak` to avoid retain cycles
- cancel in-flight task before starting a new one
- gate state updates by `requestID` to prevent stale overwrites

## UIKit View Implementation

The UIKit view controller forwards actions to Presenter and executes view commands.

```swift
@MainActor
final class ProfileViewController: UIViewController, ProfileView {
    private let presenter: ProfilePresenter
    private let nameLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.viewDidAppear()
    }

    // MARK: - ProfileView

    func showLoading(_ isLoading: Bool) {
        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
    }

    func show(profile: ProfileViewData) {
        nameLabel.text = profile.displayName
        errorLabel.isHidden = true
    }

    func showError(message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    private func setupLayout() {
        // Layout setup omitted for brevity.
    }
}
```

## SwiftUI Adapter

For SwiftUI, bridge via a thin observable adapter that conforms to `ProfileView`.

```swift
@MainActor
@Observable
final class ProfileViewAdapter: ProfileView {
    private(set) var viewData: ProfileViewData?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        self.presenter = presenter
        presenter.view = self
    }

    func showLoading(_ isLoading: Bool) {
        self.isLoading = isLoading
    }

    func show(profile: ProfileViewData) {
        self.viewData = profile
        self.errorMessage = nil
    }

    func showError(message: String) {
        self.errorMessage = message
    }

    func viewDidAppear() { presenter.viewDidAppear() }
}

struct ProfileScreen: View {
    @State private var adapter: ProfileViewAdapter

    init(adapter: ProfileViewAdapter) {
        self._adapter = State(initialValue: adapter)
    }

    var body: some View {
        Group {
            if adapter.isLoading {
                ProgressView()
            } else if let viewData = adapter.viewData {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewData.displayName).font(.title)
                    if let badge = viewData.badgeText {
                        Text(badge).font(.caption)
                    }
                }
            } else if let error = adapter.errorMessage {
                Text(error).foregroundStyle(.red)
            }
        }
        .onAppear { adapter.viewDidAppear() }
    }
}
```

## Assembly

Wire dependencies in one place — the assembler or coordinator.

```swift
enum ProfileAssembly {
    static func build(repository: ProfileRepository) -> UIViewController {
        let presenter = ProfilePresenter(repository: repository)
        let viewController = ProfileViewController(presenter: presenter)
        presenter.view = viewController
        return viewController
    }

    @MainActor
    static func buildSwiftUI(repository: ProfileRepository) -> ProfileScreen {
        let presenter = ProfilePresenter(repository: repository)
        let adapter = ProfileViewAdapter(presenter: presenter)
        return ProfileScreen(adapter: adapter)
    }
}
```

Rules:
- set `presenter.view` after construction, not inside the Presenter initializer
- inject concrete repositories from the composition root
- keep the assembly function as the only place that creates the full module

## Anti-Patterns and Fixes

1. View containing logic:
   - Smell: UIViewController computes display strings, formats dates, or makes service calls.
   - Fix: move all logic to Presenter; View receives ready-to-render view data.

2. Presenter observing state objects (ViewModel pattern leaking in):
   - Smell: Presenter publishes `@Published` properties that the View observes directly.
   - Fix: keep the Presenter command-driven; View state is driven by protocol method calls, not KVO or Combine pipelines.

3. Bidirectional strong references:
   - Smell: Presenter holds a strong reference to View.
   - Fix: declare `weak var view: ProfileView?` in Presenter.

4. No request-identity guard:
   - Smell: rapid re-loads overwrite each other because any in-flight completion can update the View.
   - Fix: assign a `UUID` per request and guard all view updates behind identity equality.

5. Fat Presenter:
   - Smell: Presenter contains network code, caching logic, or routing details.
   - Fix: delegate network and persistence to injected Repository protocols; delegate navigation to an injected Router or Coordinator.

## Testing Strategy

Test the Presenter in isolation with a mock View and stub Repository.
Verify the Presenter-to-View contract for success, failure, and cancellation paths.
Keep tests deterministic by controlling async behaviour with stubs, not `sleep`.

```swift
@MainActor
final class MockProfileView: ProfileView {
    var isLoading = false
    var shownViewData: ProfileViewData?
    var shownError: String?

    func showLoading(_ isLoading: Bool) { self.isLoading = isLoading }
    func show(profile: ProfileViewData) { shownViewData = profile }
    func showError(message: String) { shownError = message }
}

struct StubProfileRepository: ProfileRepository {
    var result: Result<User, Error>
    func fetchCurrentUser() async throws -> User { try result.get() }
}

@MainActor
final class ProfilePresenterTests: XCTestCase {
    func test_load_success_showsUserName() async {
        let user = User(id: UUID(), name: "Alice", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .success(user))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Alice")
        XCTAssertNil(view.shownError)
    }

    func test_load_failure_showsError() async {
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(TestError.notFound))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertNotNil(view.shownError)
        XCTAssertNil(view.shownViewData)
    }

    func test_load_cancellation_doesNotOverwriteExistingViewData() async {
        let existing = User(id: UUID(), name: "Existing", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        view.show(profile: ProfileViewData(user: existing))
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .failure(CancellationError()))
        )
        presenter.view = view

        presenter.load()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "Existing")
    }

    func test_rapidLoads_onlyLatestResultShown() async {
        let firstUser = User(id: UUID(), name: "First", isPremium: false, joinDate: .now)
        let view = MockProfileView()
        let presenter = ProfilePresenter(
            repository: StubProfileRepository(result: .success(firstUser))
        )
        presenter.view = view

        // Simulate two rapid loads; second call cancels first.
        presenter.load() // request A — will be cancelled
        presenter.load() // request B — latest
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(view.shownViewData?.displayName, "First")
    }
}

private enum TestError: Error { case notFound }
```

## When to Prefer MVP

Prefer MVP when:
- UIKit is the primary stack and you want full Presenter testability without observable state objects
- the View must be completely passive (no `if` logic, no `guard`, no formatting)
- migrating from MVC and want a minimal step up without pulling in Combine or the `@Observable` macro
- existing team is familiar with the Presenter + View protocol pattern

Prefer MVVM when:
- SwiftUI is the primary stack and `@Observable` / `@Published` state binding reduces wiring overhead
- you want reactive data flow with less hand-written command dispatch

Compared with VIPER, MVP omits the Interactor and Router as distinct components, making it lighter and simpler for single-screen features.

## PR Review Checklist

- View contains no business logic, data formatting, or service calls.
- `view` property in Presenter is `weak` and typed as `ProfileView`.
- Presenter cancels the previous task before starting a new load.
- All Presenter-to-View calls are guarded by request identity where async.
- Repository and service dependencies are injected via protocols, not singletons.
- Tests cover success, failure, and stale-cancellation paths.
- Assembly function wires the module from the outside — Presenter does not create its own dependencies.
