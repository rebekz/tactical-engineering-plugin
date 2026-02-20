---
category: shell-escaping
component: ralph-stop-hook
tags: [shell-escaping, zsh, node, history-expansion, validation, bash, operator]
date_resolved: 2026-02-20
related_build: native-ralph-loop-integration
related_tasks: [ralph-stop-hook, validation-commands]
---

# Zsh History Expansion Breaks node -e with !== Operator

## Problem Symptom

Multiple `node -e` validation commands failed with cryptic "Expected unicode escape" errors or unexpected token errors when run from zsh.

Commands like this would fail silently or produce corrupted output:

```bash
node -e "if(state.status !== 'complete') process.exit(1)"
```

**Error:** `SyntaxError: Expected unicode escape sequence` or `event not found: ==`

**Impact:** Validation commands in the spec's "Validation Commands" section could not be executed by the ralph stop hook, causing the iteration loop to either skip validation or produce false failures. This blocked automated build-validate cycling.

## Investigation Steps

1. **Observed failures** - Validation commands embedded in `node -e` strings returned unexpected errors during ralph loop iterations. The errors did not clearly point to the `!` character.
2. **Isolated the pattern** - Narrowed down to commands containing the `!==` operator. Commands using only `===` worked correctly.
3. **Tested in zsh vs bash** - Confirmed the issue only manifests in zsh. Running the same `node -e` command in bash worked fine.
4. **Identified history expansion** - zsh interprets `!` as a history expansion trigger, even inside double-quoted strings. The sequence `!==` gets rewritten by zsh before Node.js ever sees it, producing garbled JavaScript.

## Root Cause

Zsh performs **history expansion** on the `!` character in both double-quoted and, in some contexts, single-quoted strings passed to `node -e`. The `!==` strict inequality operator in JavaScript triggers this behavior:

```bash
# What the developer writes:
node -e "if(x !== y) process.exit(1)"

# What zsh sends to node after history expansion:
# The !== gets mangled because zsh tries to expand !==
# Result: SyntaxError or "event not found"
```

This affects any shell-embedded JavaScript that uses `!==`, `!=`, or `!` followed by alphanumeric characters. The ralph stop hook (`hooks/ralph-stop-hook.sh`) runs in the user's default shell, which on macOS is zsh by default.

The root file affected: `plugins/tactical-engineering/hooks/ralph-stop-hook.sh`

## Working Solution

**Option A (preferred): Use heredoc syntax for multi-line node scripts**

Heredocs with single-quoted delimiters suppress all shell interpretation:

```bash
# Before (broken in zsh)
node -e "const s = JSON.parse(process.argv[1]); if(s.status !== 'complete') process.exit(1);" "$STATE_JSON"

# After (works in all shells)
node << 'SCRIPT'
const fs = require('fs');
const state = JSON.parse(require('fs').readFileSync('/dev/stdin', 'utf8'));
if (state.status !== 'complete') {
  process.exit(1);
}
process.exit(0);
SCRIPT
```

**Option B: Invert logic to avoid !== entirely**

```bash
# Before (broken)
node -e 'if (status !== "complete") process.exit(1);'

# After (safe — uses === with inverted control flow)
node -e 'if (status === "complete") process.exit(0); process.exit(1);'
```

**Option C: Pipe JSON via stdin instead of process.argv**

```bash
# Avoids complex quoting by using stdin
echo "$STATE_JSON" | node -e "
  let d='';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    const s = JSON.parse(d);
    if (s.status === 'complete') process.exit(0);
    process.exit(1);
  });
"
```

**Result:** All validation commands in the ralph stop hook now execute correctly across both bash and zsh environments. The hook was rewritten to use heredoc syntax for complex JavaScript and stdin piping for JSON parsing (visible throughout `ralph-stop-hook.sh`).

## Prevention Strategies

1. **Default to heredoc for node scripts** - Any `node -e` invocation containing more than a simple expression should use `node << 'SCRIPT' ... SCRIPT` syntax. The single-quoted delimiter (`'SCRIPT'`) is critical -- it prevents all shell variable expansion and history substitution.
2. **Never use !== in node -e one-liners** - If a one-liner is truly needed, rewrite using `===` with inverted control flow: `if (x === y) { good_path } else { bad_path }`.
3. **Test validation commands in zsh** - Since macOS defaults to zsh, always test shell-embedded node commands in zsh specifically, not just bash.
4. **Add shell escaping note to CLAUDE.md** - Document this pattern in the project's CLAUDE.md so all agents and developers are aware. (Already added under "Shell Escaping in Node Validation" section.)
5. **Lint shell scripts for !==** - Consider adding a grep check in CI: `grep -n '!==' hooks/*.sh` should return zero matches.

## Test Cases Added

The fix was validated by running the actual validation commands from the spec:

```bash
# Test 1: Verify ralph-loop.js exports (uses heredoc for complex check)
node << 'SCRIPT'
const r = require('./plugins/tactical-engineering/scripts/ralph-loop.js');
const required = [
  'createRalphState',
  'updateRalphIteration',
  'getRalphState',
  'isRalphComplete',
  'generateFailureReport',
  'shouldRunFullValidation'
];
for (const f of required) {
  if (!r[f]) {
    console.error(`Missing export: ${f}`);
    process.exit(1);
  }
}
console.log('All exports present');
SCRIPT

# Test 2: Verify hooks.json has Stop entry (uses === not !==)
node -e "
  const h = require('./plugins/tactical-engineering/hooks/hooks.json');
  console.log('PostToolUse:', !!h.hooks.PostToolUse);
  console.log('Stop:', !!h.hooks.Stop);
  process.exit(h.hooks.Stop ? 0 : 1);
"
```

## Cross-References

- Pattern documented in: `plugins/tactical-engineering/CLAUDE.md` (section "Shell Escaping in Node Validation")
- Affected file: `plugins/tactical-engineering/hooks/ralph-stop-hook.sh`
- Related: `plugins/tactical-engineering/hooks/hooks.json` (Stop hook registration)
- Zsh history expansion docs: https://zsh.sourceforge.io/Doc/Release/Expansion.html#History-Expansion
