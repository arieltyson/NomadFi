#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

python3 scripts/check-staged-security.py --check-dependencies
chmod +x scripts/normalize-xcstrings.sh .githooks/pre-commit
git config core.hooksPath .githooks

echo "Installed git hooks for this repository."
echo "Active hooks path: $(git config --get core.hooksPath)"
