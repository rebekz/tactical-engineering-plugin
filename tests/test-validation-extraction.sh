#!/bin/bash

# Tests for validation command extraction logic
#
# Verifies that the node -e command extraction (used in ralph-stop-hook.sh)
# correctly parses validation commands from spec files.
#
# Usage: bash tests/test-validation-extraction.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

extract_commands() {
  local spec_path="$1"

  node -e "
    const fs = require('fs');
    const specPath = process.argv[1];

    if (!fs.existsSync(specPath)) {
      console.log('[]');
      process.exit(0);
    }

    const content = fs.readFileSync(specPath, 'utf8');

    const match = content.match(/##\s*Validation\s*Commands?\s*\n([\s\S]*?)(?=\n##\s|\n---|\$)/i);
    if (!match) {
      console.log('[]');
      process.exit(0);
    }

    const section = match[1];
    const commands = [];

    const codeBlocks = section.match(/\x60\x60\x60(?:bash|sh|shell)\n([\s\S]*?)\x60\x60\x60/g);
    if (codeBlocks) {
      for (const block of codeBlocks) {
        const inner = block.replace(/\x60\x60\x60(?:bash|sh|shell)\n/, '').replace(/\x60\x60\x60/, '').trim();
        inner.split('\n').forEach(line => {
          const trimmed = line.trim();
          if (trimmed && !trimmed.startsWith('#')) commands.push(trimmed);
        });
      }
    }

    const inlineMatches = section.matchAll(/[-*]\s*\x60([^\x60]+)\x60/g);
    for (const m of inlineMatches) {
      const cmd = m[1].trim();
      if (cmd && !commands.includes(cmd)) commands.push(cmd);
    }

    console.log(JSON.stringify(commands));
  " "$spec_path" 2>/dev/null || echo "[]"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local test_name="$3"
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if [[ "$actual" == "$expected" ]]; then
    echo -e "  ${GREEN}PASS${NC}: $test_name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo -e "  ${RED}FAIL${NC}: $test_name"
    echo "    Expected: $expected"
    echo "    Got:      $actual"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test 1: Failing spec — should extract the exit 1 command
# ---------------------------------------------------------------------------
echo -e "${YELLOW}--- Test: Extract from spec-validation-fail.md ---${NC}"
RESULT=$(extract_commands "$FIXTURES_DIR/spec-validation-fail.md")
assert_eq "$RESULT" '["echo \"This command will fail\" && exit 1"]' "Extracts failing command"

# ---------------------------------------------------------------------------
# Test 2: Passing spec — should extract the echo command
# ---------------------------------------------------------------------------
echo -e "${YELLOW}--- Test: Extract from spec-validation-pass.md ---${NC}"
RESULT=$(extract_commands "$FIXTURES_DIR/spec-validation-pass.md")
assert_eq "$RESULT" '["echo \"ok\""]' "Extracts passing command"

# ---------------------------------------------------------------------------
# Test 3: No validation section — should return empty
# ---------------------------------------------------------------------------
echo -e "${YELLOW}--- Test: Extract from spec-no-validation.md ---${NC}"
RESULT=$(extract_commands "$FIXTURES_DIR/spec-no-validation.md")
assert_eq "$RESULT" '[]' "Returns empty for spec without validation commands"

# ---------------------------------------------------------------------------
# Test 4: Mixed spec — should extract all 3 commands
# ---------------------------------------------------------------------------
echo -e "${YELLOW}--- Test: Extract from spec-validation-mixed.md ---${NC}"
RESULT=$(extract_commands "$FIXTURES_DIR/spec-validation-mixed.md")
assert_eq "$RESULT" '["echo \"test 1 ok\"","exit 1","echo \"test 3 ok\""]' "Extracts all commands from mixed spec"

# ---------------------------------------------------------------------------
# Test 5: Non-existent file — should return empty
# ---------------------------------------------------------------------------
echo -e "${YELLOW}--- Test: Extract from non-existent file ---${NC}"
RESULT=$(extract_commands "/tmp/does-not-exist.md")
assert_eq "$RESULT" '[]' "Returns empty for non-existent file"

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
