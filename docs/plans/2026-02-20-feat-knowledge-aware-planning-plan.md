---
title: "feat: Knowledge-Aware Planning — Close the Compound-to-Plan Loop"
type: feat
status: active
date: 2026-02-20
brainstorm: docs/brainstorms/2026-02-20-knowledge-aware-planning-brainstorm.md
---

# feat: Knowledge-Aware Planning — Close the Compound-to-Plan Loop

## Overview

Close the broken feedback loop between `/compound` and `/plan_w_team`. Currently, `/compound` writes learnings to 4 knowledge stores (ADRs, solutions, deployment docs, CLAUDE.md), but `/plan_w_team` reads none of them during planning. User refinements during planning (like "always add QA team with real data tests across csv/iceberg/postgres") are also lost between sessions.

This feature adds:
1. **Read side:** A "Review Past Learnings" step in `/plan_w_team` Create Mode that reads compound outputs and planning patterns before designing the solution
2. **Write side (planning):** A prompt at the end of `/plan_w_team` asking "Any planning patterns to remember?"
3. **Write side (compound):** A planning-pattern extraction step in `/compound` that analyzes specs for reusable planning decisions

## Problem Statement

The compound engineering loop is supposed to make each build smarter than the last. But the feedback arrow from `/compound` back to `/plan_w_team` is not implemented:

```
/plan_w_team → /build → /compound → docs/adr/, docs/solutions/, CLAUDE.md
     ↑                                              |
     └──────── THIS LINK IS MISSING ────────────────┘
```

Planning refinements from users (e.g., "always include QA with multi-source testing") are verbal — they exist only in the session that produced them.

## Proposed Solution

Three modifications across two commands and two new files:

| Change | File | What |
|--------|------|------|
| Add "Review Past Learnings" step | `commands/plan-w-team.md` (line ~643) | Read `docs/planning-patterns.md`, `docs/adr/`, `docs/solutions/` before designing |
| Add "Capture Planning Patterns" prompt | `commands/plan-w-team.md` (line ~839) | Ask user after plan creation if any patterns should be remembered |
| Add pattern summary to report | `commands/plan-w-team.md` (line ~707) | Show which learnings were applied in the plan |
| Create planning-patterns-agent | `agents/planning-patterns-agent.md` (new) | Extract planning-level patterns from completed specs |
| Add agent to compound pipeline | `commands/compound.md` (before line ~283) | Launch planning-patterns-agent alongside other 6 agents |
| Update compound report format | `commands/compound.md` (lines ~369-442) | Include planning patterns in final report |
| Create patterns template | `docs/planning-patterns.md` (new) | Markdown file with categorized planning preferences |

## Acceptance Criteria

- [ ] `/plan_w_team` Create Mode reads `docs/planning-patterns.md` (if it exists) before "Design Solution" step
- [ ] `/plan_w_team` Create Mode reads `docs/adr/` summaries (if directory exists and has content)
- [ ] `/plan_w_team` Create Mode reads `docs/solutions/` summaries (if directory exists and has content)
- [ ] Create Mode Report includes a "Learnings Applied" section when patterns were used
- [ ] `/plan_w_team` Handoff prompts "Any planning patterns to remember?" and appends to `docs/planning-patterns.md`
- [ ] `/compound` launches a planning-patterns-agent that extracts planning-level decisions from specs
- [ ] `docs/planning-patterns.md` template exists with categories and example format
- [ ] Planning patterns agent definition exists at `agents/planning-patterns-agent.md`
- [ ] Empty `docs/adr/`, `docs/solutions/`, or missing `docs/planning-patterns.md` are handled silently (no errors on first run)
- [ ] Applied patterns cite their source (e.g., "Based on ADR-003" or "Per planning pattern: always include QA")

## Implementation Tasks

### Task 1: Create `docs/planning-patterns.md` template

**File:** `docs/planning-patterns.md` (new)

Create the planning patterns storage file with:
- Header explaining purpose
- Categories: Team Composition, Testing Strategy, Architecture Patterns, Workflow Preferences
- Each pattern format: `### <Title>` + description + "When to apply" condition
- Start empty (no example patterns — those come from real usage)

```markdown
# Planning Patterns

Reusable planning decisions captured from past builds and planning sessions.
These patterns are automatically read by `/plan_w_team` when creating new plans.

## Team Composition

<!-- Patterns about team structure, roles, and agent assignments -->

## Testing Strategy

<!-- Patterns about QA approach, test data, environments -->

## Architecture Patterns

<!-- Patterns about technical design decisions that recur -->

## Workflow Preferences

<!-- Patterns about build order, review process, deployment -->
```

- [ ] Create file with category headers
- [ ] Include brief header comment explaining how patterns are added

### Task 2: Create `agents/planning-patterns-agent.md`

**File:** `plugins/tactical-engineering/agents/planning-patterns-agent.md` (new)

Follow the established agent structure from CLAUDE.md. This agent:
- Reads the completed spec file and its tasks
- Identifies planning-level decisions (not code-level — those go to ADRs)
- Looks for: team composition choices, testing strategies, task ordering decisions, scope decisions
- Writes new patterns to `docs/planning-patterns.md` under the appropriate category
- Skips patterns that already exist (dedup by semantic similarity)

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

- [ ] Create agent file with YAML frontmatter
- [ ] Write Purpose, Instructions, Workflow, Report sections
- [ ] Instructions should read spec → identify planning decisions → check existing patterns → append new ones

### Task 3: Add "Review Past Learnings" step to plan-w-team Create Mode

**File:** `plugins/tactical-engineering/commands/plan-w-team.md` (~line 643)

Insert a new step between "Understand Codebase" (step 2) and "Design Solution" (step 3) in the Create Mode Workflow:

```
2. **Understand Codebase** - ...
3. **Review Past Learnings** - Check for relevant knowledge from past builds:
   - Read `docs/planning-patterns.md` if it exists — note relevant planning preferences
   - Scan `docs/adr/` for architecture decisions that may apply to this feature
   - Scan `docs/solutions/` for known pitfalls related to this domain
   - Apply only what's relevant. Ignore patterns that don't apply to the current feature
   - When a pattern is applied, cite its source in the plan
4. **Design Solution** - ... (renumbered from 3)
```

Renumber subsequent steps (Design Solution becomes 4, Define Team Members becomes 5, etc.).

- [ ] Insert "Review Past Learnings" step after "Understand Codebase"
- [ ] Renumber steps 3-7 to 4-8
- [ ] Include clear instructions about relevance filtering and citation

### Task 4: Add pattern summary to Create Mode Report

**File:** `plugins/tactical-engineering/commands/plan-w-team.md` (~line 707)

Add a "Learnings Applied" section to the Create Mode Report, between "Team members" and the `/build` instruction:

```
Team members:
- <member 1>: <role>
- <member 2>: <role>

Learnings Applied:
- <pattern or ADR applied> (source: <docs/planning-patterns.md | docs/adr/xxx.md>)
- (or "No relevant past learnings found" if none applied)

When you're ready, execute the plan by running:
/build specs/<filename>.md
```

- [ ] Add "Learnings Applied" section to Create Mode Report template
- [ ] Show "No relevant past learnings found" when nothing was applied

### Task 5: Add "Capture Planning Patterns" prompt to Handoff

**File:** `plugins/tactical-engineering/commands/plan-w-team.md` (~line 839)

After the existing AskUserQuestion handoff, add a second prompt that fires before the selected action:

```typescript
// After plan is created but before executing handoff action
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

If user selects "Yes, save a pattern":
1. Ask for the pattern description via a follow-up question
2. Determine the appropriate category (Team Composition, Testing Strategy, Architecture Patterns, Workflow Preferences)
3. Append to `docs/planning-patterns.md` under the right category header
4. Confirm: "Pattern saved to docs/planning-patterns.md under [Category]"

Then proceed with the original handoff action.

- [ ] Add pattern capture prompt after plan creation
- [ ] Handle "Yes" flow: get description, categorize, append to file
- [ ] Handle "No" flow: proceed directly to handoff action

### Task 6: Add planning-patterns-agent to compound pipeline

**File:** `plugins/tactical-engineering/commands/compound.md` (~line 282, before doc-assembler)

Add the planning-patterns-agent to the parallel agent launch in the Analysis Phase. Insert before the doc-assembler-agent (which needs to wait for all other agents):

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

Update the doc-assembler prompt to also validate planning patterns:
- Add `6. Read updated docs/planning-patterns.md` to the assembler's read list
- Add `- [ ] Planning patterns extracted (if any)` to validation checklist

Update the comment "Launch 6 parallel subagents" → "Launch 7 parallel subagents".

- [ ] Add planning-patterns-agent Task to the agents array
- [ ] Update doc-assembler prompt to include planning patterns validation
- [ ] Update agent count comment (6 → 7)

### Task 7: Update compound report format

**File:** `plugins/tactical-engineering/commands/compound.md` (~lines 369-442)

Add planning patterns to both the human-readable report and the YAML format:

**Human-readable report** (after line 396, before the closing `---`):

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

validation:
  ...
  planning_patterns_updated: true
```

- [ ] Add planning patterns to human-readable final report
- [ ] Add planning_patterns_extracted and planning_patterns to YAML format
- [ ] Add planning_patterns_updated to validation section

## References

- Brainstorm: `docs/brainstorms/2026-02-20-knowledge-aware-planning-brainstorm.md`
- plan-w-team command: `plugins/tactical-engineering/commands/plan-w-team.md`
- compound command: `plugins/tactical-engineering/commands/compound.md`
- Agent template: `plugins/tactical-engineering/CLAUDE.md` (Agent Structure section)
- Existing agents: `plugins/tactical-engineering/agents/`
