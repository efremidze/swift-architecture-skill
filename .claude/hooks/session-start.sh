#!/bin/bash
set -euo pipefail

# SessionStart hook: install the validation dependency so the repo's checks
# (skill validation, evals, benchmarks) can run in Claude Code on the web.
#
# Only the skills-ref CLI is an external dependency; the tooling/ validators
# use the Python standard library, and jq (for evals.sh) ships with the image.
# Swift snippet validation needs swiftc, which is macOS-only and skips cleanly
# on the Linux web environment.

# Only run in the remote (web) environment; local machines manage their own deps.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Idempotent: skip the install if skills-ref is already importable.
if ! python3 -c "import skills_ref" >/dev/null 2>&1; then
  python3 -m pip install --quiet --root-user-action=ignore \
    "git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref"
fi

echo "session-start: skills-ref ready"
