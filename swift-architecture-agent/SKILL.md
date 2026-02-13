---
name: swift-architecture-agent
description: Architecture selection and implementation guidance for Swift iOS codebases, with architecture-specific playbooks and review checklists. Use when designing new features, refactoring existing modules, reviewing pull requests, or debugging maintainability issues in SwiftUI/UIKit projects and you need concrete guidance for MVVM (and future architecture guides).
---

# Swift Architecture Agent

## Overview

Use this skill as an architecture router for Swift feature work. Select the architecture playbook that matches the request, then apply its patterns to produce implementation-ready guidance.

## Workflow

1. Identify the requested architecture.
2. If the user explicitly asks for MVVM, load `references/mvvm.md`.
3. If no architecture is specified, infer one from stated constraints (state complexity, team familiarity, testing goals, and effect orchestration needs) and explain the recommendation briefly.
4. Read only the relevant architecture reference file(s) from `references/`.
5. Convert the selected guide into concrete deliverables for the user request:
- file and module structure
- state and dependency boundaries
- concurrency and cancellation strategy
- testing strategy
6. End with a concise validation checklist for code review.

## Architecture References

- MVVM: `references/mvvm.md`

## Output Requirements

- Keep recommendations scoped to the requested feature or review task.
- Prefer protocol-based dependency injection and explicit state modeling.
- Flag anti-patterns and provide direct fixes.
- Include cancellation and error handling in async flows.
- Ask only minimum blocking questions; otherwise proceed with explicit assumptions.
