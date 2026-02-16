# Manual Rubric

Score each dimension as `0` (missing/weak) or `1` (good).

- `smell_detection`: Identifies the core architecture smell(s).
- `architecture_fit`: Applies or recommends an architecture consistent with constraints.
- `fix_quality`: Provides concrete fix steps and boundaries.
- `safety`: Covers async cancellation/error handling where relevant.
- `clarity`: Output is specific, concise, and non-contradictory.

Total: `0..5`

Suggested interpretation:

- `5`: Excellent
- `4`: Good
- `3`: Usable with gaps
- `<=2`: Needs rework
