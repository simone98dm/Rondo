#!/usr/bin/env bash
# Formats Swift files with the swift-format bundled in Xcode, using .swift-format.
# Usage: ./scripts/format.sh            → files changed against main (staged, unstaged and new)
#        ./scripts/format.sh --check    → lint those files instead of rewriting them
#        ./scripts/format.sh FILE...    → only these files
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE=format
[ "${1:-}" = "--check" ] && { MODE=lint; shift; }

if [ $# -gt 0 ]; then
  FILES=("$@")
else
  BASE=$(git merge-base HEAD main 2>/dev/null || echo HEAD)
  FILES=()
  while IFS= read -r file; do
    [ -f "$file" ] && FILES+=("$file")
  done < <( { git diff --name-only "$BASE" -- '*.swift'; git ls-files --others --exclude-standard -- '*.swift'; } | sort -u)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No Swift files to $MODE."
  exit 0
fi

if [ "$MODE" = lint ]; then
  xcrun swift-format lint "${FILES[@]}"
else
  xcrun swift-format format --in-place "${FILES[@]}"
  echo "Formatted ${#FILES[@]} file(s)."
fi
