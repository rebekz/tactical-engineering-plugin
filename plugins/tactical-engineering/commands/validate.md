---
name: validate
description: Run validation commands and check acceptance criteria for a completed plan. Use after build completes.
argument-hint: [path-to-plan]
model: opus
allowed-tools: Task, TaskOutput, Bash, Read, Edit, Write
---

# Validate

Run validation commands and verify acceptance criteria for a completed implementation plan.

## Variables

- `PATH_TO_PLAN`: $1 - Path to the plan file to validate against

## Instructions

### Prerequisites

- If no `PATH_TO_PLAN` is provided, STOP and ask the user to provide it
- The build should be complete before running validation

### MANDATORY EXECUTION RULES

These rules are NON-NEGOTIABLE. Violating any rule invalidates the entire validation.

1. **Every validation command MUST be executed using the Bash tool.** You MUST invoke the Bash tool for each command individually. You may NOT claim a command passed without a corresponding Bash tool call in this conversation.

2. **Capture and report the exit code.** After each Bash tool call, note the actual exit code returned. Exit code 0 = pass. Any non-zero exit code = failure.

3. **Show raw output.** Include the actual stdout/stderr from each command (truncated to 50 lines if very long). Do NOT paraphrase or summarize command output — show what the tool returned.

4. **If a command is NOT run, it counts as FAILED.** If you skip a command for any reason (timeout, tool unavailable, decided to skip, etc.), mark it as FAILED with reason "NOT EXECUTED".

5. **Zero validation commands = FAILED.** If the spec has no "Validation Commands" section, or the section is empty, the overall status MUST be FAILED with the note: "No validation commands defined in spec."

6. **Do NOT infer success.** Do not assume a test passes because the code "looks correct" or because a previous build step succeeded. Only actual Bash tool execution with exit code 0 counts as evidence of passing.

7. **Do NOT summarize without running.** You may not write a validation report without first running every command. The report comes AFTER execution, not instead of it.

### Validation Process

1. **Read the Plan** - Read `PATH_TO_PLAN` to extract:
   - Validation Commands from "Validation Commands" section
   - Acceptance Criteria from "Acceptance Criteria" section

2. **Count commands** - If zero commands found, STOP and report FAILED immediately.

3. **Run Validation Commands** - Execute EACH command individually using the Bash tool:
   ```typescript
   // For EACH validation command extracted from the spec:
   const result = Bash({ command: "<validation command>" })
   // Record: command text, exit code, stdout, stderr
   // Exit code 0 = PASS, anything else = FAIL
   ```

4. **Check Results** - Tally pass/fail counts from actual exit codes.

5. **Verify Acceptance Criteria** - For each criterion:
   - Functional Requirements (F1, F2, etc.) - Verify feature works
   - Non-Functional Requirements (NF1, NF2, etc.) - Measure performance
   - Quality Gates - Check tests, linting, etc.

6. **Apply Status Determination Rules** (see below)

7. **Report Results** - Provide detailed validation report with machine-readable summary

### Status Determination Rules

Apply these rules IN ORDER. The FIRST matching rule determines the status:

1. **If ANY validation command was not executed via Bash tool → FAILED**
2. **If ANY validation command exited with non-zero code → FAILED**
3. **If ALL commands exited with code 0, but some acceptance criteria require manual verification (⏳ items) → PARTIAL**
4. **If ALL commands exited with code 0 AND ALL acceptance criteria are verified → PASSED**

There is NO "partial" for command failures. Any command failure = FAILED, period.

## Output Format

```
Validation Report

Plan: specs/<plan-name>.md

Validation Commands:
✅ <command 1> (exit code: 0)
✅ <command 2> (exit code: 0)
❌ <command 3> (exit code: 1) - <error output>

Acceptance Criteria:
Functional Requirements:
✅ F1: <requirement>
✅ F2: <requirement>
⏳ F3: <requirement> (requires manual verification)

Non-Functional Requirements:
✅ NF1: <requirement> (measured: <value>)
❌ NF2: <requirement> (measured: <value>, target: <target>)

Quality Gates:
✅ Unit tests pass
✅ Integration tests pass
✅ No TypeScript errors
❌ Linting issues found

Overall Status: <PASSED|FAILED|PARTIAL>

Issues:
- <list of issues found>
```

### Machine-Readable Summary

At the END of your validation report, you MUST include this exact HTML comment block with actual counts from your Bash tool executions:

```
<!-- VALIDATION_SUMMARY
commands_total: <number of commands in spec>
commands_executed: <number actually run via Bash tool>
commands_passed: <number with exit code 0>
commands_failed: <number with non-zero exit code>
criteria_passed: <number>
criteria_failed: <number>
criteria_manual: <number>
status: <PASSED|FAILED|PARTIAL>
-->
```

This block is parsed by downstream automation (get-it-done, ralph loop). Do NOT omit it. Do NOT modify the format. The counts MUST match your actual Bash tool executions.

## Workflow

1. Read the plan file
2. Extract validation commands
3. If zero commands → report FAILED immediately
4. Run EACH validation command via Bash tool (one at a time)
5. Record exit codes and output for each
6. Check each acceptance criterion
7. Apply status determination rules
8. Compile results into report with machine-readable summary

## Error Handling

If a validation command fails:
1. Capture the full error output (stderr and stdout)
2. Mark the command as FAILED — there is no "warning" severity for commands
3. Continue with remaining validation commands — run ALL of them even if some fail
4. The Overall Status MUST be FAILED if any command failed

## Manual Verification

Some criteria may require manual verification (e.g., "UI looks good", "User can understand flow").

Mark these with ⏳ and provide instructions for manual verification:

```
⏳ F3: User can navigate intuitively
   Manual verification required:
   - Open the application
   - Try to complete the user flow
   - Confirm navigation is intuitive
```

Manual verification items alone do NOT cause FAILED status — they cause PARTIAL (only if all commands passed).

## Examples

```bash
# Validate a completed build
/validate specs/conversational-ui-revamp.md

# Validate with detailed output
/validate specs/conversational-ui-revamp.md --verbose
```

## Notes

- Some validations may require the application to be running
- Performance tests may require specific load conditions
- Security scans may require additional tools
