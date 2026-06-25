# Swift Architecture Skill

[![Validate Skill](https://github.com/efremidze/swift-architecture-skill/actions/workflows/validate-skill.yml/badge.svg)](https://github.com/efremidze/swift-architecture-skill/actions/workflows/validate-skill.yml)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Compatible-purple.svg)](https://agentskills.io/home)
![Release](https://img.shields.io/github/v/release/efremidze/swift-architecture-skill)

Architecture guidance for AI coding tools — because LLMs default to MVVM for everything. This skill routes to the right pattern for your feature, keeps guidance scoped to your task, and gives you concrete code, anti-pattern fixes, and a PR checklist.

Supports the [Agent Skills open format](https://agentskills.io/home).

## Features

- **Routes to the right architecture**: Describe your feature and the skill selects the best fit based on UI stack, state complexity, and existing conventions. Name a pattern yourself and it validates the fit before you commit.
- **Scoped playbooks**: Each architecture has its own reference — code patterns, anti-pattern fixes, testing strategy, and a PR checklist. Guidance never bleeds across patterns.
- **Reference index**: A dedicated `_index.md` gives agents a fast navigation hub and problem router before diving into a playbook.
- **SwiftUI and UIKit**: Every playbook covers both stacks with modern async/await and actor-based concurrency patterns throughout.

## Supported Architectures

MVP · MVVM · MVI · TCA · Clean Architecture · VIPER · Coordinator · Reactive

Each has a dedicated [playbook](swift-architecture-skill/references/) with overview, patterns, anti-pattern fixes, testing strategy, and PR checklist.
Start with the [reference index](swift-architecture-skill/references/_index.md) for quick routing, or use the [selection guide](swift-architecture-skill/references/selection-guide.md) when the architecture is still undecided.

## Installation

### skills.sh (recommended)

Works with any tool that supports the [Agent Skills](https://agentskills.io) format:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

### Claude Code plugin

Install from the marketplace for personal use:

```text
/plugin marketplace add efremidze/swift-architecture-skill
/plugin install swift-architecture-skill@swift-architecture-skill
```

Or enable it for an entire project by committing this to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "swift-architecture-skill": {
      "source": {
        "source": "github",
        "repo": "efremidze/swift-architecture-skill"
      }
    }
  },
  "enabledPlugins": {
    "swift-architecture-skill@swift-architecture-skill": true
  }
}
```

### Manual install

Clone the repository and copy the skill into your tool's skills directory. For Claude Code that's `~/.claude/skills/` (personal, available everywhere):

```bash
git clone https://github.com/efremidze/swift-architecture-skill.git
mkdir -p ~/.claude/skills
cp -r swift-architecture-skill/swift-architecture-skill ~/.claude/skills/swift-architecture-skill
```

For a project-scoped install, swap the destination for the project's `.claude/skills/` instead:

```bash
mkdir -p .claude/skills
cp -r swift-architecture-skill/swift-architecture-skill .claude/skills/swift-architecture-skill
```

## Usage

Once installed, ask your agent:

> Use `swift-architecture-skill` to recommend and scaffold architecture for this feature.

## Example Prompts

```text
I'm building a SwiftUI feed with pagination, pull-to-refresh, and live updates.
Which architecture should I use and why?
```

```text
We're planning to use TCA for a simple settings screen with two toggles.
Is that the right call, or is it overkill for this feature?
```

```text
This module started as MVVM but the ViewModel is doing too much — routing,
formatting, and business logic. Use swift-architecture-skill to refactor it
toward Clean Architecture and show me the layer boundaries.
```

```text
We have a UIKit + MVP module we're migrating to SwiftUI. Should we keep MVP
or switch patterns during the migration, and how do we handle the transition
period where both coexist?
```

## Skill Structure

```text
swift-architecture-skill/
  SKILL.md                       # Routing logic and output requirements
  references/
    _index.md                    # Navigation hub and problem router
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
