# Swift Architecture Skill
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/efremidze/swift-architecture-skill)](https://github.com/efremidze/swift-architecture-skill/releases)

Architecture guidance for AI coding tools that support the [Agent Skills open format](https://agentskills.io/home).

This skill helps agents choose and apply the right Swift architecture for real feature work in SwiftUI/UIKit codebases with concrete implementation patterns, anti-pattern fixes, testing strategy, and review checklists.

## Features

- **Architecture selection**: Describe your feature or module and the skill selects the right pattern based on UI stack, state complexity, and existing conventions. If you name a pattern, it validates fit before you commit.
- **Dedicated playbooks**: Each architecture has its own reference with code patterns, anti-pattern fixes, testing strategy, and a PR review checklist. Guidance stays scoped to your task.
- **SwiftUI and UIKit**: Every playbook covers both stacks and calls out where they differ, using modern async/await and actor-based concurrency patterns.

## Supported Architectures

- **MVP** - Model-View-Presenter pattern ([playbook](swift-architecture-skill/references/mvp.md))
- **MVVM** - Model-View-ViewModel pattern ([playbook](swift-architecture-skill/references/mvvm.md))
- **MVI** - Model-View-Intent pattern ([playbook](swift-architecture-skill/references/mvi.md))
- **TCA** - The Composable Architecture ([playbook](swift-architecture-skill/references/tca.md))
- **Clean Architecture** - Layered architecture with dependency inversion ([playbook](swift-architecture-skill/references/clean-architecture.md))
- **VIPER** - View-Interactor-Presenter-Entity-Router pattern ([playbook](swift-architecture-skill/references/viper.md))
- **Coordinator** - Navigation flow decoupling pattern ([playbook](swift-architecture-skill/references/coordinator.md))
- **Reactive** - Combine/RxSwift patterns ([playbook](swift-architecture-skill/references/reactive.md))

## Quick Start

### Option A: `skills.sh` (Recommended)

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then ask your agent:

> Use `swift-architecture-skill` to recommend and scaffold architecture for this feature.

[View this skill on skills.sh](https://skills.sh/efremidze/swift-architecture-skill/swift-architecture-skill)

### Option B: Claude Code Plugin

1. Add the marketplace:

```bash
/plugin marketplace add efremidze/swift-architecture-skill
```

2. Install the skill:

```bash
/plugin install swift-architecture-skill@swift-architecture-skill
```

For team setup, add this to `.claude/settings.json`:

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
2. Copy or symlink `swift-architecture-skill/` into your tool's skills directory.
3. Ask your AI assistant to use `swift-architecture-skill` for architecture tasks.

## Example Prompts

```text
I'm building a SwiftUI feed with pagination, pull-to-refresh, and live updates.
Which architecture should I use and why?
```

```text
Use swift-architecture-skill to review this ViewModel for MVVM violations
and suggest concrete fixes.
```

```text
Help me migrate this 500-line UIViewController to Clean Architecture
incrementally, with tests at each step.
```

## What You Get

- architecture fit-check for explicit requests (`fit` vs `mismatch` + rationale)
- feature-scoped file/module structure and dependency boundaries
- async/await + actor-aware implementation guidance
- anti-pattern detection with direct "instead of X, do Y" fixes
- architecture-specific testing strategy and PR review checklist

## How the Skill Works

1. Analyzes task context: feature type, scope, UI stack, team constraints.
2. Selects or validates architecture using `references/selection-guide.md`.
3. Loads the matching playbook and generates implementation-ready guidance.
4. Ends with a checklist tailored to the chosen architecture.

## Skill Structure

```text
swift-architecture-skill/
  SKILL.md                       # Routing logic and output requirements
  agents/
    openai.yaml                  # Interface metadata for skill-capable tools
  references/
    selection-guide.md           # Decision framework across architectures
    mvp.md                       # MVP playbook
    mvvm.md                      # MVVM playbook
    mvi.md                       # MVI playbook
    tca.md                       # TCA playbook
    clean-architecture.md        # Clean Architecture playbook
    viper.md                     # VIPER playbook
    coordinator.md               # Coordinator playbook
    reactive.md                  # Reactive (Combine/RxSwift) playbook
```

Each playbook follows a consistent contract:
- overview and when to use it
- core concepts and implementation patterns
- anti-patterns with direct fixes
- testing strategy
- PR review checklist

## Related Skills

- [swift-patterns-skill](https://github.com/efremidze/swift-patterns-skill)

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for structure and quality requirements.

## License

MIT License. See [LICENSE](LICENSE) for details.
