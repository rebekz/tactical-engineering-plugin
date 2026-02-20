---
category: state-management
component: state-file
tags: [state-management, checksum, enoent, file-system, validation, node, spec-file]
date_resolved: 2026-02-20
related_build: native-ralph-loop-integration
related_tasks: [state-schema-extension, validation-commands]
---

# State File Checksum Fails with ENOENT on Non-Existent Spec File

## Problem Symptom

Calling `createInitialState('specs/test.md', [...])` with `ralphOptions` threw an unhandled `ENOENT` error because the spec file `specs/test.md` does not exist on disk.

This was discovered when running the validation command from the spec:

```bash
node -e "const s = require('./plugins/tactical-engineering/scripts/state-file.js'); \
  const state = s.createInitialState('specs/test.md', [{id:'1',subject:'test',description:'test'}], \
  'subagent', {ralph:{maxIterations:5}}); \
  console.log(JSON.stringify(state.ralph, null, 2)); \
  process.exit(state.ralph ? 0 : 1)"
```

**Error:** `Error: Failed to calculate checksum for specs/test.md: ENOENT: no such file or directory, open 'specs/test.md'`

**Impact:** The validation command in the spec itself was not executable, making it impossible to verify the ralph state schema extension was working correctly. This created a false test failure during the build.

## Investigation Steps

1. **Ran validation command** - The first validation command in the spec's "Validation Commands" section failed immediately with an ENOENT error.
2. **Traced the error** - The stack trace pointed to `calculateChecksum()` in `state-file.js` at line 48, which calls `fs.readFileSync(specPath, 'utf8')`.
3. **Analyzed createInitialState flow** - At line 186, `createInitialState` calls `calculateChecksum(specPath)`. It has a try/catch block (lines 185-189) but only suppresses the error when `mode === 'party'`. For all other modes (including `'subagent'`), the ENOENT error propagates.
4. **Identified the mismatch** - The validation command used `specs/test.md` as a dummy path, but this file does not exist. The function requires a real file for non-party modes because it needs to compute the SHA256 checksum of the spec contents.

## Root Cause

`calculateChecksum()` in `scripts/state-file.js` reads the spec file synchronously with `fs.readFileSync()` and throws if the file is missing:

```javascript
// state-file.js line 46-54
function calculateChecksum(specPath) {
  try {
    const content = fs.readFileSync(specPath, 'utf8');
    const hash = crypto.createHash('sha256').update(content).digest('hex');
    return `sha256:${hash}`;
  } catch (error) {
    throw new Error(`Failed to calculate checksum for ${specPath}: ${error.message}`);
  }
}
```

`createInitialState()` (line 180) calls this function and only catches the error for `mode === 'party'`:

```javascript
// state-file.js lines 184-189
let checksum = null;
try {
  checksum = calculateChecksum(specPath);
} catch (e) {
  if (mode !== 'party') throw e;  // Only party mode tolerates missing specs
  // Party mode: spec doesn't exist yet, checksum set later
}
```

The validation command passed `mode = 'subagent'` with a non-existent file path, triggering the throw. This is working as designed -- the function correctly requires a real spec file for non-party builds -- but the validation command was testing with an invalid input.

## Working Solution

**Fix the validation command to use a real spec file:**

```bash
# Before (broken -- specs/test.md does not exist)
node -e "const s = require('./plugins/tactical-engineering/scripts/state-file.js'); \
  const state = s.createInitialState('specs/test.md', \
  [{id:'1',subject:'test',description:'test'}], \
  'subagent', null, {maxIterations:5}); \
  console.log(JSON.stringify(state.ralph, null, 2)); \
  process.exit(state.ralph ? 0 : 1)"

# After -- Option A: use an actual spec file that exists in the repo
node -e "const s = require('./plugins/tactical-engineering/scripts/state-file.js'); \
  const state = s.createInitialState('specs/native-ralph-loop-integration.md', \
  [{id:'1',subject:'test',description:'test'}], \
  'subagent', null, {maxIterations:5}); \
  console.log(JSON.stringify(state.ralph, null, 2)); \
  process.exit(state.ralph ? 0 : 1)"

# After -- Option B: use party mode which skips checksum
node -e "const s = require('./plugins/tactical-engineering/scripts/state-file.js'); \
  const state = s.createInitialState('specs/test.md', \
  [{id:'1',subject:'test',description:'test'}], \
  'party', null, {maxIterations:5}); \
  console.log(JSON.stringify(state.ralph, null, 2)); \
  process.exit(state.ralph ? 0 : 1)"
```

Note also the function signature correction: `ralphOptions` is the **fifth** parameter (after `partyOptions`), not the fourth. The original validation command in the spec passed ralph options as the fourth argument, which would have been interpreted as `partyOptions`.

```javascript
// Correct signature:
createInitialState(specPath, tasks, mode, partyOptions, ralphOptions)

// Spec's original validation command passed ralph options as partyOptions (4th arg):
createInitialState('specs/test.md', [...], 'subagent', {ralph:{maxIterations:5}})
//                                                      ^^^^^^^^^^^^^^^^^^^^^^^^
//                                                      This is partyOptions, not ralphOptions!

// Correct call:
createInitialState('specs/test.md', [...], 'subagent', null, {maxIterations:5})
//                                                     ^^^^  ^^^^^^^^^^^^^^^^^
//                                                     partyOptions=null, ralphOptions
```

**Result:** Validation command executes successfully and correctly outputs the ralph state schema with `active: true`, `maxIterations: 5`, and all expected fields.

## Prevention Strategies

1. **Always use existing files in validation commands** - When writing validation commands in specs, reference real files that exist in the repository (e.g., the spec file itself). Never use placeholder paths like `specs/test.md`.
2. **Verify function signatures before writing test calls** - Check the actual parameter order in the source code. `createInitialState` has 5 parameters; confusing positional arguments (especially optional ones like `partyOptions` and `ralphOptions`) leads to silent misrouting of data.
3. **Test validation commands before marking spec as ready** - Run each validation command manually before committing the spec. This catches file-not-found and argument-ordering issues early.
4. **Consider adding a ralph mode to the checksum bypass** - For future robustness, `createInitialState` could also bypass checksum for `mode === 'ralph-test'` or accept an explicit `skipChecksum` option. This would make isolated testing easier. (Not implemented in V1 -- out of scope.)
5. **Document optional parameter conventions** - When functions have multiple optional parameters (like `partyOptions` and `ralphOptions`), document that callers must pass `null` for unused optional parameters to maintain positional correctness.

## Test Cases Added

```bash
# Verify ralph state schema with a real spec file
node -e "
  const s = require('./plugins/tactical-engineering/scripts/state-file.js');
  const state = s.createInitialState(
    'specs/native-ralph-loop-integration.md',
    [{id:'1', subject:'test', description:'test'}],
    'subagent',
    null,
    {maxIterations: 5}
  );
  if (!state.ralph) { console.error('ralph state missing'); process.exit(1); }
  if (state.ralph.maxIterations !== 5) { console.error('maxIterations wrong'); process.exit(1); }
  if (state.ralph.active !== true) { console.error('active should be true'); process.exit(1); }
  if (state.ralph.status !== 'active') { console.error('status should be active'); process.exit(1); }
  console.log(JSON.stringify(state.ralph, null, 2));
  console.log('Ralph state schema validated successfully');
"

# Verify party mode tolerates missing spec
node -e "
  const s = require('./plugins/tactical-engineering/scripts/state-file.js');
  const state = s.createInitialState(
    'specs/does-not-exist.md',
    [{id:'1', subject:'test', description:'test'}],
    'party',
    null,
    {maxIterations: 3}
  );
  if (!state.ralph) { console.error('ralph state missing in party mode'); process.exit(1); }
  if (state.build.specChecksum !== null) { console.error('checksum should be null for missing spec'); process.exit(1); }
  console.log('Party mode with missing spec: OK');
"
```

## Cross-References

- Source file: `plugins/tactical-engineering/scripts/state-file.js` (lines 46-54 for `calculateChecksum`, lines 180-189 for checksum bypass logic)
- Ralph state creation: `plugins/tactical-engineering/scripts/ralph-loop.js` (`createRalphState` function)
- Spec file: `specs/native-ralph-loop-integration.md` (Validation Commands section)
- Related solution: `docs/solutions/shell-escaping/zsh-history-expansion-in-node-one-liners.md` (same validation commands affected by both issues)
