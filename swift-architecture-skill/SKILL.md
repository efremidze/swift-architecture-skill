---
name: swift-architecture-skill
description: Swift iOS architecture guidance and playbooks for MVVM, MVI, TCA, Clean Architecture, VIPER, MVP, Coordinator, and Reactive patterns. Use when designing, implementing, refactoring, or reviewing the architecture of a SwiftUI or UIKit feature, module, or codebase.
license: MIT
---

# Swift Architecture Skill

## Overview

Use this skill to pick the best Swift architecture playbook for SwiftUI/UIKit codebases and apply it to the user’s task.

For quick navigation across playbooks, use `references/_index.md`.

## Fast Path

Before selecting an architecture, always capture:
- task type (new feature, refactor, PR review, debugging)
- UI stack (SwiftUI, UIKit, or mixed)
- scope (single screen, multi-screen, app-wide)
- state and effect complexity
- team familiarity and dependency tolerance
- existing conventions to preserve

Then:
- if the user explicitly names an architecture, treat it as the initial candidate and run a fit check first
- if no architecture is named, load `references/selection-guide.md` and infer the best fit from the stated constraints
- if the best fit combines patterns, name one **primary** playbook for the feature boundary and one **secondary** playbook for the supporting concern
- choose **Quick Recommendation Mode** for single-feature guidance with clear constraints
- choose **Deep Refactor Mode** for migrations, mixed architectures, or module boundary changes

## Quick Recommendation Mode

Use this mode when:
- the scope is one feature or screen
- constraints are clear enough to recommend one primary pattern
- the user mainly needs a recommendation, scaffold, or review checklist

Deliver:
- fit result (`fit` or `mismatch`)
- 1-2 reasons grounded in the request
- the selected reference file
- concrete structure, state, dependency, async, and testing guidance scoped to the feature

## Deep Refactor Mode

Use this mode when:
- the request spans multiple modules or screens
- the codebase already mixes architectures
- the user is migrating from one pattern to another

Deliver:
- current-state assessment
- target architecture recommendation with fit or mismatch result
- incremental migration path with boundary changes called out
- risks, trade-offs, and verification points for the transition

## Architecture Router

If the user explicitly names an architecture, treat it as the initial candidate and run a fit check before committing:
- validate against UI stack fit (SwiftUI/UIKit/mixed), state complexity, effect orchestration needs, team familiarity, and existing codebase conventions
- if it fits, proceed with the requested architecture
- if it mismatches key constraints, explicitly explain the mismatch and recommend the closest-fit alternative from `references/selection-guide.md`
- if the user still insists on a mismatched architecture, proceed with a risk-mitigated plan and state the risks up front

Architecture reference mapping:
- MVVM → `references/mvvm.md`
- MVI → `references/mvi.md`
- TCA → `references/tca.md`
- Clean Architecture → `references/clean-architecture.md`
- VIPER → `references/viper.md`
- Reactive → `references/reactive.md`
- MVP → `references/mvp.md`
- Coordinator → `references/coordinator.md`

Combination routing:
- Coordinator is usually secondary unless the user's main problem is flow ownership, deep linking, or reusable navigation.
- Reactive is usually secondary when streams live inside MVVM, MVP, VIPER, MVI, or TCA presentation boundaries.
- Clean Architecture is usually primary for app/module layering, with MVVM, MVP, or TCA as the presentation pattern.
- When combining, read both references and state which pattern owns each boundary before giving file structure or code.

## Analyze Existing Codebase (When Applicable)

When code already exists:
- detect current architecture and DI style
- note concurrency model (async/await, Combine, GCD, mixed)
- align recommendations to local conventions

## Guardrails

- Do not force an architecture switch for a small feature when the current local pattern is still a reasonable fit.
- Preserve existing conventions unless the mismatch is severe enough to justify change.
- Do not introduce new framework dependencies such as TCA unless the user explicitly accepts that trade-off or the codebase already uses them.
- Prefer the smallest architecture change that solves the request cleanly.
- Keep guidance architecture-specific; do not blend playbooks unless the boundary between patterns is explicit.
- For combined patterns, avoid merging responsibilities: identify the primary boundary first, then apply the secondary playbook only to its concern.

## Produce Concrete Deliverables

Read the selected architecture reference and convert its guidance into deliverables tailored to the user's request:

- **File and module structure**: directory layout with file names specific to the feature
- **State and dependency boundaries**: concrete types, protocols, and injection points
- **Async strategy**: cancellation, actor isolation, and error paths
- **Testing strategy**: what to test, how to stub dependencies, and example test structure
- **Migration path** (for refactors): incremental steps to move from current to target architecture
- **UI stack adaptation**: where SwiftUI and UIKit guidance should differ for the chosen architecture

## Output Requirements

- Keep recommendations scoped to the requested feature or review task.
- Prefer protocol-based dependency injection and explicit state modeling.
- Flag anti-patterns found in existing code and provide direct fixes.
- Include cancellation and error handling in all async flows.
- For explicit architecture requests, include a short fit result (`fit` or `mismatch`) with 1-2 reasons.
- For mismatch cases, include one closest-fit alternative and why it better matches the stated constraints.
- When writing code, include only the patterns relevant to the task — do not dump entire playbooks.
- Treat reference snippets as illustrative by default; add full compile scaffolding only if the user asks for runnable code.
- Ask only minimum blocking questions; otherwise proceed with explicit assumptions stated up front.
- When reviewing PRs, use the architecture-specific checklist and call out specific violations with line-level fixes.

## Verification Checklist

Before finalizing:

1. confirm the selected pattern matches the user’s constraints and stack
2. confirm dependency injection, state ownership, effects, and testing strategy are covered
3. call out migration risk explicitly when recommending an architecture change
4. end with the selected architecture’s PR review checklist adapted to the user’s feature
