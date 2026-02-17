# Swift Architecture Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.4.0-blue.svg)](https://github.com/efremidze/swift-architecture-skill/releases)

An Agent Skill that provides architecture guidance for Swift, SwiftUI, and UIKit iOS development. Get concrete, actionable patterns instead of abstract advice.

## What This Skill Does

This skill helps AI coding assistants make better architecture decisions for your iOS projects:

- **Smart Architecture Selection**: Describe your feature and constraints—the skill analyzes your UI stack (SwiftUI/UIKit), state complexity, and existing patterns to recommend the best architecture. Or name a specific pattern and get validation with alternatives if there's a mismatch.

- **Implementation-Ready Playbooks**: Each architecture comes with concrete code patterns, common anti-patterns with fixes, testing strategies, and PR review checklists—all scoped to your specific task, not generic documentation.

- **Modern Swift Best Practices**: All guidance uses Swift 5.9+ features including async/await, actors, and structured concurrency. Both SwiftUI and UIKit patterns are covered with clear guidance on their differences.

## Supported Architectures

- **[MVVM](swift-architecture-skill/references/mvvm.md)** - Model-View-ViewModel with observable state and protocol-based dependency injection
- **[MVI](swift-architecture-skill/references/mvi.md)** - Model-View-Intent with unidirectional data flow and immutable state
- **[TCA](swift-architecture-skill/references/tca.md)** - The Composable Architecture with composable reducers and effects
- **[Clean Architecture](swift-architecture-skill/references/clean-architecture.md)** - Layered architecture with clear boundaries and dependency inversion
- **[VIPER](swift-architecture-skill/references/viper.md)** - View-Interactor-Presenter-Entity-Router for modular, testable apps
- **[Reactive](swift-architecture-skill/references/reactive.md)** - Combine/RxSwift patterns for reactive data streams

## Quick Start

### For Claude Code Plugin

Add the marketplace:

```bash
/plugin marketplace add efremidze/swift-architecture-skill
```

Install the skill:

```bash
/plugin install swift-architecture-skill@swift-architecture-skill
```

Then use it in your conversations:

```
Review my SwiftUI view for state management issues using swift-architecture-skill
```

```
Help me design a new user profile feature with MVVM architecture
```

### For OpenAI/Cursor/Other AI Tools

Install via skills CLI:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then reference it in your AI tool:

```
Use swift-architecture-skill to recommend the best architecture for my feed feature
```

## Example Usage

Here are some ways to use this skill with your AI coding assistant:

**Architecture Selection:**
```
I'm building a social feed feature with infinite scroll, pull-to-refresh, 
and real-time updates. What architecture should I use?
```

**Code Review:**
```
Review this ViewModel for MVVM best practices and suggest improvements
[paste your code]
```

**Refactoring Guidance:**
```
I have a massive UIViewController with 500+ lines. Help me refactor it 
to Clean Architecture with clear layer boundaries.
```

**Testing Strategy:**
```
Show me how to test this MVI reducer with mock dependencies and verify 
all state transitions.
```

The skill will provide concrete, implementation-ready guidance including:
- File structure and module organization
- Protocol definitions for dependency injection
- Complete code examples with async/await patterns
- Anti-patterns to avoid with specific fixes
- Testing approach with example test cases
- Architecture-specific PR review checklist

## Detailed Installation

### Option A: Claude Code Plugin (Recommended)

**For Personal Use:**

1. Add the marketplace:

```bash
/plugin marketplace add efremidze/swift-architecture-skill
```

2. Install the skill:

```bash
/plugin install swift-architecture-skill@swift-architecture-skill
```

**For Team Setup:**

Configure in your project's `.claude/settings.json`:

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

### Option B: Skills CLI (OpenAI/Cursor/Other Tools)

Install this skill with:

```bash
npx skills add https://github.com/efremidze/swift-architecture-skill --skill swift-architecture-skill
```

Then reference it in your prompts:

```bash
Use swift-architecture-skill to recommend the best architecture for this feature.
```

### Option C: Manual Installation

For custom setups or local development:

1. Clone this repository:
   ```bash
   git clone https://github.com/efremidze/swift-architecture-skill.git
   ```

2. Symlink or copy the `swift-architecture-skill/` directory to your AI tool's skills directory.

3. Reference the skill in your AI tool conversations.

## How It Works

When you use this skill, the AI assistant follows this workflow:

1. **Analyzes Your Context**: Understands your task type (new feature, refactor, review), UI stack (SwiftUI/UIKit), and existing codebase conventions.

2. **Selects Architecture**: Either validates your explicitly requested architecture against your constraints, or recommends the best fit based on state complexity, team experience, and project needs.

3. **Provides Concrete Guidance**: Delivers implementation-ready patterns from the selected architecture playbook, including:
   - File and module structure
   - Protocol-based dependency injection patterns
   - Async/await and actor isolation strategies
   - Testing approach with example test cases
   - Migration paths for refactoring work

4. **Reviews with Checklist**: Applies architecture-specific PR review criteria to catch common anti-patterns and ensure consistency.

## Project Structure

```
swift-architecture-skill/
├── SKILL.md                    # Skill definition and workflow
├── agents/
│   └── openai.yaml            # Agent interface configuration
└── references/
    ├── selection-guide.md      # Architecture decision framework
    ├── mvvm.md                 # MVVM pattern playbook
    ├── mvi.md                  # MVI pattern playbook
    ├── tca.md                  # TCA playbook
    ├── clean-architecture.md   # Clean Architecture playbook
    ├── viper.md                # VIPER playbook
    └── reactive.md             # Reactive (Combine/RxSwift) playbook
```

Each playbook follows a consistent structure:
- **Overview and Use Cases**: When to use this architecture
- **Core Concepts**: Key principles and patterns
- **Code Examples**: Complete, runnable Swift code with async/await
- **Anti-Patterns**: Common mistakes with fixes
- **Testing Strategy**: How to test each component
- **PR Review Checklist**: Architecture-specific review criteria

## Related Skills

- [swift-patterns-skill](https://github.com/efremidze/swift-patterns-skill) - Swift design patterns and idioms

## FAQ

**Q: Can I use this with GitHub Copilot?**  
A: Yes, if you're using Copilot with an AI coding assistant that supports Agent Skills format, you can install and reference this skill.

**Q: Does this work with both SwiftUI and UIKit?**  
A: Yes! Every architecture playbook provides patterns for both SwiftUI and UIKit, with clear guidance on where they differ.

**Q: What if my project uses a different architecture?**  
A: The selection guide will help you find the closest match, or you can explicitly name an architecture and get validation with alternatives. The skill supports the most common iOS architectures.

**Q: Can I contribute improvements?**  
A: Absolutely! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on improving playbooks and adding new patterns.

## Contributing

Contributions are welcome! This repository provides architecture playbooks for AI coding assistants.

**What to contribute:**
- Improvements to existing architecture playbooks
- New architecture patterns
- Better code examples using modern Swift
- Clearer anti-pattern explanations

**Before contributing:**
- Read [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines
- Review existing playbooks to match structure and style
- Ensure Swift examples are syntactically correct and use Swift 5.9+ features

All playbooks must include: overview, core concepts, code patterns, anti-patterns with fixes, testing strategy, and PR review checklist.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

**Lasha Efremidze**
- GitHub: [@efremidze](https://github.com/efremidze)
- Email: efremidzel@hotmail.com

---

*This skill follows the [Agent Skills](https://github.com/agentskills/agentskills) open format for AI-assisted development tools.*
