#!/usr/bin/env bash
# scripts/verify.sh - Unified Quality Assurance and Verification Suite
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEST_PATTERN=""

show_help() {
  echo "Usage: ./scripts/verify.sh [OPTIONS]"
  echo ""
  echo "Runs the Pomo verification suite: dependencies, localizations, formatting, static analysis, and regression tests."
  echo ""
  echo "Options:"
  echo "  -h, --help           Show this help message and exit"
  echo "  -t, --test <pattern> Run only tests matching <pattern> (by file path or test description)"
  echo ""
  echo "Examples:"
  echo "  ./scripts/verify.sh"
  echo "  ./scripts/verify.sh --test cubit"
  echo "  ./scripts/verify.sh --test test/helpers/lap_helper_test.dart"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -t|--test)
      if [ -z "${2:-}" ]; then
        echo "Error: --test requires a pattern argument."
        exit 1
      fi
      TEST_PATTERN="$2"
      shift 2
      ;;
    --test=*)
      TEST_PATTERN="${1#*=}"
      shift 1
      ;;
    *)
      echo "Error: Unknown argument '$1'. Run with --help for usage."
      exit 1
      ;;
  esac
done

echo "=========================================="
echo "Running Pomo Verification Suite..."
echo "=========================================="

echo "1. Synchronizing dependencies and localizations..."
flutter pub get >/dev/null
flutter gen-l10n >/dev/null

echo "2. Checking Dart code formatting..."
if ! dart format --output=none --set-exit-if-changed lib/ test/ scripts/; then
  echo "Error: Code formatting check failed. Please run 'dart format lib/ test/ scripts/' to fix."
  exit 1
fi

echo "3. Running static analysis (very_good_analysis)..."
if ! flutter analyze --no-fatal-infos; then
  echo "Error: Static analysis reported issues. Please fix all lints before submitting."
  exit 1
fi

echo "4. Executing automated regression test suite..."
if [ -d "test" ] && [ "$(ls -A test/*.dart test/**/*.dart 2>/dev/null | wc -l)" -gt 0 ]; then
  if [ -n "$TEST_PATTERN" ]; then
    echo "Running targeted tests matching: '$TEST_PATTERN'..."
    if [ -e "$TEST_PATTERN" ]; then
      flutter test --flavor development "$TEST_PATTERN"
    elif [ -n "$(find test -name "*${TEST_PATTERN}*.dart" 2>/dev/null)" ]; then
      find test -name "*${TEST_PATTERN}*.dart" 2>/dev/null | xargs flutter test --flavor development
    else
      flutter test --flavor development --plain-name "$TEST_PATTERN"
    fi
  else
    flutter test --flavor development
  fi
else
  echo "Notice: No test files detected yet in test/. Skipping test step."
fi

echo "=========================================="
echo "Verification Suite Passed Successfully!"
echo "=========================================="
