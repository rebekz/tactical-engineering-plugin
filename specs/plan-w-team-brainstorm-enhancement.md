---
title: "Enhance plan-w-team with Brainstorm Capability and Research-Driven Planning"
type: feat
date: 2026-02-28
status: ready
origin: docs/brainstorms/2026-02-28-plan-w-team-brainstorm-enhancement-brainstorm.md
---

# Plan: Enhance plan-w-team with Brainstorm Capability and Research-Driven Planning

## Task Description

Add a `--brainstorm` flag to `plan-w-team` that triggers a collaborative brainstorm phase before planning, and enhance the planning workflow with parallel research agents, detail level selection, and brainstorm auto-detection with cross-checking. Create a reusable `skills/brainstorming/SKILL.md` following compound-engineering's pattern.

The brainstorm capability follows the same 4-phase approach as compound-engineering's brainstorming skill: assess clarity, understand idea, explore approaches, capture design. The planning enhancements draw inspiration from compound-engineering's plan workflow: parallel research agents, detail level selection, and brainstorm-to-plan traceability.

## Objective

1. Enable users to brainstorm before planning with `--brainstorm` flag on `plan-w-team`
2. Create a reusable brainstorming skill that can be used by `/plan_w_team`, `/party`, and future commands
3. Add parallel research agents to improve plan quality through codebase analysis and learnings discovery
4. Add detail level selection (MINIMAL/MORE/A LOT) controlling depth within existing 7 required sections
5. Auto-detect recent brainstorm documents and cross-check that decisions are carried into specs

## Relevant Files

### Existing Files to Modify
- `plugins/tactical-engineering/commands/plan-w-team.md` - Main command file, add brainstorm flag, research agents, detail levels, auto-detect, cross-check

### New Files to Create
- `plugins/tactical-engineering/skills/brainstorming/SKILL.md` - Reusable brainstorming skill with 4-phase dialogue, YAGNI principles, anti-patterns, document template

### Reference Files (read-only)
- `~/.claude/plugins/marketplaces/every-marketplace/plugins/compound-engineering/skills/brainstorming/SKILL.md` - Source of inspiration for brainstorming skill
- `~/.claude/plugins/marketplaces/every-marketplace/plugins/compound-engineering/commands/workflows/plan.md` - Source of inspiration for plan enhancements
- `plugins/tactical-engineering/CLAUDE.md` - Project conventions (additive-only command modification, content-based detection)
- `plugins/tactical-engineering/agents/context-gatherer.md` - Existing codebase research agent
- `docs/planning-patterns.md` - Past learnings (sequential tasks for overlapping files)
- `docs/brainstorms/2026-02-28-plan-w-team-brainstorm-enhancement-brainstorm.md` - Brainstorm document with all decisions

## Step by Step Tasks

### 1. Create Brainstorming Skill
- **Task ID:** brainstorming-skill
- **Depends On:** none
- **Assigned To:** skill-builder
- **Agent Type:** general-purpose
- **Parallel:** true (independent new file)

Create `plugins/tactical-engineering/skills/brainstorming/SKILL.md` following compound-engineering's pattern but adapted for tactical-engineering's context.

**Skill Content Requirements:**

Frontmatter:
```yaml
---
name: brainstorming
description: Guides exploring user intent, approaches, and design decisions before planning. Use before implementing features or when requirements are ambiguous. Triggers on --brainstorm flag or ambiguous feature requests.
---
```

Sections to include:

1. **When to Use This Skill** - Clear vs ambiguous requirement signals (same as compound-engineering)

2. **Core Process** with 4 phases:
   - **Phase 0: Assess Requirement Clarity** - Check if brainstorming is needed. Clear signals: specific acceptance criteria, referenced patterns, exact behavior, constrained scope. If clear, suggest skipping to planning
   - **Phase 1: Understand the Idea** - One question at a time via AskUserQuestion. Question techniques: prefer multiple choice, start broad then narrow, validate assumptions, ask about success criteria. Key topics table: Purpose, Users, Constraints, Success, Edge Cases, Existing Patterns. Exit when idea is clear or user says "proceed"
   - **Phase 2: Explore Approaches** - Propose 2-3 concrete approaches. Structure: Name, 2-3 sentence description, Pros, Cons, Best when. Lead with recommendation. Apply YAGNI
   - **Phase 3: Capture the Design** - Write brainstorm document to `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md`

3. **Brainstorm Document Template:**
```markdown
---
date: YYYY-MM-DD
topic: <kebab-case-topic>
---

# <Topic Title>

## What We're Building
[Concise description - 1-2 paragraphs max]

## Why This Approach
[Brief explanation of approaches considered and why this one was chosen]

## Key Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

## Open Questions
- [Any unresolved questions for the planning phase]

## Next Steps
-> Run /plan_w_team for implementation details
```

4. **YAGNI Principles** (5 rules):
   - Don't design for hypothetical future requirements
   - Choose the simplest approach that solves the stated problem
   - Prefer boring, proven patterns over clever solutions
   - Ask "Do we really need this?" when complexity emerges
   - Defer decisions that don't need to be made now

5. **Incremental Validation** - 200-300 words max per section. Pause to validate after each section

6. **Anti-Patterns Table:**
   | Anti-Pattern | Better Approach |
   |---|---|
   | Asking 5 questions at once | Ask one at a time |
   | Jumping to implementation details | Stay focused on WHAT, not HOW |
   | Proposing overly complex solutions | Start simple, add complexity only if needed |
   | Ignoring existing codebase patterns | Research what exists first |
   | Making assumptions without validating | State assumptions explicitly and confirm |
   | Creating lengthy design documents | Keep it concise - details go in the plan |

7. **Integration with Planning** - Brainstorming answers WHAT, planning answers HOW. When brainstorm output exists, `/plan_w_team` should detect it and use it as input

### 2. Update plan-w-team Frontmatter
- **Task ID:** frontmatter-update
- **Depends On:** none
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** true (independent change in frontmatter section)

Update the frontmatter of `plugins/tactical-engineering/commands/plan-w-team.md`:

1. Add `Agent` to the `allowed-tools` list (after `AskUserQuestion`):
   ```yaml
   allowed-tools: Agent, AskUserQuestion, Bash, Glob, Grep, Read, Write, Edit, WebFetch, WebSearch, TaskOutput
   ```

2. Update `argument-hint` to include `--brainstorm`:
   ```yaml
   argument-hint: [user-prompt | --accept path[,path2,...] | --bmad path] [orchestration-prompt] [--brainstorm] [--ralph [--max-iterations N]]
   ```

3. Update `description` to mention brainstorming:
   ```yaml
   description: Creates a detailed engineering implementation plan based on user requirements, accepts an existing plan document, or converts BMad output documents. Supports brainstorming with --brainstorm flag. Saves to specs directory.
   ```

### 3. Add Brainstorm Flag Detection
- **Task ID:** brainstorm-flag-detection
- **Depends On:** frontmatter-update
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

Add brainstorm flag detection in the existing "Ralph Flag Detection" section of `plan-w-team.md`. Insert AFTER the ralph flag detection block, BEFORE the "Create Mode (Default)" section:

```typescript
### Brainstorm Flag Detection

Parse brainstorm flag from arguments:

const BRAINSTORM_MODE = arguments.includes('--brainstorm')

// --brainstorm is NOT compatible with --ralph
if (BRAINSTORM_MODE && RALPH_MODE) {
  console.log('Error: --brainstorm and --ralph cannot be used together. Brainstorming requires interactive dialogue.')
  return
}

if (BRAINSTORM_MODE) {
  console.log('Brainstorm mode: will run collaborative brainstorm phase before planning')
}
```

### 4. Add Brainstorm Phase to Create Mode
- **Task ID:** brainstorm-phase
- **Depends On:** brainstorm-flag-detection
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

Add a new "Brainstorm Phase" section in the Create Mode workflow. Insert AFTER the "Core Principles" section and BEFORE the existing workflow steps. This is the Phase 0 that runs when `--brainstorm` is passed.

Content to add:

```markdown
#### Brainstorm Phase (when --brainstorm flag is set)

When BRAINSTORM_MODE is true, run the brainstorming skill before planning:

1. **Load Brainstorming Skill** - Load the `brainstorming` skill for detailed question techniques, approach exploration, and YAGNI principles

2. **Lightweight Repo Research** - Spawn a context-gatherer agent to understand existing patterns:
   ```typescript
   Agent({
     description: "Research codebase patterns",
     prompt: "Understand existing patterns related to: <USER_PROMPT>. Focus on: similar features, established patterns, CLAUDE.md guidance. Return a concise summary of relevant findings.",
     subagent_type: "tactical-engineering:context-gatherer",
     model: "sonnet"
   })
   ```

3. **Phase 0: Assess Clarity** - Evaluate whether full brainstorming is needed based on the USER_PROMPT. If requirements are already clear (specific acceptance criteria, referenced patterns, exact behavior, constrained scope), suggest skipping brainstorm:
   ```typescript
   AskUserQuestion({
     questions: [{
       question: "Your requirements seem detailed enough to proceed directly to planning. Should I brainstorm first or go straight to planning?",
       header: "Clarity",
       options: [
         { label: "Skip to planning", description: "Requirements are clear, proceed directly to plan creation" },
         { label: "Brainstorm first", description: "Explore the idea further before planning" }
       ],
       multiSelect: false
     }]
   })
   ```

4. **Phase 1: Understand the Idea** - Use AskUserQuestion one question at a time following the brainstorming skill's question techniques:
   - Prefer multiple choice when natural options exist
   - Start broad (purpose, users) then narrow (constraints, edge cases)
   - Validate assumptions explicitly
   - Ask about success criteria early
   - Continue until idea is clear OR user says "proceed"

5. **Phase 2: Explore Approaches** - Propose 2-3 concrete approaches based on research and conversation. For each: name, 2-3 sentence description, pros, cons, best when. Lead with recommendation. Apply YAGNI. Ask user which approach they prefer.

6. **Phase 3: Capture the Design** - Write brainstorm document to `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md` using the template from the brainstorming skill. Ensure `docs/brainstorms/` directory exists before writing.

7. **Resolve Open Questions** - Before proceeding, check if there are Open Questions in the brainstorm document. Ask the user about each one. Move resolved questions to a "Resolved Questions" section.

8. **Spec-Flow Analysis** - After brainstorm capture, spawn a context-gatherer agent to validate user flow completeness:
   ```typescript
   Agent({
     description: "Validate brainstorm completeness",
     prompt: "Review the brainstorm at docs/brainstorms/<filename>.md. Check for: completeness of user flows, missing edge cases, gaps in requirements, unclear acceptance criteria. Return a brief analysis of any gaps found.",
     subagent_type: "tactical-engineering:context-gatherer",
     model: "sonnet"
   })
   ```
   If gaps are found, present them to the user and ask if they want to address them before proceeding.

9. **Handoff to Planning** - After brainstorm is complete, proceed directly to the Create Mode Workflow (the brainstorm document becomes the input context for planning). Set BRAINSTORM_FILE to the path of the brainstorm document just created.

**Important:** After the brainstorm phase, the command continues into the regular Create Mode Workflow. The brainstorm document provides context but does not replace the planning steps.
```

### 5. Add Research Agents Phase to Create Mode Workflow
- **Task ID:** research-agents
- **Depends On:** brainstorm-phase
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

Insert a new step between "Understand Codebase" (step 2) and "Review Past Learnings" (step 3) in the Create Mode Workflow. This adds parallel research agents for deeper codebase understanding.

Modify the Create Mode Workflow to insert after step 2:

```markdown
2.5. **Research Phase (Parallel Agents)** - Spawn research agents in parallel for deeper context:
   ```typescript
   // Agent 1: Codebase patterns research
   Agent({
     description: "Research codebase patterns",
     prompt: "Analyze the codebase for patterns related to: <USER_PROMPT>. Focus on: existing implementations of similar features, architectural patterns, file organization conventions, naming conventions, test patterns. Return a structured summary with file paths and line numbers.",
     subagent_type: "tactical-engineering:context-gatherer",
     model: "sonnet",
     run_in_background: true
   })

   // Agent 2: Past learnings research
   Agent({
     description: "Research past learnings",
     prompt: "Search docs/solutions/, docs/adr/, and docs/planning-patterns.md for learnings relevant to: <USER_PROMPT>. Return applicable patterns, decisions, and pitfalls with their sources.",
     subagent_type: "Explore",
     model: "sonnet",
     run_in_background: true
   })
   ```
   Wait for both agents to complete. Incorporate findings into the planning context.

   **When to spawn external research:** If the feature involves security, payments, external APIs, or unfamiliar frameworks, also spawn:
   ```typescript
   // Agent 3: External best practices (conditional)
   Agent({
     description: "Research external best practices",
     prompt: "Research best practices and documentation for: <relevant-technology>. Focus on official docs, security considerations, and common pitfalls.",
     subagent_type: "Explore",
     model: "sonnet",
     run_in_background: true
   })
   ```
```

### 6. Add Detail Level Selection to Create Mode Workflow
- **Task ID:** detail-levels
- **Depends On:** research-agents
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

Insert a new step between "Design Solution" (step 4) and "Define Team Members" (step 5) in the Create Mode Workflow. This adds interactive detail level selection.

```markdown
4.5. **Select Detail Level** - Ask user what level of detail they want in the spec:
   ```typescript
   AskUserQuestion({
     questions: [{
       question: "What level of detail should the plan include?",
       header: "Detail level",
       options: [
         {
           label: "MINIMAL",
           description: "Core sections with bare-bones content. Task descriptions, objectives, and acceptance criteria only."
         },
         {
           label: "MORE (Recommended)",
           description: "Standard depth. Adds technical considerations, dependencies, risk notes, and implementation strategy within each section."
         },
         {
           label: "A LOT",
           description: "Maximum depth. Adds phased implementation details, alternative approaches considered, system impact analysis, and detailed risk mitigation within each section."
         }
       ],
       multiSelect: false
     }]
   })
   ```

   **Detail Level Guidelines:**
   All 7 required sections are always present (enforced by Stop hooks). The detail level controls depth WITHIN each section:

   **MINIMAL:**
   - `## Task Description` - 1-2 sentences
   - `## Objective` - Single bullet list
   - `## Relevant Files` - File paths only, no explanations
   - `## Step by Step Tasks` - Task name, assignee, and 1-line description per task
   - `## Acceptance Criteria` - Checkbox list only
   - `## Team Orchestration` - Minimal orchestration boilerplate
   - `### Team Members` - Name, role, agent type only

   **MORE (default):**
   - `## Task Description` - 1-2 paragraphs with context
   - `## Objective` - Numbered goals with success criteria
   - `## Relevant Files` - File paths with brief purpose descriptions
   - `## Step by Step Tasks` - Full task details: dependencies, agent type, implementation notes, acceptance criteria per task
   - `## Acceptance Criteria` - Grouped by functional/non-functional/quality gates
   - `## Team Orchestration` - Full orchestration workflow with code examples
   - `### Team Members` - Full member definitions with responsibilities

   **A LOT:**
   - All MORE content PLUS:
   - `## Task Description` - Includes problem statement, proposed solution, alternative approaches considered
   - `## Objective` - Includes phased objectives with milestones
   - `## Relevant Files` - Includes file dependency graph and interaction notes
   - `## Step by Step Tasks` - Includes detailed implementation requirements, code snippets, edge case handling per task
   - `## Acceptance Criteria` - Includes integration test scenarios, error propagation checks, API surface parity
   - `## Team Orchestration` - Includes risk mitigation strategies, rollback procedures
   - `### Team Members` - Includes expertise requirements, fallback assignments
```

### 7. Add Brainstorm Auto-Detect and Cross-Check
- **Task ID:** brainstorm-autodetect
- **Depends On:** detail-levels
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

Add two new capabilities to the Create Mode Workflow:

**Part A: Brainstorm Auto-Detect** - Insert at the very beginning of Create Mode Workflow (before step 1 "Analyze Requirements"):

```markdown
0. **Brainstorm Auto-Detect** - Scan `docs/brainstorms/` for a recent brainstorm matching the USER_PROMPT:
   - List files in `docs/brainstorms/` directory
   - For each `.md` file, read the YAML frontmatter `topic:` field
   - Check if the topic semantically matches the USER_PROMPT
   - Only consider files created within the last 14 days (check `date:` frontmatter)
   - If multiple matches, use the most recent one
   - If a match is found:
     - Read the brainstorm document fully
     - Set BRAINSTORM_FILE to the file path
     - Carry forward all key decisions, chosen approach, constraints, and open questions
     - Announce: "Found relevant brainstorm: <path>. Incorporating decisions into this plan."
   - If no match is found AND BRAINSTORM_MODE was not set, skip silently
   - If BRAINSTORM_FILE was already set (from brainstorm phase), skip auto-detect
```

**Part B: Brainstorm Cross-Check** - Insert as a new final step before "Save Plan" (before step 8):

```markdown
7.5. **Brainstorm Cross-Check** (when BRAINSTORM_FILE is set) - Re-read the brainstorm document and verify:
   - Every Key Decision from the brainstorm is reflected in the spec
   - The chosen approach is implemented in the spec's solution design
   - Constraints and requirements are captured in acceptance criteria
   - Open questions from the brainstorm are either resolved or flagged in the spec
   - If any brainstorm content is missing from the spec, add it before saving
   - Add `origin:` field to spec frontmatter pointing to the brainstorm file:
     ```yaml
     origin: docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md
     ```
   - Add source citation in spec: "Based on brainstorm: <path>" for carried-forward decisions
```

### 8. Update Examples and Report
- **Task ID:** examples-and-report
- **Depends On:** brainstorm-autodetect
- **Assigned To:** plan-w-team-builder
- **Agent Type:** general-purpose
- **Parallel:** false

**Part A: Add Brainstorm Examples** - Append to the existing Examples section:

```markdown
### Brainstorm Mode Examples

```bash
# Brainstorm before planning
/plan_w_team "Add user authentication" --brainstorm

# Brainstorm with orchestration guidance
/plan_w_team "Build real-time chat feature" "Use 3 agents" --brainstorm

# Auto-detect existing brainstorm (no flag needed if brainstorm exists in docs/brainstorms/)
/plan_w_team "Add user authentication"
# ^ will find docs/brainstorms/2026-02-28-user-authentication-brainstorm.md if it exists
```
```

**Part B: Update Create Mode Report** - Add brainstorm and research info to the report format:

```markdown
### Create Mode Report

```
✅ Implementation Plan Created

File: specs/<filename>.md
Topic: <brief description>
Detail Level: <MINIMAL|MORE|A LOT>

Brainstorm: <path to brainstorm file> (or "None - direct planning")
Research Agents: <N> agents spawned (<codebase patterns, past learnings, external research>)

Key Components:
- <component 1>
- <component 2>

Team Task List:
- <Task 1> (<owner>)
- <Task 2> (<owner>)

Team members:
- <member 1>: <role>
- <member 2>: <role>

Learnings Applied:
- <pattern or ADR applied> (source: <docs/planning-patterns.md | docs/adr/xxx.md>)
```
```

## Acceptance Criteria

### Functional Requirements
- [ ] `--brainstorm` flag triggers a collaborative brainstorm phase before planning
- [ ] Brainstorm phase follows 4-phase process: assess clarity, understand idea, explore approaches, capture design
- [ ] Brainstorm documents are saved to `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md`
- [ ] `--brainstorm` and `--ralph` cannot be used together (error message displayed)
- [ ] Agent tool is enabled in plan-w-team (added to allowed-tools)
- [ ] Research agents spawn in parallel (codebase patterns + past learnings)
- [ ] External research agents spawn conditionally (security, payments, external APIs)
- [ ] Detail level selection offered via AskUserQuestion (MINIMAL/MORE/A LOT)
- [ ] All 7 required sections present at all detail levels (Stop hook validation unchanged)
- [ ] Brainstorm auto-detect scans `docs/brainstorms/` for matching files within 14-day window
- [ ] Cross-check ensures brainstorm decisions are carried into spec
- [ ] Origin field added to spec frontmatter when brainstorm exists
- [ ] Spec-flow analysis runs after brainstorm capture to validate completeness
- [ ] New brainstorming skill created at `plugins/tactical-engineering/skills/brainstorming/SKILL.md`

### Non-Functional Requirements
- [ ] Existing plan-w-team modes (Create, Accept, BMad) work unchanged
- [ ] Existing Ralph mode works unchanged (--ralph without --brainstorm)
- [ ] Stop hook validation still enforces 7 required sections
- [ ] Additive-only changes to plan-w-team.md (per CLAUDE.md conventions)
- [ ] Brainstorming skill is reusable by other commands (/party, future commands)

### Quality Gates
- [ ] All existing examples in plan-w-team.md still valid
- [ ] New brainstorm examples added to Examples section
- [ ] Report format updated with brainstorm and research info

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
```

### Agent Deployment with Task Tool

**Task** - Deploy an agent to do work:

```typescript
Task({
  description: "Implement auth endpoints",
  prompt: "Implement the authentication endpoints as specified in Task 1...",
  subagent_type: "general-purpose",
  model: "opus",
  run_in_background: false
})
```

### Orchestration Workflow

1. **Create tasks** with `TaskCreate` for each step in the plan
2. **Set dependencies** with `TaskUpdate` + `addBlockedBy`
3. **Assign owners** with `TaskUpdate` + `owner`
4. **Deploy agents** with `Task` to execute assigned work
5. **Monitor progress** with `TaskList` and `TaskOutput`
6. **Mark complete** with `TaskUpdate` + `status: "completed"`

### Team Members

#### Skill Builder
- **Name:** skill-builder
- **Role:** Creates the brainstorming skill
- **Agent Type:** general-purpose
- **Resume:** true

#### Plan-w-Team Builder
- **Name:** plan-w-team-builder
- **Role:** Modifies plan-w-team.md with all enhancements
- **Agent Type:** general-purpose
- **Resume:** true

## Notes

**Learnings Applied:**
- Per planning pattern "Single Builder for Overlapping File Edits": All plan-w-team.md modifications use a single sequential builder (plan-w-team-builder) to avoid merge conflicts (source: docs/planning-patterns.md)
- Per planning pattern "Parallel Tasks Only for Independent New Files": The brainstorming SKILL.md (new file) can be created in parallel with plan-w-team.md modifications (source: docs/planning-patterns.md)
- Per ADR-002 "Content-Based Team Signal Detection": Brainstorm auto-detect uses content-based matching on frontmatter topic field, not just filename (source: docs/adr/ADR-002)
- Per CLAUDE.md "Command File Modification": Additive-only changes to plan-w-team.md - never remove or rewrite existing behavior
