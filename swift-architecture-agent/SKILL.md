---
name: swift-architecture-agent
description: Architecture selection and implementation guidance for Swift iOS codebases, with architecture-specific playbooks and review checklists. Use when designing new features, refactoring existing modules, reviewing pull requests, or debugging maintainability issues in SwiftUI/UIKit projects and you need concrete guidance for MVVM, MVI, TCA, Clean Architecture, VIPER, or Reactive patterns.
---

# Swift Architecture Agent

## Overview

Use this skill as an architecture router for Swift feature work. Select the architecture playbook that matches the request, then apply its patterns to produce implementation-ready guidance.

## Workflow

### Step 1: Analyze the Request Context

Before selecting an architecture, understand the user's situation:
- Is this a new feature, a refactor, a PR review, or a debugging task?
- What UI framework is in use (SwiftUI, UIKit, or both)?
- What is the scope (single screen, multi-screen flow, app-wide)?
- Are there existing patterns in the codebase to follow?

### Step 2: Select the Architecture

If the user explicitly names an architecture, use it. Otherwise, load `references/selection-guide.md` and infer the best fit from stated constraints (state complexity, team familiarity, testing goals, effect orchestration needs, and framework preferences). Explain the recommendation briefly.

Architecture reference mapping:
- MVVM → `references/mvvm.md`
- MVI → `references/mvi.md`
- TCA → `references/tca.md`
- Clean Architecture → `references/clean-architecture.md`
- VIPER → `references/viper.md`
- Reactive → `references/reactive.md`

### Step 3: Analyze Existing Codebase (When Applicable)

When the user has an existing codebase:
- Scan for existing architectural patterns and conventions already in use
- Identify the project's dependency injection approach
- Note the concurrency model (async/await, Combine, GCD, or mixed)
- Check for existing state management patterns
- Align recommendations with established project conventions

### Step 4: Produce Concrete Deliverables

Read the selected architecture reference and convert its guidance into deliverables tailored to the user's request:

- **File and module structure**: directory layout with file names specific to the feature
- **State and dependency boundaries**: concrete types, protocols, and injection points
- **Concurrency and cancellation strategy**: task management, actor isolation, and cancellation IDs
- **Error handling**: explicit error types and recovery paths
- **Testing strategy**: what to test, how to stub dependencies, and example test structure
- **Migration path** (for refactors): incremental steps to move from current to target architecture

### Step 5: Validate with Checklist

End with the architecture-specific PR review checklist from the reference file, adapted to the user's feature.

## Architecture References

- Selection Guide: `references/selection-guide.md`
- MVVM: `references/mvvm.md`
- MVI: `references/mvi.md`
- TCA: `references/tca.md`
- Clean Architecture: `references/clean-architecture.md`
- VIPER: `references/viper.md`
- Reactive: `references/reactive.md`

## Modern Swift Guidelines

Apply these conventions across all architecture recommendations:

### Concurrency
- Prefer Swift concurrency (async/await, actors) over GCD and completion handlers
- Use `@MainActor` for UI-bound types (ViewModels, Presenters)
- Use `Task` with explicit cancellation for async work initiated from UI
- Check `Task.isCancelled` or call `try Task.checkCancellation()` in long-running work
- Use `actor` for shared mutable state accessed from multiple contexts

### Observation (iOS 17+ / macOS 14+)
- For new projects targeting iOS 17+, prefer `@Observable` macro over `ObservableObject`/`@Published`
- Use `@Bindable` in views for two-way bindings with `@Observable` types
- Fall back to `ObservableObject`/`@Published` when supporting iOS 16 and earlier
- Note: TCA has its own observation system (`@ObservableState`) — follow TCA conventions in TCA projects

### State Modeling
- Prefer enums for mutually exclusive states (`Loadable<T>`, navigation destinations)
- Use value types (structs/enums) for state; keep state `Equatable` where practical
- Avoid boolean flags for multi-state modeling (`isLoading` + `isError` → use an enum)

### Dependency Injection
- Prefer protocol-based injection via initializers
- Define protocols at the consumer's abstraction level, not the provider's
- Compose live dependencies at the app/assembly layer
- Keep dependency surfaces small and focused

### Testing
- Use protocol stubs/fakes over mocks where possible
- Inject controlled schedulers/clocks for time-dependent tests
- Avoid `sleep`-based waits; use `Task` and controlled async stubs
- Test state transitions, not implementation details

## Output Requirements

- Keep recommendations scoped to the requested feature or review task.
- Prefer protocol-based dependency injection and explicit state modeling.
- Flag anti-patterns found in existing code and provide direct fixes.
- Include cancellation and error handling in all async flows.
- When writing code, include only the patterns relevant to the task — do not dump entire playbooks.
- Ask only minimum blocking questions; otherwise proceed with explicit assumptions stated up front.
- When reviewing PRs, use the architecture-specific checklist and call out specific violations with line-level fixes.
