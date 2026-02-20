---
name: plan_w_team
description: Creates a detailed engineering implementation plan based on user requirements, accepts an existing plan document, or converts BMad output documents. Saves to specs directory.
argument-hint: [user-prompt | --accept path[,path2,...] | --bmad path] [orchestration-prompt] [--ralph [--max-iterations N]]
model: opus
disallowed-tools: Task, EnterPlanMode
allowed-tools: AskUserQuestion, Bash, Glob, Grep, Read, Write, Edit, WebFetch, WebSearch, TaskOutput
hooks:
  Stop:
    - hooks:
        - type: command
          command: >-
            uv run $CLAUDE_PLUGIN_ROOT/hooks/validators/validate_new_file.py
            --directory specs
            --extension .md
        - type: command
          command: >-
            uv run $CLAUDE_PLUGIN_ROOT/hooks/validators/validate_file_contains.py
            --directory specs
            --extension .md
            --contains '## Task Description'
            --contains '## Objective'
            --contains '## Relevant Files'
            --contains '## Step by Step Tasks'
            --contains '## Acceptance Criteria'
            --contains '## Team Orchestration'
            --contains '### Team Members'
---

# Plan With Team

Create a detailed implementation plan based on user requirements, accept an existing plan document, or convert BMad output documents into specs. Supports three modes:

1. **Create Mode**: Generate a new plan from a user prompt
2. **Accept Mode**: Validate and import an existing plan document (single doc or multi-doc merge)
3. **BMad Mode**: Convert BMad output (PRD, architecture, epics, stories) into specs

## Variables

- `MODE`: Determined by first argument:
  - If starts with `--bmad`: BMad mode (convert BMad output)
  - If starts with `--accept` or `-a`: Accept mode (import existing plan)
  - Otherwise: Create mode (generate new plan from prompt)
- `USER_PROMPT`: $1 (Create mode) - The feature or task description
- `EXISTING_PLAN_PATH`: $1 (Accept mode, single doc, after `--accept`) - Path to existing plan document
- `EXISTING_PLAN_PATHS`: $1 (Accept mode, multi-doc, after `--accept`) - Array of comma-separated paths to merge
- `ACCEPT_MODE`: `single` or `multi` - Determined by presence of commas in the accept path argument
- `BMAD_OUTPUT_PATH`: $1 (BMad mode, after `--bmad`) - Path to BMad output directory (`_bmad_output/planning-artifacts/`)
- `ORCHESTRATION_PROMPT`: $2 - (Optional) Guidance for team assembly, task structure, and execution strategy
- `PLAN_OUTPUT_DIRECTORY`: `specs/`
- `TEAM_MEMBERS`: `agents/*.md`
- `GENERAL_PURPOSE_AGENT`: `general-purpose`

## Instructions

### Mode Detection

First, determine which mode to operate in:

```typescript
// Detect mode from first argument
if ($1.startsWith("--bmad")) {
  MODE = "bmad"
  BMAD_OUTPUT_PATH = $1.replace(/^--bmad/, "").trim()
  ORCHESTRATION_PROMPT = $2
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
} else {
  MODE = "create"
  USER_PROMPT = $1
  ORCHESTRATION_PROMPT = $2
}
```

### Ralph Flag Detection

Parse ralph flags from the arguments (applies to all modes):

```typescript
const RALPH_MODE = arguments.includes('--ralph')
const MAX_ITERATIONS = (() => {
  const idx = arguments.indexOf('--max-iterations')
  if (idx !== -1 && arguments[idx + 1]) {
    return Math.min(Math.max(parseInt(arguments[idx + 1]), 1), 50)
  }
  return 5
})()

if (RALPH_MODE) {
  console.log(`Ralph mode: will auto-start build with max ${MAX_ITERATIONS} iterations after planning`)
}
```

### Create Mode (Default)

When MODE is "create":

#### Core Principles

- **PLANNING ONLY**: Do NOT build, write code, or deploy agents. Your only output is a plan document saved to `specs/`
- If no `USER_PROMPT` is provided, stop and ask the user to provide it
- If `ORCHESTRATION_PROMPT` is provided, use it to guide team composition, task granularity, dependency structure, and parallel/sequential decisions
- Carefully analyze the user's requirements provided in the USER_PROMPT variable
- Determine the task type (chore|feature|refactor|fix|enhancement) and complexity (simple|medium|complex)
- Think deeply about the best approach to implement the requested functionality or solve the problem
- Understand the codebase directly without subagents to understand existing patterns and architecture

### Accept Mode (Import Existing Plan)

When MODE is "accept":

#### Core Principles

- **IMPORT ONLY**: Read, validate, and copy an existing plan to `specs/`
- The `EXISTING_PLAN_PATH` must be provided and must exist
- Read the existing plan document completely
- Validate that it contains all required sections
- Copy the plan to `specs/` with proper formatting
- Update frontmatter if needed (date, status, etc.)
- Provide a summary of the imported plan

#### Validation Checklist

Before accepting a plan, verify it contains:

**Required Sections:**
- [ ] `## Task Description`
- [ ] `## Objective`
- [ ] `## Relevant Files`
- [ ] `## Step by Step Tasks`
- [ ] `## Acceptance Criteria`
- [ ] `## Team Orchestration`
- [ ] `### Team Members`

#### Multi-Doc Merge (when ACCEPT_MODE is "multi")

When multiple comma-separated paths are provided, merge all input documents into a single unified spec.

##### Multi-Doc Merge Workflow

1. **Validate Inputs** — For each path in `EXISTING_PLAN_PATHS`:
   - Verify the file exists using the Read tool
   - Verify the file is non-empty (has content beyond whitespace)
   - Verify the file has a `.md` extension
   - If ANY file is missing, empty, or invalid, report ALL errors at once and stop. Do not proceed with partial inputs.

2. **Read All Documents** — Read each input file completely. Store the content and note the source path for each.

3. **Merge Documents** — Using the Multi-Doc Merge Rules below, synthesize all inputs into one unified spec containing all 7 required sections:
   - Combine `## Task Description` sections into a unified description covering all inputs
   - Combine `## Objective` into a cohesive objective
   - Merge `## Relevant Files` — union of all file references, deduplicated
   - Combine `## Step by Step Tasks` — renumber sequentially, group by source document, remap internal dependency references to new numbering
   - Merge `## Acceptance Criteria` — union of all criteria, deduplicated, preserve all
   - Merge `## Team Orchestration` / `### Team Members` — deduplicate team members, combine role descriptions for members that appear in multiple inputs
   - If `ORCHESTRATION_PROMPT` is provided, use it to guide merge decisions (priority, structure, team composition)

4. **Generate Filename** — Extract stems from input filenames:
   - Strip directory path (take basename only)
   - Strip `-plan.md`, `-spec.md`, or `.md` suffix
   - Join stems with `-` separator
   - Append `-merged.md`
   - If resulting filename exceeds 80 characters, use only the first 3 stems + `-merged.md`
   - Check for collision in `specs/` directory — if file exists, append `-2`, `-3`, etc.

5. **Add Frontmatter** — Include standard fields plus `merge_sources` array:
   ```yaml
   ---
   title: "<Stem1> + <Stem2> - Merged Implementation Plan"
   type: feat
   date: YYYY-MM-DD
   status: ready
   merge_sources:
     - <path1>
     - <path2>
     - <path3>
   ---
   ```

6. **Save to specs/** — Write the merged plan to `specs/<generated-filename>.md`

7. **Report** — Use the Multi-Doc Merge Report format (see Report section below)

##### Multi-Doc Merge Rules

1. **Preserve All Details**: Don't summarize or simplify — keep all technical specs from all inputs
2. **Renumber Tasks Sequentially**: Tasks from input 1 become tasks 1-N, input 2 becomes N+1 to M, etc. Remap any dependency references to use new numbering
3. **Group by Source**: Tasks from the same source document stay grouped together as a section or phase
4. **Deduplicate Team Members**: If multiple inputs define the same team member name, merge their responsibilities into one entry
5. **Combine Acceptance Criteria**: Union of all criteria from all inputs, deduplicated, organized by category (functional, non-functional, quality gates)
6. **Merge Relevant Files**: Union of all file references from all inputs, deduplicated
7. **Resolve Frontmatter**: Use the latest date across inputs, combine titles with `+`, use the most specific type (feat > enhancement > chore)
8. **Honor Orchestration**: If `ORCHESTRATION_PROMPT` is provided, it takes priority for resolving any conflicts between inputs

##### Multi-Doc Input Validation Error Report

If any input files fail validation:

```
Input Validation Failed

The following files could not be processed:
- <path1>: File not found
- <path2>: File is empty
- <path3>: Not a markdown file (.md)

Please fix the issues and try again.
All input files must exist, be non-empty, and have a .md extension.
```

### BMad Mode (Convert BMad Output)

When MODE is "bmad":

#### Core Principles

- **CONVERT ONLY**: Read BMad output documents and convert them into specs format
- The `BMAD_OUTPUT_PATH` must point to `_bmad_output/planning-artifacts/` directory
- Read all BMad documents: PRD, Architecture, Epics, Stories
- Convert into a unified spec document that can be executed by `/build`
- Preserve all technical details, acceptance criteria, and implementation requirements
- Create a comprehensive plan that covers all epics and stories

#### BMad Output Structure

BMad generates this structure:

```
_bmad_output/planning-artifacts/
├── prd/
│   └── <product-name>.md              # Product Requirements Document
├── architecture/
│   ├── index.md                        # Architecture overview
│   ├── adr-001-tech-stack.md          # Architecture Decision Records
│   ├── database-schema.md              # Database structure
│   └── deployment-guide.md             # Deployment procedures
├── epics/
│   └── index.md                        # Epic catalog with dependencies
│   ├── epic-001-*.md                   # Individual epic documents
│   ├── epic-002-*.md
│   └── ...
└── stories/
    ├── index.md                        # Story catalog
    ├── epic-001/
    │   ├── story-001-01-*.md
    │   ├── story-001-02-*.md
    │   └── ...
    ├── epic-002/
    └── ...
```

#### BMad Conversion Workflow

1. **Read BMad Structure** - Scan the `BMAD_OUTPUT_PATH` directory
2. **Read PRD** - Extract product requirements, features, and constraints
3. **Read Architecture** - Extract tech stack, design decisions, database schema
4. **Read Epics** - Extract epic catalog, dependencies, business value
5. **Read Stories** - Extract all stories with acceptance criteria
6. **Generate Spec Plan** - Create unified spec document from all BMad outputs
7. **Save to specs/** - Write the converted plan to `specs/<product-name>.md`
8. **Report** - Provide summary of conversion

#### BMad to Spec Mapping

| BMad Section | Spec Section | Notes |
|--------------|--------------|-------|
| PRD → Overview, Task Description, Objective | Product requirements become task description |
| Architecture → Relevant Files, Proposed Solution | Tech stack, architecture patterns |
| Epics → Implementation Phases | Each epic becomes a phase |
| Stories → Step by Step Tasks | Each story becomes a task with ACs |
| Story ACs → Acceptance Criteria | Map acceptance criteria directly |
| Epic Dependencies → Task Dependencies | Preserve dependency chains |

#### Conversion Rules

1. **Preserve All Details**: Don't summarize or simplify - keep all technical specs
2. **Map Stories to Tasks**: Each story becomes a task in the spec
3. **Group by Epic**: Stories under same epic are grouped in same phase
4. **Maintain Dependencies**: Epic dependency graph becomes task dependencies
5. **Include ACs as Acceptance Criteria**: Copy all acceptance criteria from stories
6. **Add Implementation Details**: Include code snippets, API specs, database schemas from stories
7. **Preserve Validation**: Include testing checklists and definition of done

#### BMad Spec Template

```md
---
title: "<product-name> - Implementation Plan"
type: feat
date: YYYY-MM-DD
status: ready
bmad_source: <path-to-bmad-output>
---

# Plan: <product-name>

## Overview

<from PRD: Product description, target users, value proposition>

**Key Deliverables:**
<from Epics: List of all epics and their stories>

**Architecture Note:**
<from Architecture: Tech stack, design philosophy>

## Task Description

<from PRD: Detailed product description>

## Objective

<from PRD: Product goals and success metrics>

## Problem Statement

<from PRD: Problem this product solves>

## Proposed Solution

<from Architecture: Technical approach and architecture>

Include architecture diagrams from architecture documents.

## Relevant Files

### Existing Files
<files mentioned in architecture/docs>

### New Files to Create
<files mentioned in stories and architecture>

## Implementation Phases

<From Epic catalog - each epic becomes a phase>

### Phase 1: <Epic 001 Title>

**Epic:** <Epic name>
**Business Value:** <from epic>
**Stories:** <list stories in this epic>

**Tasks:**

1.1. **<Story 001-01 Title>**
- **Story ID:** STORY-001-01
- **Points:** <story points>
- **Dependencies:** <from story>
- **User Story:** <from story>
- **Acceptance Criteria:**
  - [ ] <AC-001-01-01>
  - [ ] <AC-001-01-02>
- **Implementation Requirements:**
  - <from story technical notes>
- **Files:**
  - <files to create/modify>
- **Success Criteria:**
  - [ ] <from story definition of done>

<repeat for each story in epic>

**Success Criteria (Phase 1):**
- [ ] <from epic definition of done>

---

### Phase 2: <Epic 002 Title>
<same pattern>

---

## Alternative Approaches Considered

<from ADR documents in architecture>

## Team Orchestration

As the team lead, you have access to powerful tools for coordinating work across multiple agents. You NEVER write code directly - you orchestrate team members using these tools.

### Task Management Tools

**TaskCreate** - Create tasks in the shared task list:

```typescript
TaskCreate({
  subject: "Implement user authentication",
  description: "Create login/logout endpoints with JWT tokens. See specs/auth-plan.md for details.",
  activeForm: "Implementing authentication" // Shows in UI spinner when in_progress
})
// Returns: taskId (e.g., "1")
```

**TaskUpdate** - Update task status, assignment, or dependencies:

```typescript
TaskUpdate({
  taskId: "1",
  status: "in_progress", // pending → in_progress → completed
  owner: "builder-auth" // Assign to specific team member
})
```

**TaskList** - View all tasks and their status:

```typescript
TaskList({})
// Returns: Array of tasks with id, subject, status, owner, blockedBy
```

**TaskGet** - Get full details of a specific task:

```typescript
TaskGet({ taskId: "1" })
// Returns: Full task including description
```

### Task Dependencies

Use `addBlockedBy` to create sequential dependencies - blocked tasks cannot start until dependencies complete:

```typescript
// Task 2 depends on Task 1
TaskUpdate({
  taskId: "2",
  addBlockedBy: ["1"] // Task 2 blocked until Task 1 completes
})

// Task 3 depends on both Task 1 and Task 2
TaskUpdate({
  taskId: "3",
  addBlockedBy: ["1", "2"]
})
```

Dependency chain example:
```
Task 1: Setup foundation → no dependencies
Task 2: Implement feature → blockedBy: ["1"]
Task 3: Write tests → blockedBy: ["2"]
Task 4: Final validation → blockedBy: ["1", "2", "3"]
```

### Owner Assignment

Assign tasks to specific team members for clear accountability:

```typescript
// Assign task to a specific builder
TaskUpdate({
  taskId: "1",
  owner: "builder-api"
})

// Team members check for their assignments
TaskList({}) // Filter by owner to find assigned work
```

### Agent Deployment with Task Tool

**Task** - Deploy an agent to do work:

```typescript
Task({
  description: "Implement auth endpoints",
  prompt: "Implement the authentication endpoints as specified in Task 1...",
  subagent_type: "general-purpose",
  model: "opus", // or "opus" for complex work, "haiku" for VERY simple
  run_in_background: false // true for parallel execution
})
// Returns: agentId (e.g., "a1b2c3")
```

### Resume Pattern

Store the agentId to continue an agent's work with preserved context:

```typescript
// First deployment - agent works on initial task
Task({
  description: "Build user service",
  prompt: "Create the user service with CRUD operations...",
  subagent_type: "general-purpose"
})
// Returns: agentId: "abc123"

// Later - resume SAME agent with full context preserved
Task({
  description: "Continue user service",
  prompt: "Now add input validation to the endpoints you created...",
  subagent_type: "general-purpose",
  resume: "abc123" // Continues with previous context
})
```

**When to resume vs start fresh:**
- **Resume**: Continuing related work, agent needs prior context
- **Fresh**: Unrelated task, clean slate preferred

### Parallel Execution

Run multiple agents simultaneously with `run_in_background: true`:

```typescript
// Launch multiple agents in parallel
Task({
  description: "Build API endpoints",
  prompt: "...",
  subagent_type: "general-purpose",
  run_in_background: true
})
// Returns immediately with agentId and output_file path

Task({
  description: "Build frontend components",
  prompt: "...",
  subagent_type: "general-purpose",
  run_in_background: true
})

// Both agents now working simultaneously

// Check on progress
TaskOutput({
  task_id: "agentId",
  block: false, // non-blocking check
  timeout: 5000
})

// Wait for completion
TaskOutput({
  task_id: "agentId",
  block: true, // blocks until done
  timeout: 300000
})
```

### Orchestration Workflow

1. **Create tasks** with `TaskCreate` for each step in the plan
2. **Set dependencies** with `TaskUpdate` + `addBlockedBy`
3. **Assign owners** with `TaskUpdate` + `owner`
4. **Deploy agents** with `Task` to execute assigned work
5. **Monitor progress** with `TaskList` and `TaskOutput`
6. **Resume agents** with `Task` + `resume` for follow-up work
7. **Mark complete** with `TaskUpdate` + `status: "completed"`

### Team Members

<Define team based on tech stack from architecture>

#### Builder
- **Name:** <unique name>
- **Role:** <backend|frontend|fullstack>
- **Agent Type:** <agent type>
- **Resume:** true

## Step by Step Tasks

<Flatten all stories from all epics into sequential task list>

### 1. <Story 001-01 Title>
- **Task ID:** story-001-01
- **Depends On:** none
- **Assigned To:** <team member>
- **Agent Type:** <agent type>
- **Parallel:** false
- <implementation requirements from story>
- <acceptance criteria from story>

<continue for all stories in order>

## Acceptance Criteria

<Consolidated from all stories - group by functional/non-functional>

### Functional Requirements
- [ ] <from story ACs>
- [ ] <from story ACs>

### Non-Functional Requirements
- [ ] <from architecture performance targets>
- [ ] <from architecture quality goals>

### Quality Gates
- [ ] <from epic completion criteria>
- [ ] <from project completion criteria>

## Success Metrics

| Metric | Current | Target | Measurement |
|--------|---------|--------|-------------|
| <from PRD or architecture> | <value> | <target> | <measurement> |

## Dependencies & Prerequisites

### External Dependencies
| Dependency | Version | Purpose | Risk |
|------------|---------|---------|------|
| <from architecture tech stack> | <version> | <purpose> | <risk> |

### Internal Dependencies
| Dependency | Status | Notes |
|------------|--------|-------|
| <from epic dependencies> | <status> | <notes> |

## Risk Analysis & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| <from epic risk assessment> | <probability> | <impact> | <mitigation> |

## Resource Requirements

### Development Time Estimate
| Phase | Complexity | Estimate |
|-------|------------|----------|
| <from epic catalog> | | <total days> |

## Documentation Plan

| Document | Location | When |
|----------|----------|------|
| <from architecture documents> | <path> | <phase> |

## Validation Commands

<From architecture deployment guide and testing requirements>

## Notes

<Any additional context from BMad documents>

---

## Checklist Summary

### Phase 1: <Epic 001> 🟡
- [ ] <task from epic 001>
- [ ] <task from epic 001>

### Phase 2: <Epic 002> ⬜
- [ ] <task from epic 002>

### Phase 3: <Epic 003> ⬜
- [ ] <task from epic 003>
```

## Workflow

### Create Mode Workflow

1. **Analyze Requirements** - Parse the USER_PROMPT to understand the core problem and desired outcome
2. **Understand Codebase** - Without subagents, directly understand existing patterns, architecture, and relevant files
3. **Design Solution** - Develop technical approach including architecture decisions and implementation strategy
4. **Define Team Members** - Use `ORCHESTRATION_PROMPT` (if provided) to guide team composition. Document in plan
5. **Define Step by Step Tasks** - Use `ORCHESTRATION_PROMPT` (if provided) to guide task granularity and parallel/sequential structure. Document in plan
6. **Generate Filename** - Create a descriptive kebab-case filename based on the plan's main topic
7. **Save Plan** - Write the plan to `specs/<filename>.md`
8. **Report** - Provide a summary of key components

### Accept Mode Workflow

#### Single-Doc Accept (ACCEPT_MODE is "single")

1. **Detect Mode** - First argument starts with `--accept` or `-a`, no commas in path
2. **Extract Path** - Get the path to existing plan
3. **Read Plan** - Read the entire existing plan document
4. **Validate Sections** - Check for required sections
5. **Update Frontmatter** - Ensure proper YAML frontmatter
6. **Copy to specs/** - Write validated plan to specs directory
7. **Report** - Provide Accept Mode Report

#### Multi-Doc Merge (ACCEPT_MODE is "multi")

1. **Detect Mode** - First argument starts with `--accept` or `-a`, path contains commas
2. **Validate Inputs** - Check each path exists, is non-empty, and has `.md` extension
3. **Read All Documents** - Read each input file completely
4. **Merge Documents** - Apply Multi-Doc Merge Rules to synthesize one unified spec
5. **Generate Filename** - Auto-generate from input filenames with `-merged.md` suffix
6. **Add Frontmatter** - Include `merge_sources` array for traceability
7. **Save to specs/** - Write merged plan
8. **Report** - Provide Multi-Doc Merge Report

### BMad Mode Workflow

1. **Detect Mode** - First argument starts with `--bmad`
2. **Extract Path** - Get the path to BMad output directory
3. **Validate Structure** - Ensure `_bmad_output/planning-artifacts/` exists
4. **Read PRD** - `planning-artifacts/prd/<product>.md`
5. **Read Architecture** - All files in `planning-artifacts/architecture/`
6. **Read Epics** - `planning-artifacts/epics/index.md` and individual epic files
7. **Read Stories** - `planning-artifacts/stories/index.md` and all story files
8. **Generate Spec** - Create unified spec document from all BMad outputs
9. **Save to specs/** - Write the converted plan
10. **Report** - Provide conversion summary

## Report

### Create Mode Report

```
✅ Implementation Plan Created

File: specs/<filename>.md
Topic: <brief description>
Key Components:
- <component 1>
- <component 2>
- <component 3>

Team Task List:
- <Task 1> (<owner>)
- <Task 2> (<owner>)

Team members:
- <member 1>: <role>
- <member 2>: <role>

When you're ready, execute the plan by running:
/build specs/<filename>.md
```

### Accept Mode Report

```
✅ Plan Imported

Source: <original-path>
Destination: specs/<filename>.md

Plan Summary:
Title: <plan title>
Type: <feat|fix|refactor|enhancement|chore>
Status: <ready|in-progress|done>
Tasks: <N> tasks defined
Team Members: <N> members

Validation:
✅ All required sections present

When you're ready, execute the plan by running:
/build specs/<filename>.md
```

### Multi-Doc Merge Report

```
✅ Specs Merged

Sources:
- <path1> (<N> tasks, <M> criteria)
- <path2> (<N> tasks, <M> criteria)
- <path3> (<N> tasks, <M> criteria)

Destination: specs/<merged-filename>.md

Merge Summary:
Total Tasks: <N> (combined and renumbered)
Team Members: <N> (deduplicated)
Acceptance Criteria: <N> (combined)

Merge Sources Recorded: ✅ (in frontmatter)

Validation:
✅ All required sections present

When you're ready, execute the plan by running:
/build specs/<merged-filename>.md
```

### BMad Mode Report

```
✅ BMad Output Converted

BMad Source: <bmad-output-path>
Destination: specs/<product-name>.md

Conversion Summary:
Product: <product name>
PRD: ✅ Read
Architecture: ✅ Read
Epics: <N> epics
Stories: <M> stories

Implementation Plan:
Phases: <N> phases (from epics)
Tasks: <M> tasks (from stories)
Acceptance Criteria: <K> criteria

Tech Stack:
<from architecture tech stack>

When you're ready, execute the plan by running:
/build specs/<product-name>.md
```

### Validation Warning Report

If required sections are missing (in Accept or BMad mode):

```
⚠️ Plan Validation Warning

Source: <path>

Missing Required Sections:
- ## Task Description
- ## Team Orchestration

The plan is missing some required sections.

Options:
1. Proceed anyway - The plan will be imported as-is
2. Cancel - Fix the plan and try again

Would you like to proceed anyway? (y/n)
```

## Handoff

### Ralph Auto-Handoff

When `RALPH_MODE` is enabled, skip the handoff question and auto-start build:

```typescript
if (RALPH_MODE) {
  console.log(`Ralph mode: auto-starting build with max ${MAX_ITERATIONS} iterations`)
  // Auto-invoke /build with ralph flags
  // Equivalent to: /build specs/<filename>.md --ralph --max-iterations N
  Skill({ skill: "tactical-engineering:build", args: `specs/${filename}.md --ralph --max-iterations ${MAX_ITERATIONS}` })
  return // Skip the AskUserQuestion below
}
```

When `RALPH_MODE` is NOT enabled, fall through to the existing `AskUserQuestion` handoff.

After creating, importing, or converting the plan, use `AskUserQuestion` to present next steps:

```typescript
AskUserQuestion({
  questions: [{
    question: "Plan with team captured. What would you like to do next?",
    header: "Next Steps",
    options: [
      {
        label: "Proceed to build",
        description: "Run /build to execute the plan with multi-agent coordination (auto-detects the created spec)"
      },
      {
        label: "Refine orchestration",
        description: "Continue exploring and refine the team orchestration plan further"
      },
      {
        label: "Review plan",
        description: "Open and review the generated plan document before proceeding"
      },
      {
        label: "Done for now",
        description: "Return later - the plan is saved in specs/ and ready when you are"
      }
    ],
    multiSelect: false
  }]
})
```

### Handoff Behavior

Based on user selection:

- **"Proceed to build"**: Automatically run `/build specs/<filename>.md` to start execution
- **"Refine orchestration"**: Continue in planning mode to adjust team composition, task dependencies, or approach
- **"Review plan"**: Open the plan file for review
- **"Done for now"**: Provide summary and exit

## Examples

### Create Mode Examples

```bash
# Basic usage - create new plan
/plan_w_team "Add user authentication with OAuth providers"

# With orchestration guidance
/plan_w_team "Build real-time chat feature" "Use frontend-agent for UI, backend-agent for API, test-agent for tests. Run frontend and backend in parallel."

# Complex feature with detailed guidance
/plan_w_team "Revamp conversational UI with chat history and SSE streaming" "Phase 1: Backend foundation with API Gateway and Keycloak. Phase 2: Port UI components from KeyCenter. Phase 3: SSE integration. Run frontend and backend in parallel in Phase 2."
```

### Accept Mode Examples

```bash
# Accept existing plan from docs/plans/
/plan_w_team --accept docs/plans/2026-02-01-feat-conversational-ui-revamp-plan.md

# Short form
/plan_w_team -a docs/plans/2026-02-01-feat-conversational-ui-revamp-plan.md

# Accept from anywhere
/plan_w_team --accept ~/project/self/bmad-new/circuit/docs/plans/2026-02-01-feat-conversational-ui-revamp-plan.md

# Accept with orchestration override
/plan_w_team --accept docs/plans/oauth-plan.md "Use specific builder for API work"

# Accept multiple plans and merge into one spec (comma-separated)
/plan_w_team --accept docs/plans/backend-api.md,docs/plans/frontend-ui.md,docs/plans/shared-models.md

# Short form with multiple plans
/plan_w_team -a docs/plans/backend.md,docs/plans/frontend.md

# Merge with orchestration guidance
/plan_w_team --accept docs/plans/auth-backend.md,docs/plans/auth-frontend.md "Prioritize backend tasks. Use single fullstack agent."
```

### BMad Mode Examples

```bash
# Convert BMad output to spec
/plan_w_team --bmad ~/project/self/bmad-new/talenta-hr-bmad/_bmad-output/planning-artifacts

# Short form
/plan_w_team --bmad ~/project/self/bmad-new/talenta-hr-bmad/_bmad-output/planning-artifacts

# With orchestration override
/plan_w_team --bmad ~/project/self/bmad-new/talenta-hr-bmad/_bmad-output/planning-artifacts "Use Go-specialist for backend, template-specialist for frontend"

# Convert from different project
/plan_w_team --bmad ~/project/self/bmad-new/other-project/_bmad_output/planning-artifacts
```

### Ralph Mode Examples

```bash
# Full lifecycle with ralph — plan then auto-build with iteration
/plan_w_team "Add user authentication" --ralph

# Custom max iterations for auto-build
/plan_w_team "Build real-time chat" --ralph --max-iterations 10

# Accept plan and auto-build with ralph
/plan_w_team --accept docs/plans/my-plan.md --ralph
```

## Tips

1. **Use BMad Mode** when you have BMad output to convert - preserves all technical details
2. **Use Accept Mode** when you have existing planning documents to import — use comma-separated paths to merge multiple docs into one spec
3. **Use Create Mode** to generate plans from scratch based on your description
4. **Validation** ensures plans have all required sections for execution
5. **Orchestration Prompt** helps guide team composition and task structure
6. **Plans in specs/** are automatically validated and ready for `/build`
7. **BMad conversions preserve 100% of details** - all stories, ACs, technical specs, architecture decisions

## BMad Output Reference

BMad generates comprehensive development artifacts:

### PRD (Product Requirements Document)
- Product overview and goals
- Target users and use cases
- Design philosophy and constraints
- Feature requirements
- Success metrics

### Architecture
- Tech stack decisions (ADRs)
- Database schema
- Deployment guide
- Performance targets

### Epics
- Epic catalog with dependencies
- Business value for each epic
- Implementation sequence
- Sprint planning
- Risk assessment

### Stories
- Detailed user stories
- Acceptance criteria (AC-XXX)
- Technical implementation notes
- API specifications
- Database operations
- Testing checklist
- Definition of done
