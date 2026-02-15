# Swift Architecture Skill

An [Agent Skill](https://github.com/agentskills/agentskills) that provides architecture guidance for Swift iOS development.

## Overview

This Agent Skill helps you design and implement the right architecture pattern for your Swift iOS project. It provides concrete code examples, anti-patterns to avoid, and PR review checklists.

## Supported Architectures

- **MVVM** - Model-View-ViewModel pattern
- **MVI** - Model-View-Intent pattern
- **TCA** - The Composable Architecture
- **Clean Architecture** - Layered architecture with dependency inversion
- **VIPER** - View-Interactor-Presenter-Entity-Router pattern
- **Reactive** - Combine/RxSwift patterns

## How It Works

1. Request architecture guidance for a feature or module
2. The skill routes to the appropriate architecture playbook
3. Get concrete patterns, code examples, and testing strategies
4. Review changes with architecture-specific checklists

## Features

- Architecture selection guidance based on your constraints
- Modern Swift patterns (async/await, actors, SwiftUI)
- Testing strategies with example code
- Anti-patterns with fixes
- PR review checklists

## How to Install

### Option A: Using `skills.sh` (recommended)

Install this skill with:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then use it in your agent:

```text
Use `swift-architecture-skill` to recommend the best architecture for this feature.
```

### Option B: Claude Code Plugin

For personal usage in Claude Code:

1. Add the marketplace:

```text
/plugin marketplace add efremidze/swift-architecture-skill
```

2. Install the skill:

```text
/plugin install swift-architecture-skill@swift-architecture-skill
```

For team/project usage, you can also configure plugin enablement via repository-level `.claude` settings.

### Option C: Manual Install

1. Clone this repository.
2. Install or symlink `swift-architecture-skill/` to your tool's skills directory.
3. Use your AI tool and ask it to use `swift-architecture-skill`.

## Project Structure

```text
swift-architecture-skill/
  SKILL.md                    # Skill definition and workflow
  agents/
    openai.yaml               # Agent interface configuration
  references/
    selection-guide.md        # Architecture decision framework
    mvvm.md                   # MVVM pattern playbook
    mvi.md                    # MVI pattern playbook
    tca.md                    # TCA playbook
    clean-architecture.md     # Clean Architecture playbook
    viper.md                  # VIPER playbook
    reactive.md               # Reactive (Combine/RxSwift) playbook
```

## License

MIT License - see [LICENSE](LICENSE) for details
