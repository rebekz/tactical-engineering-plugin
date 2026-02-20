---
title: "Knowledge-Aware Planning + Smart Team-Mode Handoff"
type: feat
date: 2026-02-20
status: ready
sources:
  - docs/plans/2026-02-20-feat-knowledge-aware-planning-plan.md
  - docs/plans/2026-02-20-feat-plan-w-team-build-mode-handoff-plan.md
brainstorm: docs/brainstorms/2026-02-20-knowledge-aware-planning-brainstorm.md
---

# Plan: Knowledge-Aware Planning + Smart Team-Mode Handoff

## Overview

Two enhancements to `/plan_w_team` that close critical gaps in the compound engineering loop:

1. **Knowledge-Aware Planning** — Close the feedback loop between `/compound` and `/plan_w_team`. Add a "Review Past Learnings" step that reads ADRs, solutions, and planning patterns before designing. Add a "Capture Planning Patterns" prompt after plan creation. Add a planning-patterns-agent to the `/compound` pipeline.

2. **Smart Team-Mode Handoff** — Detect whether a generated spec contains actual team member definitions and surface a `--team` build option in the handoff. Handle the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var gracefully.

## Task Description

### Knowledge-Aware Planning

The compound engineering loop is broken: `/compound` writes to `docs/adr/`, `docs/solutions/`, `docs/deployment.md`, and `CLAUDE.md`, but `/plan_w_team` reads none of them during planning. User refinements (like "always add QA team with real data tests across csv/iceberg/postgres") are lost between sessions.

### Smart Team-Mode Handoff

The `/plan_w_team` handoff always suggests vanilla `/build` even when the spec was explicitly designed for team-mode execution with named agents and role assignments. Users must remember to add `--team` themselves.

## Objective

- Make each planning cycle smarter by reading past learnings before designing solutions
- Capture user planning preferences so they persist across sessions
- Surface the right build mode (`--team` vs default) based on the spec content
- Handle missing env var gracefully with setup instructions

## Relevant Files

### Files to Modify

| File | Changes |
|------|---------|
| `plugins/tactical-engineering/commands/plan-w-team.md` | Add "Review Past Learnings" step (~line 643), update Create Mode Report (~line 707), remove static build suggestions from all 4 reports (~lines 691-808), add Team Signal Detection (~line 810), replace Handoff with conditional logic + pattern capture (~lines 810-849) |
| `plugins/tactical-engineering/commands/compound.md` | Add planning-patterns-agent to pipeline (~line 282), update doc-assembler prompt, update report format (~lines 369-442) |

### Files to Create

| File | Purpose |
|------|---------|
| `plugins/tactical-engineering/agents/planning-patterns-agent.md` | Agent that extracts planning-level patterns from completed specs |
| `docs/planning-patterns.md` | Storage file for reusable planning patterns with categories |

## Proposed Solution

### Read Side (plan-w-team)

Insert "Review Past Learnings" between "Understand Codebase" (step 2) and "Design Solution" (step 3) in Create Mode Workflow. This step reads `docs/planning-patterns.md`, scans `docs/adr/` and `docs/solutions/`, and applies only relevant patterns with source citations.

### Write Side (plan-w-team)

After plan creation, prompt the user: "Any planning patterns to remember?" If yes, categorize and append to `docs/planning-patterns.md`.

### Write Side (compound)

Add a 7th agent (`planning-patterns-agent`) to the compound pipeline that extracts planning-level decisions (team composition, testing strategy, task ordering, scope) from completed specs.

### Team Signal Detection

Scan generated spec content under `### Team Members` for actual team member definitions (subheadings, name/agent-type fields, table rows). If found, expand handoff to 5 options with "Build with --team" first. Check env var to decide auto-run vs setup instructions.

## Step by Step Tasks

### 1. Create `docs/planning-patterns.md` template
- **Depends On:** none
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** true

Create the planning patterns storage file:
- Header explaining purpose and how patterns are added
- Four categories: Team Composition, Testing Strategy, Architecture Patterns, Workflow Preferences
- HTML comments as placeholders under each category
- No example patterns (those come from real usage)

**Files:**
- `docs/planning-patterns.md` (new)

**Acceptance Criteria:**
- [ ] File exists with 4 category headers
- [ ] Header explains patterns are read by `/plan_w_team`

### 2. Create `agents/planning-patterns-agent.md`
- **Depends On:** none
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** true (with Task 1)

Create the agent definition following CLAUDE.md Agent Structure:

```yaml
---
name: planning-patterns-agent
description: Extracts reusable planning patterns from completed specs and appends them to docs/planning-patterns.md
tools: Bash, Glob, Grep, Read, Edit, Write
model: opus
permissionMode: default
color: cyan
---
```

Sections: Purpose, Instructions, Workflow, Report.

Instructions should:
- Read the completed spec file and its tasks
- Identify planning-level decisions (not code-level — those go to ADRs)
- Focus on: team composition choices, testing strategies, task ordering, scope decisions
- Read existing `docs/planning-patterns.md` to avoid duplicates
- Append new patterns under the appropriate category with `### <Title>` format
- Each pattern: title, description, "When to apply" condition

**Files:**
- `plugins/tactical-engineering/agents/planning-patterns-agent.md` (new)

**Acceptance Criteria:**
- [ ] Agent file has valid YAML frontmatter
- [ ] Has Purpose, Instructions, Workflow, Report sections
- [ ] Instructions cover: read spec → identify patterns → dedup → append

### 3. Add "Review Past Learnings" step to plan-w-team Create Mode
- **Depends On:** none
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** true (with Tasks 1, 2)

Modify `plugins/tactical-engineering/commands/plan-w-team.md` Create Mode Workflow (~line 640-649).

Insert step 3 between "Understand Codebase" and "Design Solution":

```
3. **Review Past Learnings** - Check for relevant knowledge from past builds:
   - Read `docs/planning-patterns.md` if it exists — note relevant planning preferences
   - Scan `docs/adr/` for architecture decisions that may apply to this feature
   - Scan `docs/solutions/` for known pitfalls related to this domain
   - Apply only what's relevant. Ignore patterns that don't apply to the current feature
   - When a pattern is applied, cite its source in the plan (e.g., "Based on ADR-003" or "Per planning pattern: always include QA")
   - If none of these files/directories exist or contain relevant content, skip silently
```

Renumber subsequent steps: Design Solution → 4, Define Team Members → 5, Define Tasks → 6, Generate Filename → 7, Save Plan → 8, Report → 9.

**Files:**
- `plugins/tactical-engineering/commands/plan-w-team.md` (lines ~640-649)

**Acceptance Criteria:**
- [ ] "Review Past Learnings" inserted as step 3
- [ ] Steps 4-9 renumbered correctly
- [ ] Instructions include relevance filtering and citation
- [ ] Missing files/empty directories handled silently

### 4. Add "Learnings Applied" to Create Mode Report
- **Depends On:** Task 3
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Add a "Learnings Applied" section to the Create Mode Report template (~line 707), between "Team members" and the build suggestion line:

```
Learnings Applied:
- <pattern or ADR applied> (source: <docs/planning-patterns.md | docs/adr/xxx.md>)
- (or "No relevant past learnings found" if none applied)
```

**Files:**
- `plugins/tactical-engineering/commands/plan-w-team.md` (lines ~705-711)

**Acceptance Criteria:**
- [ ] "Learnings Applied" section added to Create Mode Report
- [ ] Shows "No relevant past learnings found" when nothing was applied

### 5. Remove static build suggestion from all 4 report formats
- **Depends On:** Task 4
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Remove the trailing "When you're ready, execute the plan by running: /build specs/<filename>.md" line from all 4 report templates (Create ~line 710, Accept ~line 732, Multi-Doc Merge ~line 758, BMad ~line 785). The handoff `AskUserQuestion` now handles the build suggestion.

**Files:**
- `plugins/tactical-engineering/commands/plan-w-team.md` (4 report sections)

**Acceptance Criteria:**
- [ ] Static build suggestion removed from Create Mode Report
- [ ] Static build suggestion removed from Accept Mode Report
- [ ] Static build suggestion removed from Multi-Doc Merge Report
- [ ] Static build suggestion removed from BMad Mode Report

### 6. Add Team Signal Detection section
- **Depends On:** Task 5
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Insert a new section between the last report and the Handoff section (~line 810):

```markdown
## Team Signal Detection

Before presenting the handoff, scan the generated spec content for team member definitions.

Check the content under `### Team Members` for any of these patterns:
- Subheadings: lines starting with `####` (e.g., `#### Go Backend Builder`)
- Name fields: lines containing `- **Name:**` followed by a value
- Agent Type fields: lines containing `- **Agent Type:**` followed by a value
- Table rows: lines with `|` containing agent type values (not the header separator `|---|`)

If ANY pattern matches, set HAS_TEAM_SIGNALS = true.

Also check environment: AGENT_TEAMS_ENABLED = (process.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS === '1')
```

**Files:**
- `plugins/tactical-engineering/commands/plan-w-team.md` (insert before Handoff)

**Acceptance Criteria:**
- [ ] Detection section added before Handoff
- [ ] 4 positive signal patterns documented
- [ ] Env var check included
- [ ] Does NOT false-positive on empty Team Members sections (heading + placeholder only)

### 7. Replace Handoff with conditional logic + pattern capture
- **Depends On:** Task 6
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Replace the existing static Handoff (~lines 810-849) with a two-part handoff:

**Part A: Capture Planning Patterns** (fires after every plan creation):

```typescript
AskUserQuestion({
  questions: [{
    question: "Any planning patterns to remember for future plans? (e.g., 'Always include QA with real data tests', 'Use 3-agent team for small features')",
    header: "Patterns",
    options: [
      {
        label: "No patterns to save",
        description: "Proceed without capturing any planning patterns"
      },
      {
        label: "Yes, save a pattern",
        description: "I'll describe a pattern to remember for future /plan_w_team runs"
      }
    ],
    multiSelect: false
  }]
})
```

If "Yes": ask for description, categorize (Team Composition / Testing Strategy / Architecture Patterns / Workflow Preferences), append to `docs/planning-patterns.md`, confirm.

**Part B: Conditional Build Handoff** (fires after pattern capture):

If HAS_TEAM_SIGNALS is true — show 5 options:
1. "Build with --team" — if env var set: auto-run `/build specs/<file>.md --team`; if not set: show setup instructions (export + restart + manual command)
2. "Build with subagents" — run `/build specs/<file>.md`
3. "Refine orchestration" — continue planning
4. "Review plan" — open plan file
5. "Done for now" — summary and exit

If HAS_TEAM_SIGNALS is false — show existing 4 options:
1. "Proceed to build" — run `/build specs/<file>.md`
2. "Refine orchestration" — continue planning
3. "Review plan" — open plan file
4. "Done for now" — summary and exit

Update the **Handoff Behavior** section accordingly.

**Files:**
- `plugins/tactical-engineering/commands/plan-w-team.md` (lines ~810-849 + Handoff Behavior)

**Acceptance Criteria:**
- [ ] Pattern capture prompt fires after every plan creation
- [ ] "Yes" flow: gets description, categorizes, appends to file, confirms
- [ ] "No" flow: proceeds to build handoff
- [ ] Team signals + env var → 5 options, "Build with --team" auto-runs
- [ ] Team signals + no env var → 5 options, "Build with --team" shows setup instructions
- [ ] No team signals → existing 4-option handoff
- [ ] All modes (Create, Accept, Multi-Doc Merge, BMad) use same handoff logic

### 8. Add planning-patterns-agent to compound pipeline
- **Depends On:** Task 2
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Modify `plugins/tactical-engineering/commands/compound.md` Analysis Phase (~line 282).

Add planning-patterns-agent Task to the agents array, before doc-assembler-agent:

```typescript
Task({
  subagent_type: "planning-patterns-agent",
  prompt: `Analyze spec ${specPath} and extract reusable planning-level patterns.

Focus on decisions about:
- Team composition (who was on the team and why)
- Testing strategy (what testing approach was used)
- Task ordering and dependencies
- Scope decisions (what was included/excluded)

Read existing docs/planning-patterns.md to avoid duplicates.
Append new patterns under the appropriate category.

Report what patterns were extracted.`,
  model: "opus",
  run_in_background: true
}),
```

Update doc-assembler prompt:
- Add `6. Read updated docs/planning-patterns.md` to read list
- Add `- [ ] Planning patterns extracted (if any)` to validation checklist

Update comment: "Launch 6 parallel subagents" → "Launch 7 parallel subagents"

**Files:**
- `plugins/tactical-engineering/commands/compound.md` (lines ~121-310)

**Acceptance Criteria:**
- [ ] planning-patterns-agent Task added to agents array
- [ ] doc-assembler prompt includes planning patterns validation
- [ ] Agent count comment updated (6 → 7)

### 9. Update compound report format
- **Depends On:** Task 8
- **Assigned To:** builder
- **Agent Type:** general-purpose
- **Parallel:** false

Modify `plugins/tactical-engineering/commands/compound.md` report sections (~lines 369-442).

**Human-readable report** (after "Agent Guidelines" section, before closing `---`):

```
Planning Patterns:
- docs/planning-patterns.md (N new patterns extracted)
```

**YAML format** (after `patterns_added`, before `validation`):

```yaml
planning_patterns_extracted: 2
planning_patterns:
  - category: "Testing Strategy"
    pattern: "Always include QA with real data tests across csv/iceberg/postgres"
  - category: "Team Composition"
    pattern: "Include dedicated docs agent for API-heavy features"
```

**Validation section** — add:
```yaml
planning_patterns_updated: true
```

**Files:**
- `plugins/tactical-engineering/commands/compound.md` (lines ~369-442)

**Acceptance Criteria:**
- [ ] Planning patterns in human-readable report
- [ ] planning_patterns_extracted and planning_patterns in YAML format
- [ ] planning_patterns_updated in validation section

## Acceptance Criteria

### Knowledge-Aware Planning
- [ ] `/plan_w_team` Create Mode reads `docs/planning-patterns.md` before "Design Solution" step
- [ ] `/plan_w_team` Create Mode reads `docs/adr/` and `docs/solutions/` summaries
- [ ] Create Mode Report includes "Learnings Applied" section
- [ ] Handoff prompts "Any planning patterns to remember?" and appends to `docs/planning-patterns.md`
- [ ] `/compound` launches a planning-patterns-agent (7 agents total)
- [ ] `docs/planning-patterns.md` template exists with 4 categories
- [ ] `agents/planning-patterns-agent.md` exists with proper structure
- [ ] Missing files/empty directories handled silently (no errors on first run)
- [ ] Applied patterns cite their source

### Smart Team-Mode Handoff
- [ ] Team signals detected + env var set → 5 options, "Build with --team" first, auto-runs
- [ ] Team signals detected + env var missing → 5 options, shows setup instructions
- [ ] No team signals → existing 4-option handoff unchanged
- [ ] Detection does NOT false-positive on empty Team Members sections
- [ ] Detection DOES trigger on all real formats: subheading, bold fields, table rows
- [ ] Static build suggestion removed from all 4 report formats
- [ ] All 4 entry modes use same detection + handoff logic

## Team Orchestration

As the team lead, orchestrate a single builder agent to execute tasks sequentially. The tasks modify overlapping sections of `plan-w-team.md`, so sequential execution prevents conflicts.

### Team Members

#### Builder
- **Name:** builder
- **Role:** Full-stack implementer
- **Agent Type:** general-purpose
- **Resume:** true

## Validation Commands

```bash
# Verify new files exist
test -f docs/planning-patterns.md && echo "PASS: planning-patterns.md exists" || echo "FAIL"
test -f plugins/tactical-engineering/agents/planning-patterns-agent.md && echo "PASS: agent exists" || echo "FAIL"

# Verify plan-w-team.md has the new step
grep -c "Review Past Learnings" plugins/tactical-engineering/commands/plan-w-team.md

# Verify compound.md has 7 agents
grep -c "planning-patterns-agent" plugins/tactical-engineering/commands/compound.md

# Verify no static build suggestions remain in reports
grep -c "When you're ready, execute the plan by running" plugins/tactical-engineering/commands/plan-w-team.md
# Expected: 0

# Verify team signal detection exists
grep -c "Team Signal Detection" plugins/tactical-engineering/commands/plan-w-team.md
```

## References

- Brainstorm (knowledge-aware): `docs/brainstorms/2026-02-20-knowledge-aware-planning-brainstorm.md`
- Brainstorm (team handoff): `docs/brainstorms/2026-02-20-plan-w-team-build-mode-handoff-brainstorm.md`
- Source plan 1: `docs/plans/2026-02-20-feat-knowledge-aware-planning-plan.md`
- Source plan 2: `docs/plans/2026-02-20-feat-plan-w-team-build-mode-handoff-plan.md`
- Target: `plugins/tactical-engineering/commands/plan-w-team.md`
- Target: `plugins/tactical-engineering/commands/compound.md`
- Agent template: `plugins/tactical-engineering/CLAUDE.md` (Agent Structure)

## Compounded

- [x] Last compounded: 2026-02-20
- [x] ADRs created: 2
- [x] Solutions documented: 1
- [x] Deployment changes: 1
- [x] Patterns added: 5

**Generated Documents:**
- ADRs: `docs/adr/ADR-001-close-compound-to-plan-feedback-loop.md`, `docs/adr/ADR-002-content-based-team-signal-detection-for-build-mode-handoff.md`
- Solutions: `docs/solutions/build-patterns/track-based-parallel-execution.md`
- Deployment: `docs/deployment.md`
- Guidelines: `plugins/tactical-engineering/CLAUDE.md`
- Planning Patterns: `docs/planning-patterns.md` (3 patterns added)
