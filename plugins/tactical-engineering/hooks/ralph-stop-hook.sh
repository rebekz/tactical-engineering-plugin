#!/bin/bash

# Ralph Loop Stop Hook (Tactical Engineering)
# Intercepts Claude's exit attempts and decides whether to continue iterating.
#
# Contract:
#   stdin:  { "transcript_path": "/path/to/transcript.jsonl" }
#   stdout: { "decision": "block", "reason": "...", "systemMessage": "..." }  to BLOCK exit
#   stdout: (empty) + exit 0  to ALLOW exit

set -e

# ---------------------------------------------------------------------------
# 1. Read hook input from stdin
# ---------------------------------------------------------------------------
HOOK_INPUT=$(cat)

# ---------------------------------------------------------------------------
# 2. Extract transcript_path from the JSON input
# ---------------------------------------------------------------------------
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try { console.log(JSON.parse(d).transcript_path || ''); }
    catch(e) { console.log(''); }
  });
" 2>/dev/null || echo "")

# ---------------------------------------------------------------------------
# 3. Determine plugin root and project root
# ---------------------------------------------------------------------------
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="$(pwd)"

# ---------------------------------------------------------------------------
# 4. Find active ralph state
#    Scan $PROJECT_ROOT/.claude/specs/*/state.json for ralph.active === true.
#    Exports SPEC_PATH (the build.specPath from the state) and STATE_DIR.
# ---------------------------------------------------------------------------
ACTIVE_STATE=$(node -e "
  const fs = require('fs');
  const path = require('path');
  const glob = path.join('${PROJECT_ROOT}', '.claude', 'specs', '*', 'state.json');
  const specsDir = path.join('${PROJECT_ROOT}', '.claude', 'specs');

  if (!fs.existsSync(specsDir)) { process.exit(0); }

  const dirs = fs.readdirSync(specsDir, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  for (const dir of dirs) {
    const stateFile = path.join(specsDir, dir, 'state.json');
    if (!fs.existsSync(stateFile)) continue;
    try {
      const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      if (state.ralph && state.ralph.active === true) {
        // Output specPath and stateFile separated by newline
        console.log(state.build.specPath);
        console.log(stateFile);
        process.exit(0);
      }
    } catch(e) { /* skip corrupted files */ }
  }
  // No active ralph found — output nothing
" 2>/dev/null || echo "")

if [[ -z "$ACTIVE_STATE" ]]; then
  # No active ralph loop — allow normal exit
  exit 0
fi

# Parse the two-line output
SPEC_PATH=$(echo "$ACTIVE_STATE" | head -1)
STATE_FILE=$(echo "$ACTIVE_STATE" | tail -1)

if [[ -z "$SPEC_PATH" ]] || [[ -z "$STATE_FILE" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. Check abort sentinel
# ---------------------------------------------------------------------------
ABORT_FILE="${PROJECT_ROOT}/.claude/ralph-abort"
if [[ -f "$ABORT_FILE" ]]; then
  rm -f "$ABORT_FILE"
  node -e "
    const { readStateFile, writeStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
    const state = readStateFile('${SPEC_PATH}');
    if (state && state.ralph) {
      state.ralph.status = 'aborted';
      state.ralph.active = false;
      writeStateFile('${SPEC_PATH}', state);
    }
  " 2>/dev/null || echo "Ralph stop-hook: failed to update abort state" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# 6. Read current state via node (single source of truth)
# ---------------------------------------------------------------------------
STATE_JSON=$(node -e "
  const { readStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
  const state = readStateFile('${SPEC_PATH}');
  if (!state) { process.exit(1); }
  console.log(JSON.stringify(state));
" 2>/dev/null) || { echo "Ralph stop-hook: failed to read state file" >&2; exit 0; }

# ---------------------------------------------------------------------------
# 7. Check max iterations
# ---------------------------------------------------------------------------
MAX_REACHED=$(node -e "
  const state = JSON.parse(process.argv[1]);
  const r = state.ralph;
  if (r.currentIteration >= r.maxIterations) {
    console.log('true');
  } else {
    console.log('false');
  }
" "$STATE_JSON" 2>/dev/null || echo "false")

if [[ "$MAX_REACHED" == "true" ]]; then
  node -e "
    const { readStateFile, writeStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
    const { generateFailureReport, writeFailureReport } = require('${PLUGIN_ROOT}/scripts/ralph-loop');
    const state = readStateFile('${SPEC_PATH}');
    if (state && state.ralph) {
      state.ralph.status = 'failed';
      state.ralph.active = false;
      writeStateFile('${SPEC_PATH}', state);
      const report = generateFailureReport(state);
      writeFailureReport('${SPEC_PATH}', report);
    }
  " 2>/dev/null || echo "Ralph stop-hook: failed to write failure report" >&2
  echo "Ralph loop: max iterations reached. See ralph-report.md for details." >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# 8. Check completion promise
# ---------------------------------------------------------------------------
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  PROMISE_RESULT=$(node -e "
    const fs = require('fs');
    const state = JSON.parse(process.argv[1]);
    const r = state.ralph;

    if (!r.completionPromise) {
      console.log('no_promise');
      process.exit(0);
    }

    const transcriptPath = process.argv[2];
    // Read last 50 lines of transcript
    const lines = fs.readFileSync(transcriptPath, 'utf8').split('\n').filter(Boolean);
    const tail = lines.slice(-50);

    // Search for <promise>TEXT</promise> in assistant messages
    for (const line of tail) {
      try {
        const entry = JSON.parse(line);
        if (entry.role !== 'assistant' || !entry.message || !entry.message.content) continue;
        const texts = entry.message.content
          .filter(c => c.type === 'text')
          .map(c => c.text)
          .join('\n');

        // Extract promise tags — use a regex that handles multiline
        const match = texts.match(/<promise>([\s\S]*?)<\/promise>/);
        if (match) {
          const promiseText = match[1].trim().replace(/\s+/g, ' ');
          const expected = r.completionPromise.trim().replace(/\s+/g, ' ');
          if (promiseText === expected) {
            console.log('matched');
            process.exit(0);
          }
        }
      } catch(e) { /* skip unparseable lines */ }
    }

    console.log('not_matched');
  " "$STATE_JSON" "$TRANSCRIPT_PATH" 2>/dev/null || echo "no_promise")

  if [[ "$PROMISE_RESULT" == "matched" ]]; then
    node -e "
      const { readStateFile, writeStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
      const state = readStateFile('${SPEC_PATH}');
      if (state && state.ralph) {
        state.ralph.status = 'completed';
        state.ralph.active = false;
        writeStateFile('${SPEC_PATH}', state);
      }
    " 2>/dev/null || echo "Ralph stop-hook: failed to update completion state" >&2
    echo "Ralph loop: completion promise matched. Loop finished." >&2
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 9. Lightweight task check — should we skip full validation?
# ---------------------------------------------------------------------------
TASK_CHECK=$(node -e "
  const { shouldRunFullValidation } = require('${PLUGIN_ROOT}/scripts/ralph-loop');
  const state = JSON.parse(process.argv[1]);
  const result = shouldRunFullValidation(state);
  console.log(result ? 'run_validation' : 'tasks_pending');
" "$STATE_JSON" 2>/dev/null || echo "tasks_pending")

ITERATION_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$TASK_CHECK" == "tasks_pending" ]]; then
  # Tasks still pending/failed — continue without full validation
  BLOCK_JSON=$(node -e "
    const { updateRalphIteration } = require('${PLUGIN_ROOT}/scripts/ralph-loop');
    const state = JSON.parse(process.argv[1]);
    const r = state.ralph;
    const nextIter = r.currentIteration + 1;

    // Build list of pending/failed tasks
    const actionable = (state.tasks || [])
      .filter(t => t.status === 'pending' || t.status === 'failed' || t.status === 'in-progress')
      .map(t => t.subject || t.id);
    const taskList = actionable.join(', ') || 'check task list';

    // Record iteration
    try {
      updateRalphIteration('${SPEC_PATH}', {
        startedAt: '${ITERATION_START}',
        completedAt: new Date().toISOString(),
        tasksCompleted: 0,
        tasksFailed: [],
        tasksStuck: [],
        validationResult: 'skipped',
        validationSummary: 'Tasks still pending — skipped validation'
      });
    } catch(e) { process.stderr.write('Ralph stop-hook: failed to update iteration: ' + e.message + '\n'); }

    // Re-read state to get updated iteration count
    const { readStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
    const updated = readStateFile('${SPEC_PATH}');
    const currentIter = updated ? updated.ralph.currentIteration : nextIter;
    const maxIter = updated ? updated.ralph.maxIterations : r.maxIterations;

    const output = {
      decision: 'block',
      reason: 'Continue building. Focus on pending/failed tasks: ' + taskList + '. Run /status for progress.',
      systemMessage: 'Ralph Loop — Iteration ' + currentIter + '/' + maxIter
    };

    console.log(JSON.stringify(output));
  " "$STATE_JSON" 2>/dev/null) || { echo "Ralph stop-hook: failed to build block response" >&2; exit 0; }

  echo "$BLOCK_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# 10. Full validation — all tasks in terminal state
# ---------------------------------------------------------------------------
# Extract "Validation Commands" section from the spec file
VALIDATION_CMDS=$(node -e "
  const fs = require('fs');
  const specPath = '${SPEC_PATH}';

  // Try relative to project root first, then absolute
  let fullPath = specPath;
  if (!fs.existsSync(fullPath)) {
    fullPath = require('path').join('${PROJECT_ROOT}', specPath);
  }
  if (!fs.existsSync(fullPath)) {
    console.log('');
    process.exit(0);
  }

  const content = fs.readFileSync(fullPath, 'utf8');

  // Look for ## Validation Commands or ## Validation section
  const match = content.match(/##\s*Validation\s*Commands?\s*\n([\s\S]*?)(?=\n##\s|\n---|\$)/i);
  if (!match) {
    console.log('');
    process.exit(0);
  }

  // Extract code blocks or backtick commands
  const section = match[1];
  const commands = [];

  // Match fenced code blocks
  const codeBlocks = section.match(/\x60\x60\x60(?:bash|sh|shell)?\n([\s\S]*?)\x60\x60\x60/g);
  if (codeBlocks) {
    for (const block of codeBlocks) {
      const inner = block.replace(/\x60\x60\x60(?:bash|sh|shell)?\n/, '').replace(/\x60\x60\x60/, '').trim();
      inner.split('\n').forEach(line => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#')) commands.push(trimmed);
      });
    }
  }

  // Match inline backtick commands (- \`command\`)
  const inlineMatches = section.matchAll(/[-*]\s*\x60([^\x60]+)\x60/g);
  for (const m of inlineMatches) {
    const cmd = m[1].trim();
    if (cmd && !commands.includes(cmd)) commands.push(cmd);
  }

  console.log(JSON.stringify(commands));
" 2>/dev/null || echo "[]")

# If no validation commands found, treat as pass (all tasks completed)
if [[ "$VALIDATION_CMDS" == "[]" ]] || [[ -z "$VALIDATION_CMDS" ]]; then
  # No validation commands — tasks are all done, mark completed
  node -e "
    const { readStateFile, writeStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');
    const state = readStateFile('${SPEC_PATH}');
    if (state && state.ralph) {
      state.ralph.status = 'completed';
      state.ralph.active = false;
      writeStateFile('${SPEC_PATH}', state);
    }
  " 2>/dev/null || echo "Ralph stop-hook: failed to update completion state" >&2
  echo "Ralph loop: all tasks completed (no validation commands to run). Loop finished." >&2
  exit 0
fi

# Run each validation command with a 30s timeout
VALIDATION_PASS=true
VALIDATION_FAILURES=""

CMD_COUNT=$(echo "$VALIDATION_CMDS" | node -e "
  let d=''; process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{ try{console.log(JSON.parse(d).length)}catch(e){console.log(0)} });
" 2>/dev/null || echo "0")

for i in $(seq 0 $((CMD_COUNT - 1))); do
  CMD=$(echo "$VALIDATION_CMDS" | node -e "
    let d=''; process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{ try{console.log(JSON.parse(d)[$i])}catch(e){console.log('')} });
  " 2>/dev/null || echo "")

  if [[ -z "$CMD" ]]; then
    continue
  fi

  # Execute with 30s timeout
  CMD_OUTPUT=""
  CMD_EXIT=0
  CMD_OUTPUT=$(cd "$PROJECT_ROOT" && timeout 30 bash -c "$CMD" 2>&1) || CMD_EXIT=$?

  if [[ $CMD_EXIT -ne 0 ]]; then
    VALIDATION_PASS=false
    if [[ -n "$VALIDATION_FAILURES" ]]; then
      VALIDATION_FAILURES="${VALIDATION_FAILURES}; "
    fi
    # Truncate output to avoid overly long messages
    TRUNCATED_OUTPUT=$(echo "$CMD_OUTPUT" | tail -5 | head -c 500)
    VALIDATION_FAILURES="${VALIDATION_FAILURES}Command '${CMD}' failed (exit ${CMD_EXIT}): ${TRUNCATED_OUTPUT}"
  fi
done

# ---------------------------------------------------------------------------
# 11. Handle validation results
# ---------------------------------------------------------------------------
ITERATION_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$VALIDATION_PASS" == "true" ]]; then
  # All validation commands passed — success!
  node -e "
    const { updateRalphIteration } = require('${PLUGIN_ROOT}/scripts/ralph-loop');
    const { readStateFile, writeStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');

    try {
      updateRalphIteration('${SPEC_PATH}', {
        startedAt: '${ITERATION_START}',
        completedAt: '${ITERATION_END}',
        tasksCompleted: 0,
        tasksFailed: [],
        tasksStuck: [],
        validationResult: 'pass',
        validationSummary: 'All validation commands passed'
      });
    } catch(e) { process.stderr.write('Ralph stop-hook: iteration update failed: ' + e.message + '\n'); }

    const state = readStateFile('${SPEC_PATH}');
    if (state && state.ralph) {
      state.ralph.status = 'completed';
      state.ralph.active = false;
      state.ralph.finalResult = 'All tasks completed and validation passed';
      writeStateFile('${SPEC_PATH}', state);
    }
  " 2>/dev/null || echo "Ralph stop-hook: failed to update completion state" >&2
  echo "Ralph loop: all validation commands passed. Loop finished successfully." >&2
  exit 0
else
  # Validation failed — block exit and continue iterating
  BLOCK_JSON=$(node -e "
    const { updateRalphIteration } = require('${PLUGIN_ROOT}/scripts/ralph-loop');
    const { readStateFile } = require('${PLUGIN_ROOT}/scripts/state-file');

    const failures = process.argv[1];

    try {
      updateRalphIteration('${SPEC_PATH}', {
        startedAt: '${ITERATION_START}',
        completedAt: '${ITERATION_END}',
        tasksCompleted: 0,
        tasksFailed: [],
        tasksStuck: [],
        validationResult: 'fail',
        validationSummary: failures
      });
    } catch(e) { process.stderr.write('Ralph stop-hook: iteration update failed: ' + e.message + '\n'); }

    const state = readStateFile('${SPEC_PATH}');
    const r = state ? state.ralph : null;
    const currentIter = r ? r.currentIteration : '?';
    const maxIter = r ? r.maxIterations : '?';

    const output = {
      decision: 'block',
      reason: 'Validation failed. Fix these issues and re-validate: ' + failures + '. Run /status for progress.',
      systemMessage: 'Ralph Loop — Iteration ' + currentIter + '/' + maxIter + ' (validation failed)'
    };

    console.log(JSON.stringify(output));
  " "$VALIDATION_FAILURES" 2>/dev/null) || { echo "Ralph stop-hook: failed to build block response" >&2; exit 0; }

  echo "$BLOCK_JSON"
  exit 0
fi
