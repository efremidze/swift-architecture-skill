# Contributing Guide

Thanks for contributing to `swift-architecture-skill`.

This repository is documentation-first: it defines a routing skill (`SKILL.md`) and architecture playbooks (`references/*.md`) used by coding agents.

## Before You Start

1. Read `swift-architecture-skill/SKILL.md` to understand how architecture selection and routing works.
2. Review `swift-architecture-skill/references/selection-guide.md` to see current decision criteria.
3. Skim one or two existing playbooks (for example `mvvm.md`, `tca.md`) to match structure and tone.

## Repository Structure

```text
swift-architecture-skill/
  SKILL.md
  agents/openai.yaml
  references/
    selection-guide.md
    mvvm.md
    mvi.md
    tca.md
    clean-architecture.md
    viper.md
    reactive.md
```

## What Good Contributions Look Like

- Concrete, implementation-ready guidance instead of abstract advice
- Modern Swift patterns (Swift 5.9+, async/await, actors, SwiftUI-first where appropriate)
- Clear anti-patterns and direct fixes
- Consistent playbook sections and checklist quality

## Add or Update a Playbook

When editing any file in `swift-architecture-skill/references/`, keep this structure:

1. Overview and when to use it
2. Core concepts and principles
3. Code patterns with Swift examples
4. Anti-patterns with fixes
5. Testing strategy
6. PR review checklist

Content expectations:

- Use protocol-based dependency injection
- Include error handling in async operations
- Prefer value-based navigation modeling (enum/struct) over UIKit reference wiring
- Keep examples focused and syntactically correct

## Add a New Architecture

1. Create a new playbook in `swift-architecture-skill/references/<architecture>.md`.
2. Follow the required playbook structure listed above.
3. Update `swift-architecture-skill/SKILL.md`:
   - Add the architecture to the mapping in **Step 2: Select the Architecture**
   - Mention it in any architecture list that should include it
4. Update `swift-architecture-skill/references/selection-guide.md`:
   - Add decision criteria signals
   - Add it to the decision matrix/flow if applicable
   - Document valid combinations with other patterns when relevant
5. If needed, update `README.md` so supported architectures and project structure stay accurate.

## Swift Example Conventions

- Swift naming conventions (`PascalCase` types, `camelCase` members)
- `private(set)` for externally read-only state in ViewModels
- `@MainActor` on test classes that test `MainActor`-isolated types
- Effects handle their own errors and map to explicit failure actions
- Comments only for non-obvious architectural decisions

## Validation Checklist

Use both automated and manual checks:

1. Run automated validators:

```bash
python -m skills_ref.cli validate ./swift-architecture-skill
./scripts/validate/testing-snippets.sh
python3 ./scripts/validate/testing-quality.py
./scripts/run/benchmarks.py
python3 ./scripts/validate/benchmark-coverage.py
python3 ./scripts/run/corpus.py
python3 ./scripts/validate/architecture.py
```

2. Complete manual review:

   1. Markdown formatting is clean and readable
   2. Cross-file references are correct (`SKILL.md` and `selection-guide.md` stay in sync)
   3. New guidance is specific enough for an agent to apply directly

## Useful Commands

```bash
find . -name "*.md"
grep -r "pattern" swift-architecture-skill/references/
wc -l swift-architecture-skill/references/*.md
```

For automated validation commands, use the canonical list under `Validation Checklist`.

## Pull Request Checklist

Before opening a PR, confirm:

- Scope is focused and architecture-specific where applicable
- New or changed examples follow modern Swift concurrency practices
- Anti-pattern sections include actionable corrections
- `swift-architecture-skill/SKILL.md` reflects any new architecture references
- `swift-architecture-skill/references/selection-guide.md` reflects decision updates
- `README.md` was updated if public-facing architecture lists changed
