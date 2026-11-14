#!/usr/bin/env bash
# The walk's guard (CLAUDE.md, "An edited walk test is a failure, not a fix"):
# since <start>, no walk test, walk-test helper or fixture is edited beyond an
# import line, test/fixtures is only added to, and no golden PNG has changed.
#
#   tool/walk_guard.sh <start>      # <start>: the commit the work began from
#
# The same three checks CLAUDE.md lists, in one place, so a session before
# committing and CI on every push run exactly the same thing. Prints what
# breaks the rule and exits 1, or exits 0.
set -euo pipefail

start="${1:?usage: tool/walk_guard.sh <start commit>}"
cd "$(dirname "$0")/.."
broken=0

# 1. Walk tests, their helpers and the goldens' code: no line changed but an
#    import (a file the work moved). git prints no +/- line for a PNG, hence 3.
edits="$(git diff -M -U0 --diff-filter=MRD "$start" -- \
    test/features/gene_lookup test/core test/support test/goldens \
  | grep -E '^[+-]' | grep -vE '^(\+\+\+|---) |^[+-]import ' || true)"
if [ -n "$edits" ]; then
  echo "Walk tests edited since $start (only an import line may change):"
  printf '%s\n' "$edits" | head -60
  broken=1
fi

# 2. test/fixtures: a new curated protein's files and rows only.
if ! python3 tool/fixtures_added_only.py "$start"; then
  broken=1
fi

# 3. No golden PNG modified, renamed or deleted (a new one is a new surface).
if ! git diff --quiet --diff-filter=MRD "$start" -- 'test/goldens/**/*.png'; then
  echo "Golden PNGs changed since $start:"
  git diff --name-status --diff-filter=MRD "$start" -- 'test/goldens/**/*.png'
  broken=1
fi

exit "$broken"
