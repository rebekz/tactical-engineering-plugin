---
title: "/compound Command - Knowledge Compounding from Builds"
type: feat
date: 2026-02-03
status: ready
complexity: complex
related_brainstorm: docs/brainstorms/2026-02-03-compound-command-brainstorm.md
---

# Plan: /compound Command - Knowledge Compounding from Builds

## Overview

The `/compound` command extracts, structures, and documents knowledge from completed builds, creating a "compounding effect" where each build makes future builds easier. Following Every's compounding philosophy: "Each unit of engineering work should make subsequent units of work easier—not harder."

**Key Deliverables:**
- 6 parallel subagents for efficient knowledge extraction
- ADRs (Architecture Decision Records) for architecture choices
- docs/solutions/ for mistakes and their solutions
- docs/deployment.md with changelog for deployment knowledge
- CLAUDE.md updates for reusable patterns

**First Time:** Solving a problem takes 30 minutes of research
**After Compound:** Quick lookup takes 2 minutes
**Result:** Knowledge compounds, team gets smarter

---

## Problem Statement

After completing builds with `/build`, valuable knowledge is lost:

1. **Architecture choices aren't documented** - Why was Fiber chosen over Gin? What was the rationale for using SQLite?
2. **Deployment lessons fade** - What VPS configuration worked? What systemd setup was used?
3. **Mistakes get repeated** - The same N+1 query problem occurs in different modules
4. **Patterns aren't captured** - Multi-tenant query patterns, error handling formats, testing approaches
5. **Future builds start from scratch** - Each build re-researches decisions that were already made

**User Impact:**
- **Time wasted** - Re-solving already-solved problems
- **Inconsistency** - Different approaches for similar problems
- **Knowledge silos** - Lessons learned by one agent aren't available to others
- **Onboarding friction** - New team members (and agents) lack context

---

## Proposed Solution

The `/compound` command uses 6 parallel subagents to analyze completed builds and create structured documentation:

```
User runs: /compound specs/feature-name.md
                ↓
    ┌─────────────────────┐
    │  Launch 6 Parallel  │
    │     Subagents       │
    └─────────────────────┘
                ↓
    ┌───────────────────────────────────────────────────┐
    │ │                                                   │
    │ ▼                                                   ▼
┌───────────────┐                              ┌──────────────┐
│ Task Analyzer │                              │ Doc Assembler│
├───────────────┤                              ├──────────────┤
│ Reads spec    │──analysis JSON─────────────▶│ Coordinates │
│ Reads tasks   │                              │ all outputs │
│ Extracts:     │                              │ Validates   │
│ - Decisions   │                              │ Compiles    │
│ - Errors      │                              │ summary     │
│ - Deployment  │                              └──────┬───────┘
│ - Patterns    │                                     │
└───────────────┘                                     │
         │                                             │
         ├─────────────────────────────────────────────┤
         │                                             │
         ▼                                             ▼
┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐
│ Architecture     │  │  Deployment      │  │  Mistake     │
│ Writer           │  │  Writer          │  │  Extractor  │
├──────────────────┤  ├──────────────────┤  ├─────────────┤
│ Creates ADRs     │  │  Updates         │  │  Creates     │
│ in docs/adr/     │  │  deployment.md   │  │  solutions   │
│                  │  │  with changelog  │  │  in docs/    │
└──────────────────┘  └──────────────────┘  │  solutions/  │
                                         ┌─────────────┐
                                         │  CLAUDE      │
                                         │  Updater     │
                                         ├─────────────┤
                                         │  Updates     │
                                         │  CLAUDE.md   │
                                         │  with new    │
                                         │  patterns    │
                                         └─────────────┘
```

### Output Structure

```
docs/
├── adr/                               # Architecture Decision Records
│   ├── adr-001-use-fiber-framework.md
│   ├── adr-002-sqlite-over-postgres.md
│   └── adr-003-jwt-authentication.md
├── solutions/                         # Mistakes & Solutions
│   ├── performance-issues/
│   │   └── n-plus-one-query-employees.md
│   ├── security-vulnerabilities/
│   │   └── xss-in-user-input.md
│   └── database-optimizations/
│       └── missing-index-slow-queries.md
├── deployment.md                       # Deployment guide with changelog
└── brainstorms/
    └── 2026-02-03-compound-command-brainstorm.md
```

---

## Technical Approach

### Architecture

**Command Structure:** Following established patterns from `.claude/commands/build.md`

```yaml
---
name: compound
description: Extract and document learnings from completed builds. Use after /build completes to compound knowledge.
argument-hint: [path-to-spec]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion, Skill
---
```

**Subagent Architecture:** 6 specialized agents working in parallel

| Subagent | Role | Output |
|----------|------|--------|
| **task-analyzer-agent** | Reads spec + tasks, extracts decisions/changes/errors | Structured analysis JSON |
| **architecture-writer-agent** | Creates ADRs from architecture decisions | `docs/adr/adr-XXX-title.md` |
| **deployment-writer-agent** | Updates deployment.md with changelog | `docs/deployment.md` |
| **mistake-extractor-agent** | Creates solution docs from errors/fixes | `docs/solutions/[category]/[problem].md` |
| **claude-updater-agent** | Updates CLAUDE.md with new patterns | `CLAUDE.md` |
| **doc-assembler-agent** | Coordinates, validates, compiles summary | Summary report |

### Execution Flow

```typescript
// Phase 1: Discovery
function discoverBuild(specPath) {
  // Validate spec exists
  if (!fileExists(specPath)) {
    showError("Spec not found", availableSpecs)
  }

  // Get completed tasks from TaskList
  const tasks = TaskList({
    filter: { spec: specPath, status: "completed" }
  })

  if (tasks.length === 0) {
    showError("No completed tasks found", options)
  }

  return { spec, tasks }
}

// Phase 2: Parallel Analysis
function runParallelAnalysis(spec, tasks) {
  // Launch 6 subagents simultaneously
  const results = await Promise.all([
    launchAgent("task-analyzer-agent", { spec, tasks }),
    launchAgent("architecture-writer-agent", { waitFor: "task-analyzer" }),
    launchAgent("deployment-writer-agent", { waitFor: "task-analyzer" }),
    launchAgent("mistake-extractor-agent", { waitFor: "task-analyzer" }),
    launchAgent("claude-updater-agent", { waitFor: "task-analyzer" }),
    launchAgent("doc-assembler-agent", { waitFor: "all" })
  ])

  return results
}

// Phase 3: Assembly & Validation
function assembleDocumentation(results) {
  const assembler = results.docAssembler

  // Validate all outputs
  const validation = assembler.validate()
  if (!validation.passed) {
    presentValidationErrors(validation)
    askUserHowToProceed()
  }

  // Compile summary
  const summary = assembler.compileSummary()
  presentSummary(summary)
}
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Input Sources                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │  Spec File          │         │  Completed Tasks    │       │
│  │  specs/feature.md   │         │  TaskList/TaskGet   │       │
│  │                     │         │                     │       │
│  │  - Task Description │         │  - Subject           │       │
│  │  - Proposed Solution│         │  - Description      │       │
│  │  - Relevant Files   │         │  - Status (done)    │       │
│  │  - Tech Stack       │         │  - Output (agent)   │       │
│  └─────────────────────┘         └─────────────────────┘       │
│               │                             │                   │
│               └──────────────┬──────────────┘                  │
│                              ▼                                 │
│                   ┌─────────────────────┐                     │
│                   │   Task Analyzer     │                     │
│                   │   (Extraction)       │                     │
│                   └─────────────────────┘                     │
│                              │                                 │
│               ┌──────────────┴──────────────┐                  │
│               ▼                              ▼                  │
│     ┌──────────────────┐         ┌──────────────────┐         │
│     │ Structured Data  │         │  Raw Content     │         │
│     │  JSON:           │         │  - Decisions     │         │
│     │  {               │         │  - Errors        │         │
│     │    decisions: [] │         │  - Deployment    │         │
│     │    errors: []    │         │  - Patterns      │         │
│     │    deployment:{} │         │                  │         │
│     │    patterns: []  │         │                  │         │
│     │  }               │         │                  │         │
│     └──────────────────┘         └──────────────────┘         │
│               │                              │                   │
│               └──────────────┬──────────────┘                  │
│                              ▼                                 │
│        ┌─────────────────────────────────────┐                │
│        │         Parallel Subagents          │                │
│        ├─────────────────────────────────────┤                │
│        │ • Architecture Writer (ADRs)        │                │
│        │ • Deployment Writer (changelog)     │                │
│        │ • Mistake Extractor (solutions)     │                │
│        │ • CLAUDE Updater (patterns)          │                │
│        └─────────────────────────────────────┘                │
│                              │                                 │
│                              ▼                                 │
│                   ┌─────────────────────┐                     │
│                   │   Doc Assembler     │                     │
│                   │   (Validate + Sum)   │                     │
│                   └─────────────────────┘                     │
│                              │                                 │
│                              ▼                                 │
│                   ┌─────────────────────┐                     │
│                   │   Summary Report    │                     │
│                   │   + Links to Docs   │                     │
│                   └─────────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation & Task Analyzer (Week 1)

**Goal:** Build core analysis infrastructure

**Tasks:**

#### 1.1 Create Directory Structure
```bash
mkdir -p docs/adr
mkdir -p docs/solutions/{performance-issues,security-vulnerabilities,database-optimizations,api-design,frontend-bugs,deployment-issues,testing-problems}
touch docs/deployment.md
touch CLAUDE.md
```

**Files:**
- `docs/adr/.gitkeep`
- `docs/solutions/.gitkeep`
- `docs/deployment.md`
- `CLAUDE.md`

**Acceptance Criteria:**
- [ ] All directories created
- [ ] `.gitkeep` files for empty dirs
- [ ] Initial deployment.md with template
- [ ] Initial CLAUDE.md with project guidelines

---

#### 1.2 Create task-analyzer-agent

**File:** `.claude/agents/task-analyzer-agent.md`

```yaml
---
name: task-analyzer-agent
description: Analyzes spec files and completed tasks to extract architecture decisions, errors, deployment info, and patterns
tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write
model: opus
color: blue
---

# Task Analyzer Agent

## Purpose
Extract structured information from spec files and completed tasks to fuel the compound process.

## Instructions

### Step 1: Read Spec File
Read the spec file completely to understand:
- What was planned (Task Description, Objective)
- What architecture was proposed (Proposed Solution, Tech Stack)
- What was actually built (from task outputs)

### Step 2: Get Completed Tasks
Use TaskList to get all completed tasks for this spec:
```typescript
TaskList({})
```

For each completed task, use TaskGet to retrieve full details:
```typescript
TaskGet({ taskId: "1" })
```

### Step 3: Extract Decisions
Look for architecture decisions in task outputs:
- Framework/library choices
- Architectural patterns
- Data modeling decisions
- Security approaches
- Deployment strategies

**Keywords:** "decided to", "chose", "using", "selected", "framework", "library"

**Significance Criteria:**
- **Always document:** Framework choices, architectural patterns, data models, security, deployment
- **Never document:** Variable naming, code style, typo fixes
- **Case by case:** Implementation patterns (assess reusability), performance optimizations (>20% improvement?), API design (breaking changes?)

### Step 4: Extract Errors
Look for errors, bugs, and failures in task outputs:
- Error messages
- Stack traces
- "failed", "error", "exception", "bug"
- What didn't work and why
- How it was fixed

### Step 5: Extract Deployment Info
Look for deployment-related information:
- Environment configurations
- Docker/service files
- Database migrations
- Infrastructure as code
- Deployment commands

### Step 6: Extract Patterns
Look for reusable patterns:
- Multi-tenant query patterns
- Error handling formats
- Testing approaches
- Code organization patterns

### Step 7: Output Structured Analysis
Create JSON output with all extracted information:

```json
{
  "spec": "specs/feature-name.md",
  "spec_title": "Feature Name",
  "completed_tasks": 15,
  "extraction_date": "2026-02-03T10:00:00Z",

  "decisions": [
    {
      "type": "architecture",
      "title": "Use Fiber framework",
      "context": "Need web framework for API",
      "rationale": "Fastest Go framework, Express-like API",
      "consequences": ["Fast performance", "Smaller community"],
      "alternatives": ["Gin", "Echo"],
      "evidence": ["task-1-output", "task-3-output"]
    }
  ],

  "errors": [
    {
      "type": "performance",
      "category": "n-plus-one",
      "symptom": "Employee list took 15 seconds to load",
      "root_cause": "N+1 query for department associations",
      "solution": "Added .Preload('Department') to GORM query",
      "result": "15s → 400ms",
      "prevention": "Always preload associations",
      "evidence": ["task-8-output"]
    }
  ],

  "deployment": {
    "environment": "production",
    "platform": "linux-amd64",
    "changes": [
      {
        "type": "service",
        "description": "Added systemd service configuration",
        "config_file": "talenta-hr.service"
      },
      {
        "type": "database",
        "description": "Configured SQLite with WAL mode",
        "rationale": "Better concurrency"
      }
    ]
  },

  "patterns": [
    {
      "name": "Multi-tenant queries",
      "pattern": "All database queries MUST include company_id filter",
      "correct": "db.Where('company_id = ?', companyID).Find(&employees)",
      "incorrect": "db.Find(&employees)",
      "rationale": "Prevents data leaks across companies"
    }
  ]
}
```

## Output Format

Return the JSON as your final output. This will be consumed by the other subagents.

## Error Handling

- If spec file not found: Return error with available specs
- If no completed tasks: Return error with suggestions
- If task outputs are empty: Warn but continue with what's available
```

**Acceptance Criteria:**
- [ ] Agent reads spec file correctly
- [ ] Agent retrieves completed tasks via TaskList/TaskGet
- [ ] Agent extracts architecture decisions with significance filtering
- [ ] Agent extracts errors with root cause and solution
- [ ] Agent extracts deployment information
- [ ] Agent extracts reusable patterns
- [ ] Agent outputs valid JSON
- [ ] Agent handles missing data gracefully

**Files:**
- `.claude/agents/task-analyzer-agent.md`

---

#### 1.3 Create compound Command

**File:** `.claude/commands/compound.md`

```yaml
---
name: compound
description: Extract and document learnings from completed builds. Use after /build completes to compound knowledge.
argument-hint: [path-to-spec]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, AskUserQuestion, Skill
---

# /compound

Document a recently completed build to compound your team's knowledge.

## Purpose

Captures learnings while context is fresh, creating structured documentation that makes future builds faster and more consistent.

**Why "compound"?** Each documented solution compounds your team's knowledge. First time solving takes 30 minutes. After documenting, next time takes 2 minutes. Knowledge compounds.

## Usage

```bash
/compound [path-to-spec]
```

**Examples:**
```bash
# Compound most recent build
/compound

# Compound specific build
/compound specs/user-authentication.md

# Compound with dry run (preview first)
/compound specs/user-authentication.md --dry-run
```

## Variables

- `SPEC_PATH`: $1 - Path to the spec file (e.g., `specs/user-authentication.md`)
- If not provided, auto-detect most recent completed build

## Instructions

### Prerequisites

1. Build must be completed (run `/build` first)
2. Spec file must exist in `specs/` directory
3. Tasks must be tracked via Task tool

### Discovery Phase

**If no SPEC_PATH provided:**
1. Scan `specs/` directory for completed builds
2. Check TaskList for completed tasks matching each spec
3. Present available builds to user
4. Ask user to select

**If SPEC_PATH provided:**
1. Validate spec exists
2. Check for completed tasks via TaskList
3. If no tasks found, warn user and offer options

### Analysis Phase

**Launch 6 parallel subagents:**

1. **task-analyzer-agent** - Extract decisions, errors, deployment, patterns from spec + tasks
2. **architecture-writer-agent** - Wait for analysis, create ADRs
3. **deployment-writer-agent** - Wait for analysis, update deployment.md
4. **mistake-extractor-agent** - Wait for analysis, create solutions
5. **claude-updater-agent** - Wait for analysis, update CLAUDE.md
6. **doc-assembler-agent** - Wait for all, validate and compile summary

Use `Task` tool to launch subagents in parallel:

```typescript
// Launch all 6 agents
const taskAnalyzer = Task({
  description: "Analyze spec and tasks",
  prompt: `Analyze spec: ${SPEC_PATH}`,
  subagent_type: "task-analyzer-agent",
  run_in_background: true
})

// Launch other agents similarly
// ... architecture-writer, deployment-writer, etc.

// Wait for task analyzer
const analysis = TaskOutput({ task_id: taskAnalyzer.agentId, block: true })

// Launch writers with analysis
// ... (they run in parallel)
```

### Assembly Phase

**When all subagents complete:**

1. **Validate outputs:**
   - Check ADRs have required sections
   - Check solutions have required fields
   - Check deployment.md was updated
   - Check CLAUDE.md was updated
   - Validate markdown syntax
   - Check for broken links

2. **Compile summary:**
   - List all ADRs created (with links)
   - List all solutions created (with links)
   - Show deployment.md changes
   - Show CLAUDE.md changes
   - Provide statistics

### Report Format

```
✅ Compound Complete

Spec: specs/user-authentication.md
Duration: 3m 15s

Documentation Created:
📋 Architecture Decisions: 3 ADRs
   ➜ docs/adr/adr-001-jwt-authentication.md
   ➜ docs/adr/adr-002-fiber-framework.md
   ➜ docs/adr/adr-003-multi-tenant-isolation.md

🐛 Problems Solved: 2 solutions
   ➜ docs/solutions/security/token-storage.md
   ➜ docs/solutions/performance/login-query.md

📦 Deployment: Updated docs/deployment.md
   ➜ Added systemd service configuration
   ➜ Added environment variable documentation

📚 Patterns: 4 new patterns in CLAUDE.md
   ➜ Multi-tenant query filtering
   ➜ JWT token validation
   ➜ Error response format
   ➜ Password hashing with bcrypt

Summary:
- Architecture: 3 decisions documented
- Mistakes: 2 errors captured with solutions
- Deployment: 1 configuration documented
- Patterns: 4 reusable patterns extracted

Next Steps:
1. Review the ADRs for accuracy
2. Share with team for awareness
3. Next /build will reference these docs automatically

Run /status to see builds pending compound.
```

### Error Handling

**If spec not found:**
```
❌ Spec not found: specs/non-existent.md

Available specs (completed):
- specs/user-authentication.md (completed: 2 days ago)
- specs/user-profile.md (completed: today)
```

**If no completed tasks:**
```
⚠️ No completed tasks found for specs/feature.md

This spec either:
- Has not been built yet (run /build first)
- Build completed without task tracking
- Tasks were deleted

Options:
[1] Try to compound from git history (experimental)
[2] Mark this spec as "no-compound-needed"
[3] Cancel
```

**If already compounded:**
```
⚠️ This build was already compounded on 2026-02-02

Existing documentation:
- docs/adr/adr-001-jwt-auth.md
- docs/solutions/security/token-storage.md

Options:
[1] Update existing docs (amend)
[2] Create new versions (adr-006, etc.)
[3] Skip (already documented)
```

### Dry Run Mode

```bash
/compound specs/feature.md --dry-run
```

Shows preview without creating files:

```
🔍 Dry Run: Compound Preview

Spec: specs/feature.md

Architecture Decisions Found: 3
- Use Fiber framework
- JWT authentication
- Multi-tenant isolation

Deployment Changes: 1
- Added systemd service

Mistakes Identified: 2
- N+1 query in employee list
- XSS vulnerability in user input

Files that will be created:
- docs/adr/adr-004-use-fiber.md
- docs/adr/adr-005-jwt-auth.md
- docs/adr/adr-006-multi-tenant.md
- docs/solutions/performance/n-plus-one-employee-list.md
- docs/solutions/security/xss-user-input.md

Proceed with compound? [y/N]
```

## Examples

```bash
# Compound most recent build
/compound

# Compound specific build
/compound specs/user-authentication.md

# Preview before committing
/compound specs/user-authentication.md --dry-run

# Resume interrupted compound
/compound specs/user-authentication.md --resume

# Undo last compound
/compound specs/user-authentication.md --undo
```

## Tips

1. **Run after every significant build** - Compound while context is fresh
2. **Review generated docs** - ADRs and solutions should be accurate
3. **Reference in plans** - Future /plan commands will search these docs
4. **Share with team** - Knowledge compounds when shared

## Related Commands

- `/build` - Execute a build (run before /compound)
- `/plan` - Create a plan (searches compounded knowledge)
- `/status` - See builds pending compound
```

**Acceptance Criteria:**
- [ ] Command validates spec exists
- [ ] Command retrieves completed tasks
- [ ] Command launches 6 parallel subagents
- [ ] Command validates outputs
- [ ] Command compiles and presents summary
- [ ] Command handles errors gracefully
- [ ] Dry run mode works
- [ ] Help text is clear

**Files:**
- `.claude/commands/compound.md`

---

### Phase 2: Documentation Writer Agents (Week 2)

**Goal:** Create agents that generate documentation

#### 2.1 Create architecture-writer-agent

**File:** `.claude/agents/architecture-writer-agent.md`

**Responsibility:** Create ADRs from architecture decisions

**Template:**
```markdown
---
adr_id: ADR-XXX
date: YYYY-MM-DD
status: accepted
title: Decision Title
---

# ADR-XXX: Decision Title

## Context
<Background information, what problem are we solving?>

## Decision
<Clear statement of the decision>

**Rationale:**
- Reason 1
- Reason 2
- Reason 3

**Consequences:**
- ✅ Positive consequence 1
- ✅ Positive consequence 2
- ⚠️ Potential negative 1
- ⚠️ Potential negative 2

## Alternatives Considered
- Alternative 1: <why rejected>
- Alternative 2: <why rejected>

## Related
- Spec: specs/<name>.md
- Tasks: <task-ids>
```

**Acceptance Criteria:**
- [ ] Creates ADRs from decisions
- [ ] Uses ADR numbering with file locking
- [ ] Handles conflicting ADRs (supersede pattern)
- [ ] Validates required sections present
- [ ] Writes to `docs/adr/`

---

#### 2.2 Create deployment-writer-agent

**File:** `.claude/agents/deployment-writer-agent.md`

**Responsibility:** Update docs/deployment.md with changelog

**Template:**
```markdown
---
last_updated: YYYY-MM-DD
environment: production
platform: linux-amd64
---

# Deployment Guide

<existing content>

## Changelog

### YYYY-MM-DD - <Feature Name>
- Deployment change 1
- Deployment change 2
- **Decision:** Rationale for important decisions

**Lessons Learned:**
- Lesson 1
- Lesson 2
```

**Acceptance Criteria:**
- [ ] Updates docs/deployment.md
- [ ] Adds changelog entry
- [ ] Preserves existing content
- [ ] Validates markdown format

---

#### 2.3 Create mistake-extractor-agent

**File:** `.claude/agents/mistake-extractor-agent.md`

**Responsibility:** Create solution docs from errors/fixes

**Template:**
```markdown
---
category: <category>
component: <component>
tags: [<tags>]
date_resolved: YYYY-MM-DD
related_build: <spec-name>
related_tasks: [<task-ids>]
---

# <Problem Title>

## Problem Symptom
<What went wrong, error messages>

## Investigation Steps
1. Step 1
2. Step 2
3. Root cause found

## Root Cause
<Technical explanation of why it happened>

## Working Solution
<Step-by-step fix with code examples>

**Result:** <before → after>

## Prevention Strategies
1. Strategy 1
2. Strategy 2
3. Strategy 3

## Test Cases Added
<code examples of tests to prevent regression>

## Cross-References
- Related: <links to related docs>
- Similar issue: <links to similar solutions>
```

**Categories:**
- performance-issues
- security-vulnerabilities
- database-optimizations
- api-design
- frontend-bugs
- deployment-issues
- testing-problems
- integration-challenges

**Acceptance Criteria:**
- [ ] Creates solution docs for errors
- [ ] Categorizes correctly
- [ ] Includes all required fields
- [ ] Code examples are syntax-highlighted
- [ ] Cross-references related docs

---

#### 2.4 Create claude-updater-agent

**File:** `.claude/agents/claude-updater-agent.md`

**Responsibility:** Update CLAUDE.md with new patterns

**Template:**
```markdown
# <Project> - Agent Guidelines

## Architecture Patterns

### <Pattern Name>
<Pattern description>

**Correct:**
```go
<code example>
```

**Incorrect:**
```go
<code example>
```

**Rationale:** <why this pattern matters>
```

**Merge Strategy:**
- Append new patterns to appropriate sections
- Update existing patterns if similar found
- Remove patterns contradicted by new ADRs
- Ask user if uncertain

**Acceptance Criteria:**
- [ ] Extracts patterns from analysis
- [ ] Updates CLAUDE.md
- [ ] Merges with existing content
- [ ] Preserves existing knowledge
- [ ] Validates markdown format

---

### Phase 3: Coordination & Validation (Week 3)

**Goal:** Create doc-assembler-agent and validation

#### 3.1 Create doc-assembler-agent

**File:** `.claude/agents/doc-assembler-agent.md`

**Responsibility:** Coordinate subagents, validate outputs, compile summary

**Workflow:**
1. Wait for all 5 writer agents to complete
2. Collect all created file paths
3. Validate each file:
   - Markdown syntax valid
   - YAML frontmatter valid
   - Required sections present
   - No TODO placeholders
   - Links resolve (for cross-references)
4. If validation fails:
   - Present errors to user
   - Offer to fix automatically or show what to fix
5. Compile summary with:
   - File paths created
   - Statistics (count of each type)
   - Links to all docs
6. Present summary to user

**Acceptance Criteria:**
- [ ] Waits for all writer agents
- [ ] Validates all outputs
- [ ] Handles validation failures gracefully
- [ ] Compiles comprehensive summary
- [ ] Provides file links

---

#### 3.2 Add Validation Hooks

**File:** `.claude/commands/compound.md` (add to frontmatter)

```yaml
hooks:
  Stop:
    - hooks:
        - type: command
          command: >-
            # Validate docs/adr/ created
            # Validate docs/solutions/ created
            # Validate docs/deployment.md updated
            # Validate CLAUDE.md updated
```

**Acceptance Criteria:**
- [ ] Hook validates ADRs exist
- [ ] Hook validates solutions exist
- [ ] Hook validates deployment.md updated
- [ ] Hook validates CLAUDE.md updated
- [ ] Hook fails if validation fails

---

### Phase 4: Integration & Polish (Week 4)

**Goal:** Integrate with existing commands, add features

#### 4.1 Update build Command

**File:** `.claude/commands/build.md` (modify completion report)

**Add after build complete:**
```
✅ Build Complete!

Plan: specs/<plan-name>.md
Tasks Completed: <N>/<N>

📚 Document Learnings
Run /compound to capture learnings from this build:
  /compound specs/<plan-name>.md

This creates ADRs, solutions, and updates patterns for future builds.
```

**Acceptance Criteria:**
- [ ] Build command prompts for /compound
- [ ] Command example is correct
- [ ] Explanation is clear

---

#### 4.2 Update plan Command

**File:** `.claude/commands/plan-w-team.md` (add search step)

**Add during research phase:**
```markdown
### Research Phase

**Search Compounded Knowledge:**
1. Search docs/adr/ for relevant architecture decisions
2. Search docs/solutions/ for similar problems
3. Read CLAUDE.md for applicable patterns
4. Include "Related Documentation" section in plan

**Example:**
```markdown
## Related Documentation

### Architecture Decisions
- ADR-001: Use Fiber framework
- ADR-002: JWT authentication

### Similar Problems
- docs/solutions/performance/n-plus-one-query.md
- docs/solutions/security/xss-prevention.md

### Patterns from CLAUDE.md
- Multi-tenant query filtering
- Error response format
```
```

**Acceptance Criteria:**
- [ ] Plan searches docs/adr/
- [ ] Plan searches docs/solutions/
- [ ] Plan reads CLAUDE.md
- [ ] Plan includes "Related Documentation" section
- [ ] Links are correct

---

#### 4.3 Update status Command

**File:** `.claude/commands/status.md` (add section)

**Add to status output:**
```
## Documentation Status

Builds Pending Compound:
- specs/user-authentication.md (completed: 2 days ago)
- specs/user-profile.md (completed: today)

Recent Compounds:
- 2026-02-03: specs/employee-management.md (3 ADRs, 2 solutions)
- 2026-02-02: specs/company-registration.md (2 ADRs, 1 solution)

Documentation Health:
- ADRs: 12 total
- Solutions: 18 total
- Coverage: 85% of builds compounded
```

**Acceptance Criteria:**
- [ ] Status shows pending compounds
- [ ] Status shows compound history
- [ ] Status shows documentation health
- [ ] Data is accurate

---

#### 4.4 Add ADR Numbering System

**File:** `.claude/adr-counter.txt`

```
5
```

**Logic:**
1. Read counter file
2. Lock file for exclusive access
3. Increment number
4. Write back
5. Unlock
6. Use number for ADR

**Fallback:** If lock fails, use timestamp: `adr-YYYYMMDD-HHMMSS-title.md`

**Acceptance Criteria:**
- [ ] Counter file exists
- [ ] File locking works
- [ ] Numbers increment correctly
- [ ] Fallback to timestamp on lock failure

---

#### 4.5 Add Backup & Rollback

**Directory:** `.claude/compound-backups/YYYYMMDD-HHMMSS-<spec-name>/`

**Backup before compound:**
```
.claude/compound-backups/20260203-103000-user-auth/
├── files-created.txt       # List of files created
├── files-modified.txt      # List of files modified
├── deployment.md.backup     # Original content
├── CLAUDE.md.backup         # Original content
└── state.yml               # Compound state
```

**Rollback command:**
```bash
/compound specs/feature.md --undo
```

**Acceptance Criteria:**
- [ ] Backup created before any writes
- [ ] Backup includes all modified files
- [ ] Rollback restores originals
- [ ] Old backups cleaned up (>30 days)

---

#### 4.6 Add Resume Capability

**State file:** `.claude/compound-state.yml`

```yaml
last_run:
  spec: specs/feature.md
  timestamp: 2026-02-03T10:30:00Z
  status: incomplete
  completed_steps:
    - task_analyzer
    - architecture_writer
    - deployment_writer
  pending_steps:
    - mistake_extractor
    - claude_updater
    - doc_assembler
  files_created:
    - docs/adr/adr-005.md
    - docs/deployment.md
  files_pending:
    - docs/solutions/performance/n-plus-one.md
    - CLAUDE.md
```

**Resume logic:**
```bash
/compound specs/feature.md --resume
```

**Acceptance Criteria:**
- [ ] State file created on start
- [ ] State file updated after each step
- [ ] Resume skips completed steps
- [ ] Resume continues from incomplete step
- [ ] State file cleaned up on success

---

## Alternative Approaches Considered

### Approach A: Single Agent Sequential

**Description:** One agent does everything sequentially instead of 6 parallel agents.

**Pros:**
- Simpler to implement
- No coordination complexity
- Easier debugging

**Cons:**
- Slower (sequential vs parallel)
- Harder to scale specialized analysis
- Single point of failure

**Why Rejected:** Performance and quality benefits of parallel specialized agents outweigh simplicity.

---

### Approach B: Git Diff Analysis

**Description:** Analyze git diff instead of task outputs to extract changes.

**Pros:**
- Doesn't require task tracking
- Captures all code changes
- Works for any build

**Cons:**
- Misses context and rationale
- Too granular (every line changed)
- Doesn't capture errors or fixes
- Harder to extract "why" decisions

**Why Rejected:** Task outputs contain richer context (what was tried, what failed, why). Git diff shows what changed but not why.

---

### Approach C: Auto-Trigger After Build

**Description:** Automatically run /compound after every /build completes.

**Pros:**
- No user action needed
- Guaranteed documentation
- Never forget to compound

**Cons:**
- Documents experimental/failed builds
- Creates noise
- No user control over what's worth documenting

**Why Rejected:** Manual trigger gives user control, ensures only significant builds are documented, avoids noise.

---

### Approach D: Centralized Documentation Server

**Description:** Store compounded knowledge in a centralized server instead of local files.

**Pros:**
- Team-wide access
- Searchable across projects
- Version controlled

**Cons:**
- Network dependency
- More complex infrastructure
- Single point of failure

**Why Rejected:** Local files follow existing patterns, simpler, can be synced via git. Remote can be added later.

---

## Acceptance Criteria

### Functional Requirements

#### Discovery & Input
- [ ] FR1: Command accepts spec path argument
- [ ] FR2: Command auto-detects most recent build if no path provided
- [ ] FR3: Command validates spec exists
- [ ] FR4: Command retrieves completed tasks via TaskList
- [ ] FR5: Command handles missing tasks gracefully

#### Analysis & Extraction
- [ ] FR6: Task Analyzer reads spec file completely
- [ ] FR7: Task Analyzer extracts architecture decisions
- [ ] FR8: Task Analyzer applies significance criteria
- [ ] FR9: Task Analyzer extracts errors with root cause
- [ ] FR10: Task Analyzer extracts deployment information
- [ ] FR11: Task Analyzer extracts reusable patterns
- [ ] FR12: Task Analyzer outputs structured JSON

#### Documentation Generation
- [ ] FR13: Architecture Writer creates ADRs
- [ ] FR14: Architecture Writer uses ADR numbering system
- [ ] FR15: Architecture Writer follows ADR template
- [ ] FR16: Deployment Writer updates deployment.md
- [ ] FR17: Deployment Writer adds changelog entries
- [ ] FR18: Mistake Extractor creates solution docs
- [ ] FR19: Mistake Extractor categorizes by type
- [ ] FR20: CLAUDE Updater updates CLAUDE.md
- [ ] FR21: CLAUDE Updater merges with existing patterns

#### Coordination & Validation
- [ ] FR22: Doc Assembler coordinates 6 subagents
- [ ] FR23: Doc Assembler validates all outputs
- [ ] FR24: Doc Assembler handles validation failures
- [ ] FR25: Doc Assembler compiles summary report
- [ ] FR26: Command presents summary with file links

#### Error Handling
- [ ] FR27: Command handles spec not found
- [ ] FR28: Command handles no completed tasks
- [ ] FR29: Command handles subagent failures
- [ ] FR30: Command creates backups before writes
- [ ] FR31: Command supports resume after interruption
- [ ] FR32: Command supports rollback via --undo

#### Advanced Features
- [ ] FR33: Command supports dry run mode
- [ ] FR34: Command detects already compounded builds
- [ ] FR35: Command handles conflicting ADRs (supersede)
- [ ] Command supports incremental compounding

### Non-Functional Requirements

#### Performance
- [ ] NFR1: Small build (10 tasks) completes in <2 minutes
- [ ] NFR2: Medium build (50 tasks) completes in <5 minutes
- [ ] NFR3: Large build (100+ tasks) completes in <15 minutes

#### Quality
- [ ] NFR4: All ADRs have required sections (Context, Decision, Rationale, Consequences)
- [ ] NFR5: All solutions have required fields (Symptom, Root Cause, Solution, Prevention)
- [ ] NFR6: All docs have valid YAML frontmatter
- [ ] NFR7: All docs have valid markdown syntax
- [ ] NFR8: No broken internal links
- [ ] NFR9: No TODO placeholders in generated docs

#### Maintainability
- [ ] NFR10: ADRs use sequential numbering with file locking
- [ ] NFR11: Conflict resolution is clear and consistent
- [ ] NFR12: Backup system prevents data loss
- [ ] NFR13: State files enable resume capability
- [ ] NFR14: Code follows existing patterns from build.md

#### Usability
- [ ] NFR15: Command provides clear error messages
- [ ] NFR16: Dry run shows what will be created
- [ ] NFR17: Summary report is easy to understand
- [ ] NFR18: File links are clickable
- [ ] NFR19: Help text is comprehensive

### Integration Requirements

#### Build Integration
- [ ] IR1: Build command prompts for /compound after completion
- [ ] IR2: Build command shows correct /compound example
- [ ] IR3: Build command explains value of compounding

#### Plan Integration
- [ ] IR4: Plan command searches docs/adr/ for relevant decisions
- [ ] IR5: Plan command searches docs/solutions/ for similar problems
- [ ] IR6: Plan command reads CLAUDE.md for patterns
- [ ] IR7: Plan command includes "Related Documentation" section
- [ ] IR8: Plan command references specific docs with links

#### Status Integration
- [ ] IR9: Status command shows builds pending compound
- [ ] IR10: Status command shows compound history
- [ ] IR11: Status command shows documentation health metrics

#### Validate Integration
- [ ] IR12: Validate command checks documentation coverage
- [ ] IR13: Validate warns if significant build undocumented
- [ ] IR14: Validate checks for required ADRs

### Quality Gates

#### Documentation Completeness
- [ ] QG1: All significant architecture decisions have ADRs
- [ ] QG2: All errors have solution docs
- [ ] QG3: All deployment changes are in deployment.md
- [ ] QG4: All new patterns are in CLAUDE.md

#### Consistency
- [ ] QG5: Terminology is consistent across docs
- [ ] QG6: Formatting is consistent across ADRs
- [ ] QG7: Formatting is consistent across solutions
- [ ] QG8: Links are bidirectional where relevant

#### Accuracy
- [ ] QG9: ADRs accurately reflect what was implemented
- [ ] QG10: Solutions accurately describe root cause
- [ ] QG11: Code examples are syntax-correct
- [ ] QG12: Cross-references point to existing docs

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Time Savings** | 80% reduction in research time | Compare first-time vs documented lookup |
| **Documentation Coverage** | >85% of builds compounded | Track builds vs compounds |
| **ADRs Created** | 5+ per significant build | Count ADRs per compound |
| **Solutions Created** | 2+ per build with errors | Count solutions per compound |
| **Plan Integration** | 100% of plans reference docs | Check "Related Documentation" sections |
| **User Satisfaction** | >4/5 stars | Feedback on compound quality |

---

## Dependencies & Prerequisites

### Internal Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| `/build` command | ✅ Exists | Must complete before /compound |
| Task tool API | ✅ Exists | TaskList, TaskGet, TaskOutput |
| `specs/` directory | ✅ Exists | Created by /plan_w_team |
| `/plan_w_team` command | ✅ Exists | Will be updated for integration |
| `/status` command | ✅ Exists | Will be updated for integration |
| `/validate` command | ✅ Exists | Will be updated for integration |

### External Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| None | - | Pure documentation, no external deps |

### Prerequisite Tasks

- [ ] Review brainstorm document (✅ completed)
- [ ] Review SpecFlow analysis (✅ completed)
- [ ] Create docs/ directory structure
- [ ] Create docs/adr/ directory
- [ ] Create docs/solutions/ subdirectories
- [ ] Create initial docs/deployment.md
- [ ] Create initial CLAUDE.md
- [ ] Create .claude/adr-counter.txt

---

## Risk Analysis & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Subagent failure** | Medium | High | Retry mechanism, state file for resume, clear error messages |
| **ADR numbering conflicts** | Medium | Medium | File locking, timestamp fallback, validation |
| **Incorrect information extracted** | Medium | High | Dry run mode, user review, validation checks |
| **Data loss during compound** | Low | Critical | Backup before writes, rollback capability |
| **Performance on large builds** | Low | Medium | Chunking, progress indicators, optimization |
| **Conflicting documentation** | Medium | Medium | Supersede pattern, conflict detection, ask user |
| **Missing task data** | Medium | High | Fallback to git diff, graceful degradation |
| **Integration breakage** | Low | Medium | Careful integration, testing, backwards compatibility |

---

## Resource Requirements

### Development Time Estimate

| Phase | Complexity | Estimate |
|-------|------------|----------|
| **Phase 1: Foundation** | Medium | 1 week |
| **Phase 2: Writers** | Medium | 1 week |
| **Phase 3: Coordination** | Complex | 1 week |
| **Phase 4: Integration** | Medium | 1 week |
| **Testing & Polish** | Simple | 3-5 days |
| **Total** | Complex | 4-5 weeks |

### Team Requirements

- **Developer:** 1 (full-time)
- **Skills Needed:**
  - Understanding of multi-agent orchestration
  - Knowledge extraction and NLP basics
  - Documentation best practices
  - YAML/Markdown formatting

### Infrastructure Requirements

- No special infrastructure needed
- Runs on same system as Claude Code
- Uses existing Task tool API
- Local file system only

---

## Documentation Plan

| Document | Location | When |
|----------|----------|------|
| **User Guide** | README.md | Phase 4 |
| **Agent Specifications** | .claude/agents/*.md | Phase 1-2 |
| **Command Documentation** | .claude/commands/compound.md | Phase 1 |
| **ADR Examples** | docs/adr/adr-*.md | Phase 2+ |
| **Solution Examples** | docs/solutions/*/*.md | Phase 2+ |
| **Integration Guide** | COMMANDS.md | Phase 4 |

---

## Validation Commands

```bash
# Test compound command exists
ls -la .claude/commands/compound.md

# Test agents exist
ls -la .claude/agents/task-analyzer-agent.md
ls -la .claude/agents/architecture-writer-agent.md
ls -la .claude/agents/deployment-writer-agent.md
ls -la .claude/agents/mistake-extractor-agent.md
ls -la .claude/agents/claude-updater-agent.md
ls -la .claude/agents/doc-assembler-agent.md

# Test directory structure exists
ls -la docs/adr/
ls -la docs/solutions/
ls -la docs/deployment.md
ls -la CLAUDE.md

# Test ADR counter exists
cat .claude/adr-counter.txt

# Test compound command (dry run)
/compound specs/example.md --dry-run

# Validate output structure
find docs/adr -name "*.md" | wc -l  # Should be >0 after compound
find docs/solutions -name "*.md" | wc -l  # Should be >0 after compound
grep -q "last_updated" docs/deployment.md  # Should have changelog
grep -q "Architecture Patterns" CLAUDE.md  # Should have patterns
```

---

## Notes

### Key Design Decisions

1. **Manual trigger** - User runs /compound explicitly, ensures quality over quantity
2. **Parallel subagents** - 6 agents for speed and specialization, following Every's pattern
3. **Spec + Tasks as source** - Combines what was planned (spec) with what happened (tasks)
4. **ADR format** - Standard architecture decision record format for permanence
5. **Solutions format** - Every's pattern for quick lookup of mistakes/fixes
6. **Significance criteria** - Filter to avoid noise, document what matters
7. **Supersede pattern** - Handle conflicting ADRs by linking old to new
8. **Backup & rollback** - Safety mechanisms to prevent data loss
9. **Resume capability** - Handle interruptions gracefully
10. **Integration focus** - Plans and builds reference compounded knowledge

### Open Questions for Future

1. **Should /compound support multiple builds at once?** - Maybe add `--chain` flag
2. **Should /compound auto-detect changes from spec?** - Maybe add `--detect-deltas` flag
3. **Should /compound create git commits?** - Maybe add `--commit` flag (opt-in)
4. **Should /compound have an interactive mode?** - Maybe add `--interactive` flag
5. **Should /compound support custom categories?** - Maybe add config file support

### References

- **Brainstorm:** docs/brainstorms/2026-02-03-compound-command-brainstorm.md
- **SpecFlow Analysis:** (conducted during planning)
- **Every's /workflows:compound:** https://raw.githubusercontent.com/EveryInc/compound-engineering-plugin/refs/heads/main/plugins/compound-engineering/commands/workflows/compound.md
- **ADR Format:** https://adr.github.io/
- **Existing /build:** .claude/commands/build.md
- **Compound Philosophy:** .claude/docs/compound-engineering.md

---

## Checklist Summary

### Phase 1: Foundation & Task Analyzer 🟡
- [ ] Create directory structure (docs/adr/, docs/solutions/, etc.)
- [ ] Create task-analyzer-agent.md
- [ ] Create compound.md command
- [ ] Create ADR counter file
- [ ] Test agent can read spec
- [ ] Test agent can retrieve tasks
- [ ] Test agent extracts decisions
- [ ] Test agent extracts errors
- [ ] Test agent outputs JSON

### Phase 2: Documentation Writer Agents ⬜
- [ ] Create architecture-writer-agent.md
- [ ] Create deployment-writer-agent.md
- [ ] Create mistake-extractor-agent.md
- [ ] Create claude-updater-agent.md
- [ ] Test ADR creation
- [ ] Test deployment.md updates
- [ ] Test solution creation
- [ ] Test CLAUDE.md updates

### Phase 3: Coordination & Validation ⬜
- [ ] Create doc-assembler-agent.md
- [ ] Add validation hooks to compound.md
- [ ] Test parallel execution
- [ ] Test validation failures
- [ ] Test summary compilation
- [ ] Test backup creation
- [ ] Test rollback capability

### Phase 4: Integration & Polish ⬜
- [ ] Update build.md with compound prompt
- [ ] Update plan-w-team.md with search step
- [ ] Update status.md with documentation section
- [ ] Test dry run mode
- [ ] Test resume mode
- [ ] Test undo mode
- [ ] Test all integrations
- [ ] Update README.md
- [ ] Update COMMANDS.md

---

**Status:** ✅ Ready for Implementation
**Estimated Duration:** 4-5 weeks
**Complexity:** Complex (6 subagents, parallel execution, validation, integration)
**Next Step:** Run `/workflows:work docs/plans/2026-02-03-feat-compound-command-plan.md`
