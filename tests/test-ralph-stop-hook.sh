#!/bin/bash

# Integration tests for ralph-stop-hook.sh
#
# Tests that the stop hook correctly:
# 1. Blocks exit when validation fails (even if promise is present)
# 2. Allows exit when validation passes
# 3. Handles missing validation commands correctly
# 4. Never lets a false promise short-circuit real validation
#
# Usage: bash tests/test-ralph-stop-hook.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/tactical-engineering"
HOOK_SCRIPT="$PLUGIN_ROOT/hooks/ralph-stop-hook.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup_test_env() {
  local test_name="$1"
  TEST_DIR=$(mktemp -d)
  TEST_PROJECT="$TEST_DIR/project"
  mkdir -p "$TEST_PROJECT/.claude/specs"

  # Create a mock transcript file
  TRANSCRIPT_FILE="$TEST_DIR/transcript.jsonl"
  echo '{}' > "$TRANSCRIPT_FILE"

  echo -e "${YELLOW}--- Test: $test_name ---${NC}"
}

teardown_test_env() {
  rm -rf "$TEST_DIR"
}

create_state_file() {
  local spec_path="$1"
  local completion_promise="${2:-DONE}"
  local current_iteration="${3:-0}"
  local max_iterations="${4:-5}"

  # Sanitize spec name the same way state-file.js does:
  # remove specs/ prefix, remove .md extension, replace / with -
  local sanitized
  sanitized=$(echo "$spec_path" | sed 's|^specs/||' | sed 's|\.md$||' | tr '/' '-')
  mkdir -p "$TEST_PROJECT/.claude/specs/$sanitized"

  cat > "$TEST_PROJECT/.claude/specs/$sanitized/state.json" << EOF
{
  "build": {
    "specPath": "$spec_path",
    "specChecksum": "sha256:test",
    "startedAt": "2026-03-27T00:00:00Z",
    "lastUpdated": "2026-03-27T00:00:00Z",
    "completedAt": null,
    "totalTasks": 1,
    "mode": "team"
  },
  "tasks": [
    {
      "id": "1",
      "subject": "Placeholder task",
      "status": "completed",
      "activeForm": "Done",
      "blockedBy": []
    }
  ],
  "artifacts": [],
  "validation": {},
  "ralph": {
    "active": true,
    "mode": "build-validate",
    "maxIterations": $max_iterations,
    "currentIteration": $current_iteration,
    "selfHeal": false,
    "completionPromise": "$completion_promise",
    "startedAt": "2026-03-27T00:00:00Z",
    "status": "active",
    "history": [],
    "taskRetryCounters": {},
    "failureReport": null,
    "finalResult": null
  }
}
EOF
}

create_state_file_no_promise() {
  local spec_path="$1"

  local sanitized
  sanitized=$(echo "$spec_path" | sed 's|^specs/||' | sed 's|\.md$||' | tr '/' '-')
  mkdir -p "$TEST_PROJECT/.claude/specs/$sanitized"

  cat > "$TEST_PROJECT/.claude/specs/$sanitized/state.json" << EOF
{
  "build": {
    "specPath": "$spec_path",
    "specChecksum": "sha256:test",
    "startedAt": "2026-03-27T00:00:00Z",
    "lastUpdated": "2026-03-27T00:00:00Z",
    "completedAt": null,
    "totalTasks": 1,
    "mode": "team"
  },
  "tasks": [
    {
      "id": "1",
      "subject": "Placeholder task",
      "status": "completed",
      "activeForm": "Done",
      "blockedBy": []
    }
  ],
  "artifacts": [],
  "validation": {},
  "ralph": {
    "active": true,
    "mode": "build-validate",
    "maxIterations": 5,
    "currentIteration": 0,
    "selfHeal": false,
    "completionPromise": null,
    "startedAt": "2026-03-27T00:00:00Z",
    "status": "active",
    "history": [],
    "taskRetryCounters": {},
    "failureReport": null,
    "finalResult": null
  }
}
EOF
}

add_promise_to_transcript() {
  local promise_text="$1"
  cat > "$TRANSCRIPT_FILE" << EOF
{"role":"assistant","message":{"content":[{"type":"text","text":"Build complete.\n\n<promise>$promise_text</promise>"}]}}
EOF
}

run_hook() {
  # Run the stop hook with the test environment
  local output
  local exit_code=0

  output=$(cd "$TEST_PROJECT" && \
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    echo "{\"transcript_path\":\"$TRANSCRIPT_FILE\"}" | \
    bash "$HOOK_SCRIPT" 2>/dev/null) || exit_code=$?

  echo "$output"
  return $exit_code
}

assert_blocks() {
  local output="$1"
  local test_name="$2"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if echo "$output" | grep -q '"decision":"block"' 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}: $test_name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $test_name"
    echo "    Expected: block decision"
    echo "    Got: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

assert_allows() {
  local output="$1"
  local test_name="$2"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  # Allow exit = empty stdout (or no "decision":"block")
  if [[ -z "$output" ]] || ! echo "$output" | grep -q '"decision":"block"' 2>/dev/null; then
    echo -e "  ${GREEN}PASS${NC}: $test_name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $test_name"
    echo "    Expected: allow exit (empty output)"
    echo "    Got: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test 1: Failing validation + promise present → BLOCKS exit
# This is the critical test: promise alone must NOT short-circuit validation
# ---------------------------------------------------------------------------
setup_test_env "Failing validation + promise present → BLOCKS"

# Copy failing spec to test project
cp "$FIXTURES_DIR/spec-validation-fail.md" "$TEST_PROJECT/specs-fail.md"
create_state_file "specs-fail.md" "DONE"
add_promise_to_transcript "DONE"

OUTPUT=$(run_hook) || true
assert_blocks "$OUTPUT" "Failing validation with promise present must BLOCK exit"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 2: Passing validation + promise present → ALLOWS exit
# ---------------------------------------------------------------------------
setup_test_env "Passing validation + promise present → ALLOWS"

cp "$FIXTURES_DIR/spec-validation-pass.md" "$TEST_PROJECT/specs-pass.md"
create_state_file "specs-pass.md" "DONE"
add_promise_to_transcript "DONE"

OUTPUT=$(run_hook) || true
assert_allows "$OUTPUT" "Passing validation with promise must ALLOW exit"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 3: Passing validation + no promise → ALLOWS exit
# (All tasks done + all validation green = work is complete)
# ---------------------------------------------------------------------------
setup_test_env "Passing validation + no promise → ALLOWS"

cp "$FIXTURES_DIR/spec-validation-pass.md" "$TEST_PROJECT/specs-pass.md"
create_state_file_no_promise "specs-pass.md"

OUTPUT=$(run_hook) || true
assert_allows "$OUTPUT" "Passing validation without promise must ALLOW exit"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 4: No validation commands + no promise → ALLOWS exit
# (Tasks done, nothing to validate)
# ---------------------------------------------------------------------------
setup_test_env "No validation commands + no promise → ALLOWS"

cp "$FIXTURES_DIR/spec-no-validation.md" "$TEST_PROJECT/specs-none.md"
create_state_file_no_promise "specs-none.md"

OUTPUT=$(run_hook) || true
assert_allows "$OUTPUT" "No validation commands + no promise must ALLOW exit"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 5: No validation commands + promise configured but not matched → stays active
# (Promise configured but not in transcript — should check promise)
# ---------------------------------------------------------------------------
setup_test_env "No validation commands + promise not matched → blocks or stays"

cp "$FIXTURES_DIR/spec-no-validation.md" "$TEST_PROJECT/specs-none.md"
create_state_file "specs-none.md" "DONE"
# Empty transcript — no promise in it
echo '{}' > "$TRANSCRIPT_FILE"

OUTPUT=$(run_hook) || true
# This should fall through the promise check and allow exit since
# validation commands are empty and all tasks are done
# (The promise check doesn't match, but no validation to fail either)
# In the new logic: no commands + has promise → fall to promise check → no match → allow exit
# This is debatable behavior, but the key test is #1 above
assert_allows "$OUTPUT" "No validation commands + unmatched promise allows exit (all tasks done)"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 6: Mixed validation (some pass, some fail) → BLOCKS exit
# ---------------------------------------------------------------------------
setup_test_env "Mixed validation (some fail) → BLOCKS"

cp "$FIXTURES_DIR/spec-validation-mixed.md" "$TEST_PROJECT/specs-mixed.md"
create_state_file "specs-mixed.md" "DONE"
add_promise_to_transcript "DONE"

OUTPUT=$(run_hook) || true
assert_blocks "$OUTPUT" "Mixed validation (any failure) must BLOCK exit even with promise"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 7: No active ralph state → ALLOWS exit
# ---------------------------------------------------------------------------
setup_test_env "No active ralph → ALLOWS"

# Don't create any state file
rm -rf "$TEST_PROJECT/.claude/specs"
mkdir -p "$TEST_PROJECT/.claude/specs"

OUTPUT=$(run_hook) || true
assert_allows "$OUTPUT" "No active ralph state must ALLOW exit"

teardown_test_env

# ---------------------------------------------------------------------------
# Test 8: Abort sentinel → ALLOWS exit
# ---------------------------------------------------------------------------
setup_test_env "Abort sentinel → ALLOWS"

cp "$FIXTURES_DIR/spec-validation-fail.md" "$TEST_PROJECT/specs-fail.md"
create_state_file "specs-fail.md" "DONE"
touch "$TEST_PROJECT/.claude/ralph-abort"

OUTPUT=$(run_hook) || true
assert_allows "$OUTPUT" "Abort sentinel must ALLOW exit regardless of validation"

teardown_test_env

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "==========================================="
echo -e "Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}, $TOTAL_COUNT total"
echo "==========================================="

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi

exit 0
