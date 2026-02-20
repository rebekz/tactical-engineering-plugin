# Knowledge-Aware Planning: Close the Compound-to-Plan Loop

**Date:** 2026-02-20
**Status:** Brainstorm
**Author:** User + Claude

## What We're Building

Close the broken feedback loop between `/compound` and `/plan_w_team`. Currently, `/compound` writes learnings to 4 knowledge stores (ADRs, solutions, deployment docs, CLAUDE.md), but `/plan_w_team` reads none of them during planning. User refinements during planning (like "always add QA team with real data tests across csv/iceberg/postgres") are also lost between sessions.

This feature adds:
1. **Read side:** A "Review Past Learnings" step in `/plan_w_team` Create Mode that reads compound outputs and planning patterns before designing the solution
2. **Write side (planning):** A prompt at the end of `/plan_w_team` asking "Any planning patterns to remember?"
3. **Write side (compound):** A planning-pattern extraction step in `/compound` that analyzes specs for reusable planning decisions

### User Story

As a developer who has run multiple plan-build-compound cycles, I want my future plans to automatically consider past architecture decisions, known pitfalls, and planning preferences, so each plan gets smarter without me repeating context.

### Example

After building a data pipeline feature where I refined the plan to include QA with real data testing across csv/iceberg/postgres, running `/compound` captures this as a planning pattern. Next time I run `/plan_w_team "Add new data source connector"`, the planner reads this pattern and includes QA with multi-source testing in the plan — without me having to specify it again.

## Why This Approach

**Approach chosen: Knowledge-Aware Planning**

Add a "Review Past Learnings" step to `/plan_w_team` that reads `docs/adr/`, `docs/solutions/`, and `docs/planning-patterns.md`. Capture patterns both during planning (user prompt) and post-build (compound extraction).

**Why not context-gatherer integration?** Too indirect. Relies on agent initiative to find and surface the right learnings. No guarantee relevant patterns are considered.

**Why not CLAUDE.md only?** CLAUDE.md grows unbounded. Can't include ADRs or detailed solutions (too much for system context). Doesn't support the capture-during-planning flow.

## Key Decisions

1. **Storage for planning patterns:** Dedicated `docs/planning-patterns.md` file (not CLAUDE.md). Keeps CLAUDE.md lean, easier to review and curate.
2. **Capture timing:** Both — prompt at end of `/plan_w_team` for immediate capture, PLUS `/compound` extracts patterns post-build for validation.
3. **Read strategy:** `/plan_w_team` Create Mode gets a new step between "Analyze Requirements" and "Design Solution" that reads:
   - `docs/planning-patterns.md` — user's planning preferences and reusable patterns
   - `docs/adr/` — architecture decisions from past builds
   - `docs/solutions/` — known pitfalls and solutions
4. **Relevance filtering:** The planner reads learnings but applies only what's relevant to the current feature. Irrelevant patterns are ignored, not force-applied.
5. **Planning patterns format:** Simple markdown list with categories. Each pattern has a title, description, and optionally a "when to apply" condition.

## Scope

### In Scope

- Add "Review Past Learnings" step to `/plan_w_team` Create Mode
- Add "Capture Planning Patterns" prompt at end of `/plan_w_team`
- Add planning-pattern extraction to `/compound` pipeline
- Create `docs/planning-patterns.md` template
- Update plan_w_team.md workflow and instructions

### Out of Scope

- Changes to `/build` command (doesn't plan)
- Changes to `/validate` command
- Changes to context-gatherer agent
- Auto-applying patterns without planner judgment
- UI for managing patterns

## Resolved Questions

1. **Should patterns be per-project or global?** Per-project. `docs/planning-patterns.md` lives in the project repo. Different projects have different conventions.
2. **What if docs/adr/ or docs/solutions/ is empty?** Skip silently. The step checks for existence and only reads if content is present. No error on first run.
3. **Should the planner cite which patterns it applied?** Yes. When the plan references a past learning, it should note "Based on ADR-003" or "Per planning pattern: always include QA with real data tests."
