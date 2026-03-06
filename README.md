# Swift Architecture Skill

An [Agent Skill](https://github.com/agentskills/agentskills) that provides architecture guidance for Swift, SwiftUI, and UIKit iOS development.

## Overview

This Agent Skill helps you design and implement the right architecture pattern for your iOS project.

- **Architecture selection**: Describe your feature or module and the skill picks the right pattern based on your UI stack, state complexity, and existing conventions. Name a pattern explicitly and it validates the fit before you commit.

- **Dedicated playbooks**: Each architecture has its own reference covering code patterns, anti-patterns with fixes, testing strategies, and a PR review checklist — scoped to your task, not a full reference dump.

- **SwiftUI and UIKit**: Every playbook addresses both stacks with concrete guidance on where they diverge, using modern async/await and actors throughout.

## Supported Architectures

- **MVP** - Model-View-Presenter pattern
- **MVVM** - Model-View-ViewModel pattern
- **MVI** - Model-View-Intent pattern
- **TCA** - The Composable Architecture
- **Clean Architecture** - Layered architecture with dependency inversion
- **VIPER** - View-Interactor-Presenter-Entity-Router pattern
- **Coordinator** - Navigation flow decoupling pattern
- **Reactive** - Combine/RxSwift patterns

## Quick Start

Install with a single command:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then use it in your AI assistant:
> Review my SwiftUI view for state management issues

[View on skills.sh →](https://skills.sh/efremidze/swift-architecture-skill/swift-architecture-skill)

## How to Install

### Option A: Using `skills.sh` (recommended)

Install this skill with:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then use it in your agent:

```bash
Use `swift-architecture-skill` to recommend the best architecture for this feature.
```

### Option B: Claude Code Plugin

For personal usage in Claude Code:

1. Add the marketplace:

```bash
/plugin marketplace add efremidze/swift-architecture-skill
```

2. Install the skill:

```bash
/plugin install swift-architecture-skill@swift-architecture-skill
```

Or configure for your team in `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "swift-architecture-skill@swift-architecture-skill": true
  },
  "extraKnownMarketplaces": {
    "swift-architecture-skill": {
      "source": {
        "source": "github",
        "repo": "efremidze/swift-architecture-skill"
      }
    }
  }
}
```

### Option C: Manual Install

1. Clone this repository.
2. Install or symlink `swift-architecture-skill/` to your tool's skills directory.
3. Use your AI tool and ask it to use `swift-architecture-skill`.

## Skill Structure

```bash
swift-architecture-skill/
  SKILL.md                    # Skill definition and workflow
  references/
    selection-guide.md        # Architecture decision framework
    mvvm.md                   # MVVM pattern playbook
    mvi.md                    # MVI pattern playbook
    tca.md                    # TCA playbook
    clean-architecture.md     # Clean Architecture playbook
    viper.md                  # VIPER playbook
    reactive.md               # Reactive (Combine/RxSwift) playbook
    mvp.md                    # MVP playbook
    coordinator.md            # Coordinator pattern playbook
```

## Other Skills

- [swift-patterns-skill](https://github.com/efremidze/swift-patterns-skill)

## Contributing

Contributions are welcome! This repository follows the [Agent Skills open format](https://agentskills.io/home), which has specific structural requirements.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on improving the skill content and reference files.

## License

MIT License. See [LICENSE](LICENSE) for details.
