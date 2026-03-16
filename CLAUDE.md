# Swift Architecture Skill

This repository contains an Agent Skill that provides Swift architecture design and implementation patterns for iOS codebases.

## Project Structure

```
swift-architecture-skill/
  SKILL.md                    # Skill definition and workflow
  agents/
    openai.yaml               # Agent interface configuration
  references/
    selection-guide.md        # Architecture decision framework
    mvp.md                    # MVP pattern playbook
    mvvm.md                   # MVVM pattern playbook
    mvi.md                    # MVI pattern playbook
    tca.md                    # TCA (Composable Architecture) playbook
    clean-architecture.md     # Clean Architecture playbook
    viper.md                  # VIPER pattern playbook
    coordinator.md            # Coordinator pattern playbook
    reactive.md               # Reactive (Combine/RxSwift) playbook
```

## How the Skill Works

1. User requests architecture guidance for a Swift feature or module
2. The skill routes to the appropriate architecture playbook based on explicit request or inferred constraints
3. The playbook provides concrete patterns, code examples, anti-patterns, testing strategies, and PR review checklists
4. Output is tailored to the user's specific feature context

## Key Conventions

- All architecture references are standalone markdown playbooks in `references/`
- Each playbook follows a consistent structure: core concepts, code patterns, anti-patterns with fixes, testing strategy, and PR review checklist
- The skill supports MVP, MVVM, MVI, TCA, Clean Architecture, VIPER, Coordinator, and Reactive patterns
- When no architecture is specified, use `references/selection-guide.md` to infer the best fit
- Code examples use modern Swift concurrency (async/await, actors) and cover both SwiftUI and UIKit patterns
