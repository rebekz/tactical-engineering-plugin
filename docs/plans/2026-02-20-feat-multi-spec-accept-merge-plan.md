---
title: "feat: Add multi-spec accept with merge to plan_w_team"
type: feat
status: completed
date: 2026-02-20
---

# feat: Add multi-spec accept with merge to plan_w_team

## Overview

Extend the `/plan_w_team --accept` flag to accept multiple plan documents and merge them into a single unified spec. Currently `--accept` takes exactly one path. This enhancement enables accepting multiple related plan documents (e.g., `backend-plan.md` + `frontend-plan.md` + `api-plan.md`) and producing one cohesive spec file in `specs/`.

## Problem Statement / Motivation

When a feature is planned across multiple documents — common when backend and frontend are planned separately, or when multiple teams contribute partial plans — the user currently has no way to combine them into a single `/build`-compatible spec. They must manually merge documents or accept one and hand-edit the rest in. This is error-prone and tedious.

## Proposed Solution

Add a **multi-doc sub-mode** within the existing Accept Mode. When the `--accept` argument contains comma-separated paths, split into an array, read each document, then use a dedicated merge prompt to produce one unified spec.

**Critical design change from brainstorm:** Use **comma-separated** paths instead of space-separated. The SpecFlow analysis identified that space-separated paths are fundamentally ambiguous — a path like `docs/my plans/auth.md` would be wrongly split into two non-existent paths. Commas are unambiguous since they're not valid in file paths.

### Syntax

```bash
# Single doc (existing, unchanged)
/plan_w_team --accept docs/plans/my-plan.md

# Multiple docs (new — comma-separated)
/plan_w_team --accept docs/plans/backend.md,docs/plans/frontend.md,docs/plans/api.md

# With orchestration prompt
/plan_w_team --accept docs/plans/backend.md,docs/plans/frontend.md "Focus on API-first approach"
```

## Technical Considerations

### Architecture Impact

Changes are isolated to one file: `plugins/tactical-engineering/commands/plan-w-team.md`. No changes to `state-file.js`, `/build`, or other commands.

### Bug Fix: `-a` Regex

The existing regex `/^--accept|-a/` is unanchored for the `-a` alternative. This means any `-a` substring in file paths gets stripped (e.g., `data-analysis.md` becomes `dt-nalysis.md`). Fix to `/^(?:--accept|-a)\s*/` before adding multi-doc support.

### Merge Strategy

AI-powered merge using a dedicated prompt template (not the BMad synthesis prompt). The merge prompt understands plan structure and produces a coherent unified spec with:
- Combined and renumbered tasks (grouped by source, sequential numbering)
- Deduplicated team members
- Merged acceptance criteria
- Unified relevant files list
- Resolved frontmatter conflicts (latest date, combined titles)

### Pre-Merge Validation

Validate the **merged output only**, not each input individually. Input files are checked only for existence and non-emptiness. This matches the BMad precedent where individual documents (PRD, architecture, stories) don't each contain all 7 required sections.

### Filename Generation

Auto-generate from input filenames: strip directory paths, strip `-plan.md`/`.md` suffixes, join with `-`, append `-merged.md`. If result exceeds 80 chars, truncate to first 3 file stems. If file exists in `specs/`, append numeric suffix (`-2`, `-3`).

Example: `docs/plans/backend-api.md` + `docs/plans/frontend-ui.md` -> `specs/backend-api-frontend-ui-merged.md`

### Frontmatter Provenance

Add `merge_sources` array to output frontmatter for traceability:

```yaml
---
title: "Backend API + Frontend UI - Merged Implementation Plan"
type: feat
date: 2026-02-20
merge_sources:
  - docs/plans/backend-api.md
  - docs/plans/frontend-ui.md
---
```

## System-Wide Impact

- **Hooks unchanged**: Stop hooks validate the final `specs/*.md` output — works for merged output since it's a single file
- **Build unchanged**: `/build` reads one spec from `specs/` — merged output is a standard spec file
- **State unchanged**: `state-file.js` keys on `sanitizeSpecName(specPath)` — works with any filename

## Acceptance Criteria

### Functional Requirements

- [x] Single-path `--accept` continues to work identically (backward compatible)
- [x] Comma-separated paths trigger multi-doc merge mode
- [x] Each input file is verified to exist and be non-empty before merge
- [x] Missing files produce a clear error listing all missing paths
- [x] AI merge produces a single spec with all 7 required sections
- [x] Merged output includes `merge_sources` in frontmatter
- [x] Auto-generated filename follows the described algorithm
- [x] Filename collision appends numeric suffix
- [x] `-a` short flag works with comma-separated paths
- [x] Orchestration prompt ($2) is passed to the merge as additional context
- [x] `-a` regex bug is fixed (anchored pattern)

### Documentation Requirements

- [x] COMMANDS.md updated with Accept Mode (single and multi-doc)
- [x] Accept Mode Examples updated in `plan-w-team.md`
- [x] Argument-hint updated in frontmatter

## Step by Step Tasks

### Task 1: Fix `-a` regex bug
**Owner:** builder-backend
**Dependencies:** none

Fix the unanchored regex at `plan-w-team.md:66`. Change:
```typescript
EXISTING_PLAN_PATH = $1.replace(/^--accept|-a/, "").trim()
```
To:
```typescript
EXISTING_PLAN_PATH = $1.replace(/^(?:--accept|-a)/, "").trim()
```

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md:66`

### Task 2: Update argument parsing for multi-path detection
**Owner:** builder-backend
**Dependencies:** Task 1

In the Mode Detection section (`plan-w-team.md:58-72`), after extracting `EXISTING_PLAN_PATH`, add multi-path detection:

```typescript
} else if ($1.startsWith("--accept") || $1.startsWith("-a")) {
  MODE = "accept"
  const rawPath = $1.replace(/^(?:--accept|-a)/, "").trim()
  if (rawPath.includes(",")) {
    ACCEPT_MODE = "multi"
    EXISTING_PLAN_PATHS = rawPath.split(",").map(p => p.trim())
  } else {
    ACCEPT_MODE = "single"
    EXISTING_PLAN_PATH = rawPath
  }
  ORCHESTRATION_PROMPT = $2
}
```

Update the Variables section to add:
- `ACCEPT_MODE`: `single` or `multi` (determined by presence of commas)
- `EXISTING_PLAN_PATHS`: Array of paths (multi mode only)

Update the `argument-hint` in YAML frontmatter:
```yaml
argument-hint: [user prompt or --accept <path>[,<path>,...] or --bmad <bmad-output-path>] [orchestration prompt]
```

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md:4,38-51,58-72`

### Task 3: Add multi-doc merge workflow section
**Owner:** builder-backend
**Dependencies:** Task 2

Add a new subsection under Accept Mode (after the Validation Checklist at line 114). The section should define:

**Accept Mode - Multi-Doc Merge Workflow:**

1. **Validate Inputs** — For each path in `EXISTING_PLAN_PATHS`:
   - Verify file exists (Read tool)
   - Verify file is non-empty
   - Verify file has `.md` extension
   - If any file is missing/empty/invalid, report ALL errors and stop

2. **Read All Documents** — Read each input file completely

3. **Merge Documents** — Using the dedicated merge prompt (Task 4), synthesize all inputs into one unified spec with all 7 required sections:
   - Combine `## Task Description` sections into a unified description
   - Combine `## Objective` into a cohesive objective
   - Merge `## Relevant Files` (deduplicate)
   - Combine `## Step by Step Tasks` — renumber sequentially, group by source document, preserve internal dependency references (remap as needed)
   - Merge `## Acceptance Criteria` (deduplicate, preserve all)
   - Merge `## Team Orchestration` / `### Team Members` (deduplicate members, combine role descriptions)
   - If `ORCHESTRATION_PROMPT` is provided, use it to guide merge decisions (priority, structure, team composition)

4. **Generate Filename** — Extract stems from input filenames:
   - Strip directory path
   - Strip `-plan.md`, `-spec.md`, or `.md` suffix
   - Join with `-` separator
   - Append `-merged.md`
   - If > 80 chars, use first 3 stems + `-merged.md`
   - Check for collision in `specs/`, append `-2`, `-3` if needed

5. **Add Frontmatter** — Include standard fields plus `merge_sources` array

6. **Save to specs/** — Write merged plan

7. **Report** — Use the multi-doc merge report format (Task 5)

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md` (insert after line 114)

### Task 4: Write dedicated merge prompt template
**Owner:** builder-backend
**Dependencies:** Task 3

Add a merge prompt section within the multi-doc merge workflow. This is the instruction set Claude follows when synthesizing multiple plans. Structure it similarly to the BMad Conversion Rules (lines 179-187):

**Multi-Doc Merge Rules:**

1. **Preserve All Details** — Don't summarize or simplify; keep all technical specs from all inputs
2. **Renumber Tasks Sequentially** — Tasks from input 1 become tasks 1-N, input 2 becomes N+1 to M, etc. Remap any dependency references
3. **Group by Source** — Tasks from the same source document stay grouped as a phase/section
4. **Deduplicate Team Members** — If multiple inputs define the same team member, merge their responsibilities
5. **Combine Acceptance Criteria** — Union of all criteria, deduplicated, organized by category
6. **Merge Relevant Files** — Union of all file references, deduplicated
7. **Resolve Frontmatter** — Use latest date, combine titles with `+`, use most specific type
8. **Honor Orchestration** — If `ORCHESTRATION_PROMPT` provided, it takes priority for conflict resolution

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md`

### Task 5: Add multi-doc merge report format
**Owner:** builder-backend
**Dependencies:** Task 3

Add a new report template after the existing Accept Mode Report (line 635):

```
### Multi-Doc Merge Report

\`\`\`
Specs Merged

Sources:
- <path1> (N tasks, M criteria)
- <path2> (N tasks, M criteria)
- <path3> (N tasks, M criteria)

Destination: specs/<merged-filename>.md

Merge Summary:
Total Tasks: <N> (combined and renumbered)
Team Members: <N> (deduplicated)
Acceptance Criteria: <N> (combined)

Merge Sources Recorded: Yes (in frontmatter)

Validation:
All required sections present

When you're ready, execute the plan by running:
/build specs/<merged-filename>.md
\`\`\`
```

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md` (insert after line 635)

### Task 6: Update Accept Mode Examples
**Owner:** builder-backend
**Dependencies:** Task 2

Update the Accept Mode Examples section (lines 742-756) to include multi-doc examples:

```bash
# Accept multiple plans and merge
/plan_w_team --accept docs/plans/backend-api.md,docs/plans/frontend-ui.md,docs/plans/shared-models.md

# Short form with multiple plans
/plan_w_team -a docs/plans/backend.md,docs/plans/frontend.md

# Merge with orchestration guidance
/plan_w_team --accept docs/plans/auth-backend.md,docs/plans/auth-frontend.md "Prioritize backend tasks. Use single fullstack agent."
```

**Files:** `plugins/tactical-engineering/commands/plan-w-team.md:742-756`

### Task 7: Update COMMANDS.md documentation
**Owner:** docs-agent
**Dependencies:** Task 6

Expand the `/plan_w_team` section in COMMANDS.md (currently lines 7-27, only shows Create mode) to document all three modes:

1. **Create mode** (existing, keep as-is)
2. **Accept mode — single doc** (new documentation)
3. **Accept mode — multi-doc merge** (new documentation)
4. **BMad mode** (new documentation)

Add usage examples for each mode. Follow the documentation style established by `/build` and `/party` sections.

**Files:** `plugins/tactical-engineering/COMMANDS.md:7-27`

## Team Orchestration

### Team Members

| Member | Agent Type | Tasks |
|--------|-----------|-------|
| builder-backend | general-purpose | Tasks 1-6 (sequential, same file) |
| docs-agent | general-purpose | Task 7 (COMMANDS.md) |

### Execution Strategy

Tasks 1-6 are sequential modifications to the same file (`plan-w-team.md`), so they should be executed by a single agent in order. Task 7 (COMMANDS.md) is independent and can run in parallel with later tasks.

## References

- Brainstorm: `docs/brainstorms/2026-02-20-multi-spec-accept-brainstorm.md`
- Current implementation: `plugins/tactical-engineering/commands/plan-w-team.md`
- BMad merge pattern: `plan-w-team.md:116-187`
- Accept mode: `plan-w-team.md:89-114, 566-684`
- COMMANDS.md: `plugins/tactical-engineering/COMMANDS.md:7-27`
