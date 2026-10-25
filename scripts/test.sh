#!/usr/bin/env bash
# Runs every test suite. Usage: ./scripts/test.sh [unit|ui|packages|all]  (default: all)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build/test"
RESULTS="$ROOT/build/test-results"
WHAT=${1:-all}
status=0
cd "$ROOT"
mkdir -p "$RESULTS"

run_xcode() { # $1 = test target
  local bundle="$RESULTS/$1.xcresult"
  rm -rf "$bundle"
  echo "▶ $1"
  if xcodebuild test -project Rondo.xcodeproj -scheme Rondo -destination 'platform=macOS' \
      -derivedDataPath "$DERIVED" -enableCodeCoverage YES -only-testing:"$1" \
      -resultBundlePath "$bundle" > "$RESULTS/$1.log" 2>&1; then
    grep -E "Test run with|Executed [0-9]+ tests?," "$RESULTS/$1.log" | tail -1
  else
    grep -E "error:|✘|failed" "$RESULTS/$1.log" | head -30
    echo "✖ $1 failed (log: $RESULTS/$1.log)"
    status=1
  fi
}

run_packages() {
  for pkg in "$ROOT"/Packages/*/; do
    [ -f "$pkg/Package.swift" ] || continue
    echo "▶ $(basename "$pkg")"
    if swift test --package-path "$pkg" > "$RESULTS/$(basename "$pkg").log" 2>&1; then
      grep -E "Executed|Test run with" "$RESULTS/$(basename "$pkg").log" | tail -2
    else
      tail -30 "$RESULTS/$(basename "$pkg").log"
      echo "✖ $(basename "$pkg") failed"
      status=1
    fi
  done
}

case "$WHAT" in
  unit) run_xcode RondoTests ;;
  ui) run_xcode RondoUITests ;;
  packages) run_packages ;;
  all) run_xcode RondoTests; run_xcode RondoUITests; run_packages ;;
  *) echo "usage: $0 [unit|ui|packages|all]"; exit 2 ;;
esac

if [ -d "$RESULTS/RondoTests.xcresult" ]; then
  echo "Coverage (Rondo.app):"
  xcrun xccov view --report --only-targets "$RESULTS/RondoTests.xcresult" 2>/dev/null | grep -E "Rondo.app" || true
fi
exit $status
