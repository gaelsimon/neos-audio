#!/usr/bin/env bash
# Runs the SPM package test suites with coverage and emits a SonarQube generic
# coverage report at coverage-sonar.xml (repo-root relative paths).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
LCOV="$ROOT/coverage.lcov"
: > "$LCOV"

for pkg in NeosDomain HEOSKit; do
  echo "▸ $pkg coverage"
  swift test --package-path "$pkg" --enable-code-coverage
  bin="$(swift build --package-path "$pkg" --show-bin-path)"
  prof="$(find "$bin/codecov" -name '*.profdata' | head -1)"
  xctest="$(find "$bin" -name '*.xctest' | head -1)"
  binary="$xctest/Contents/MacOS/$(basename "$xctest" .xctest)"
  # Only project sources; drop tests and checkouts.
  xcrun llvm-cov export "$binary" -instr-profile "$prof" -format=lcov \
    -ignore-filename-regex='(/Tests/|/\.build/|/checkouts/)' >> "$LCOV"
done

python3 scripts/lcov_to_sonar.py "$LCOV" "$ROOT" "$ROOT/coverage-sonar.xml"
rm -f "$LCOV"
