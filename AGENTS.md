# AGENTS Guidelines for Swift Architecture Skill

This repository provides an Agent Skill for Swift iOS architecture guidance. It contains architecture playbooks and selection guides to help coding agents provide concrete design and implementation patterns for Swift/SwiftUI/UIKit projects.

## Working with This Repository

### 1. Understanding the Skill

Before making changes:
- Read `swift-architecture-skill/SKILL.md` to understand the overall workflow
- The skill acts as a router that selects appropriate architecture playbooks based on user requests
- Each playbook in `references/` is a self-contained guide with patterns, anti-patterns, and checklists

### 2. Modifying Architecture Playbooks

When editing playbooks in `swift-architecture-skill/references/`:
- **Maintain consistent structure**: Each playbook should have core concepts, code patterns, anti-patterns, testing strategy, and PR review checklist
- **Use modern Swift**: All code examples should use Swift concurrency (async/await, actors) and SwiftUI patterns where applicable
- **Include complete examples**: Code snippets should be runnable and demonstrate the full pattern
- **Provide anti-pattern fixes**: Show both the wrong way and the correct way with explanations

### 3. Testing and Validation

This repository contains documentation and skill definitions rather than executable code:
- **No automated tests**: Changes should be validated through manual review
- **Check markdown formatting**: Ensure all `.md` files are properly formatted
- **Verify code examples**: Code snippets in playbooks should be syntactically correct Swift
- **Cross-reference consistency**: Ensure SKILL.md correctly references all playbooks

### 4. Adding New Architecture Patterns

To add a new architecture playbook:

1. Create a new `.md` file in `swift-architecture-skill/references/`
2. Follow the existing playbook structure:
   - Overview and when to use this pattern
   - Core concepts and principles
   - Code patterns with examples
   - Anti-patterns with fixes
   - Testing strategy
   - PR review checklist
3. Update `swift-architecture-skill/SKILL.md` to reference the new playbook
4. Update `references/selection-guide.md` to include the new pattern in decision criteria

### 5. Coding Conventions

When writing Swift code examples in playbooks:
- Use Swift 5.9+ features (async/await, actors, structured concurrency)
- Prefer SwiftUI over UIKit unless demonstrating UIKit-specific patterns
- Follow Swift naming conventions (PascalCase for types, camelCase for properties/functions)
- Use protocol-based dependency injection
- Include error handling in all async operations
- Add comments only when explaining non-obvious architecture decisions

### 6. Documentation Style

- Use clear, concise language
- Include "Why" explanations for architectural decisions
- Provide comparative examples (e.g., "Instead of X, do Y because...")
- Use bullet points for lists of rules or guidelines
- Use code blocks with Swift syntax highlighting
- Keep examples focused and minimal (prefer clarity over completeness)

## Useful Commands

| Command | Purpose |
| ------- | ------- |
| `find . -name "*.md"` | List all markdown files |
| `grep -r "pattern" swift-architecture-skill/references/` | Search across all playbooks |
| `wc -l swift-architecture-skill/references/*.md` | Check playbook sizes |

## Memory and Context

When working on this repository:
- **State management patterns**: ViewModels use `private(set)` for state properties
- **Testing conventions**: Use `@MainActor` on test classes that test MainActor-isolated types
- **Error handling**: Effects must handle their own errors and map to failure actions
- **Navigation**: Model navigation as value types (enum/struct), not UIKit references
- **Assembly pattern**: Use static factory methods like `makeViewModel()` for dependency injection

## Reference Links

- [AGENTS.md specification](https://github.com/agentsmd/agents.md)
- [Swift Architecture Skill Guide](swift-architecture-skill/SKILL.md)

---

Following these guidelines will help maintain consistency and quality when working on architecture playbooks and skill definitions.
