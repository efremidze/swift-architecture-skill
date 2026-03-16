# Swift Architecture Skill

![Release](https://img.shields.io/github/v/release/efremidze/swift-architecture-skill)
[![Validate Skill](https://github.com/efremidze/swift-architecture-skill/actions/workflows/validate-skill.yml/badge.svg)](https://github.com/efremidze/swift-architecture-skill/actions/workflows/validate-skill.yml)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Compatible-purple.svg)](https://agentskills.io/home)

Architecture guidance for AI coding tools — because LLMs default to MVVM for everything. This skill routes to the right pattern for your feature, keeps guidance scoped to your task, and gives you concrete code, anti-pattern fixes, and a PR checklist.

Supports the [Agent Skills open format](https://agentskills.io/home).

## Features

- **Routes to the right architecture**: Describe your feature and the skill selects the best fit based on UI stack, state complexity, and existing conventions. Name a pattern yourself and it validates the fit before you commit.
- **Scoped playbooks**: Each architecture has its own reference — code patterns, anti-pattern fixes, testing strategy, and a PR checklist. Guidance never bleeds across patterns.
- **SwiftUI and UIKit**: Every playbook covers both stacks with modern async/await and actor-based concurrency patterns throughout.

## Supported Architectures

MVP · MVVM · MVI · TCA · Clean Architecture · VIPER · Coordinator · Reactive

Each has a dedicated [playbook](swift-architecture-skill/references/) with overview, patterns, anti-pattern fixes, testing strategy, and PR checklist.

## Quick Start

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then ask your agent:

> Use `swift-architecture-skill` to recommend and scaffold architecture for this feature.

Or clone this repository and drop `swift-architecture-skill/` into your tool's skills directory.

## Example Prompts

```text
I'm building a SwiftUI feed with pagination, pull-to-refresh, and live updates.
Which architecture should I use and why?
```

```text
Use swift-architecture-skill to review this ViewModel for MVVM violations
and suggest concrete fixes.
```

## Skill Structure

```text
swift-architecture-skill/
  SKILL.md                       # Routing logic and output requirements
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

## Contributing

Contributions are welcome. A few things to keep in mind:

- **Respect the token budget.** SKILL.md is loaded on every invocation — keep additions concise.
- **Don't repeat what LLMs already know.** Focus on edge cases, common mistakes, and pattern-specific traps that models get wrong.
- **One playbook per pattern.** Keep guidance scoped; don't let patterns bleed into each other.

See [CONTRIBUTING.md](CONTRIBUTING.md) for full structure and quality requirements.

## Related

- [swift-patterns-skill](https://github.com/efremidze/swift-patterns-skill)

## License

MIT. See [LICENSE](LICENSE) for details.
