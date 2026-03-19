---
name: compound_refresh
description: Review and refresh docs/solutions/ learnings against the current codebase. Identifies stale, drifted, or obsolete knowledge.
argument-hint: [--auto]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion, Skill
---

# Compound Refresh

Review and refresh knowledge in `docs/solutions/` to keep learnings accurate and useful over time.

## Variables

- `ARGUMENTS`: $1..N - All arguments passed to the command
- `AUTO_MODE`: Detected from `--auto` in arguments (skip user confirmations)

## Instructions

### Step 1: Scan Knowledge Base

Scan `docs/solutions/` for all `.md` files. If the directory doesn't exist or is empty, report "No solutions found to refresh" and exit.

```typescript
const solutionFiles = Glob({ pattern: "docs/solutions/**/*.md" })

if (solutionFiles.length === 0) {
  console.log("No solutions found in docs/solutions/. Nothing to refresh.")
  return
}

console.log(`Found ${solutionFiles.length} solution files to review.`)
```

### Step 2: Assess Each Solution

For each solution file:

1. **Read the solution** — understand what pattern, fix, or decision it documents
2. **Check referenced code** — verify that file paths, function names, and patterns mentioned in the solution still exist in the codebase
3. **Classify drift** using this model:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **Keep** | Referenced code unchanged, advice still accurate | No action needed |
| **Update** | Code has evolved but core insight still valid | Update file paths, code examples, and details |
| **Replace** | Pattern has been superseded by a better approach | Rewrite with current best practice |
| **Archive** | Feature removed, technology replaced, or advice no longer relevant | Move to `docs/solutions/_archived/` |

```typescript
// For each file, grep for key references
for (const file of solutionFiles) {
  const content = Read({ file_path: file })

  // Extract code references (file paths, function names, class names)
  // Check if they still exist in the codebase
  // Classify based on findings
}
```

### Step 3: Present Classification

Show the user a summary of all classifications:

```
Compound Refresh Assessment

docs/solutions/
├── auth/session-token-fix.md        → Keep (code unchanged)
├── auth/oauth-retry-pattern.md      → Update (file paths moved)
├── performance/n-plus-one-fix.md    → Replace (new ORM pattern)
└── deployment/docker-config.md      → Archive (switched to K8s)

Actions: 1 update, 1 replace, 1 archive
```

If `--auto` flag is set, proceed automatically. Otherwise:

```typescript
AskUserQuestion({
  questions: [{
    question: "Proceed with these changes?",
    header: "Compound Refresh",
    options: [
      { label: "Apply all", description: "Execute all classified changes" },
      { label: "Review each", description: "Confirm each change individually" },
      { label: "Cancel", description: "Exit without changes" }
    ],
    multiSelect: false
  }]
})
```

### Step 4: Execute Changes

For each approved change:

- **Update:** Edit the file with corrected references, paths, and examples
- **Replace:** Rewrite the file preserving the original title and category
- **Archive:** Move to `docs/solutions/_archived/` with a note about why

```bash
# Create archive directory if needed
mkdir -p docs/solutions/_archived
```

### Step 5: Refresh Derived Documents (Optional)

After updating solutions, check if derived documents need updates:

1. **CLAUDE.md** — If any archived or replaced solutions were referenced in patterns
2. **docs/planning-patterns.md** — If planning patterns reference updated solutions

Only update derived documents if solutions they reference have changed.

### Step 6: Report

```
Compound Refresh Complete!

Updated: N files
Replaced: N files
Archived: N files
Unchanged: N files

Derived docs refreshed: [list or "none"]
```

## Key Instructions

- Never delete solution files — archive them instead
- Preserve the original insight even when updating details
- When replacing, explain what changed and why the new approach is better
- In auto mode, still report what was changed (just skip confirmations)
