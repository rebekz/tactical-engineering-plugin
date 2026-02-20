---
id: ADR-001
title: "Close the Compound-to-Plan Feedback Loop"
date: 2026-02-20
status: accepted
deciders: [user, claude]
feature: knowledge-aware-planning-and-team-handoff
spec: specs/knowledge-aware-planning-and-team-handoff.md
---

# ADR-001: Close the Compound-to-Plan Feedback Loop

## Status

Accepted

## Context

The compound engineering flywheel was operating with a broken feedback loop. The write side existed: `/compound` extracts learnings from completed builds and writes them to `docs/adr/`, `docs/solutions/`, `docs/deployment.md`, and `CLAUDE.md`. But the read side was missing: `/plan_w_team` read none of these stores when designing new solutions.

This meant that user refinements made during planning sessions — such as "always add QA with real data tests across csv/iceberg/postgres" — were lost between sessions. Each planning run started from scratch, ignoring knowledge that had already been hard-won through prior build-validate-compound cycles.

Three alternative approaches were considered:

1. **Context-gatherer integration** — Have an existing context-gatherer agent surface relevant learnings before planning. Rejected because it was too indirect: the approach relied on agent initiative with no guarantee that relevant patterns would be surfaced at the right time.

2. **CLAUDE.md only** — Append all learnings to the project-level `CLAUDE.md` system prompt. Rejected because CLAUDE.md grows unbounded and cannot host detailed solutions or full ADR text without polluting the global system context for every command, not just planning.

3. **Knowledge-Aware Planning (chosen)** — Add an explicit "Review Past Learnings" step to `/plan_w_team` Create Mode that reads the knowledge stores before the "Design Solution" step. Add a write-side prompt at the end of planning to capture preferences immediately. Add a `planning-patterns-agent` to `/compound` to extract planning-level decisions post-build.

## Decision

Add a "Review Past Learnings" step to `/plan_w_team` Create Mode, inserted between the existing "Understand Codebase" step and the "Design Solution" step.

The step reads three sources:

- `docs/planning-patterns.md` — user-curated planning preferences accumulated from past sessions
- `docs/adr/` — architecture decisions from past builds, written by `/compound`
- `docs/solutions/` — known pitfalls and solutions, written by `/compound`

The planner applies only what is relevant to the current feature. Irrelevant patterns are explicitly ignored, not force-applied. When a pattern is applied, the plan cites its source (e.g., "Based on ADR-003" or "Per planning pattern: always include QA with real data tests").

A complementary write side is added at the end of every `/plan_w_team` run: an `AskUserQuestion` prompt asking "Any planning patterns to remember?" If the user answers yes, the pattern is categorized and appended to `docs/planning-patterns.md`.

A `planning-patterns-agent` is added as the 7th parallel agent in the `/compound` pipeline. It analyzes the completed spec, extracts planning-level decisions (team composition, testing strategy, task ordering, scope), deduplicates against existing patterns, and appends new ones to `docs/planning-patterns.md`.

A dedicated `docs/planning-patterns.md` file is introduced (rather than expanding `CLAUDE.md`) to keep the system context lean while providing a structured, reviewable store for planning preferences.

Planning patterns are stored per-project because different projects have different conventions. The file lives in the project repo alongside `docs/adr/` and `docs/solutions/`.

## Consequences

**Positive:**

- Each planning cycle becomes incrementally smarter without requiring the user to repeat context from prior sessions.
- Plans now cite their sources, making it auditable which past learnings influenced a design decision.
- The compound engineering flywheel is complete: write side (`/compound` → docs/) and read side (docs/ → `/plan_w_team`) are both operational.
- Patterns are per-project, so cross-project noise is eliminated.

**Negative / Trade-offs:**

- First run on a new project produces no benefit (no patterns exist yet). This is handled gracefully: missing files and empty directories are skipped silently with no error.
- Planning step count increases from 8 to 9. The added step adds minor latency on projects with large knowledge stores.
- `docs/planning-patterns.md` requires occasional curation to remove outdated or conflicting patterns. No automated deduplication exists beyond exact-match checks in `planning-patterns-agent`.

**Neutral:**

- The Create Mode Report gains a "Learnings Applied" section that shows either the applied patterns with sources, or "No relevant past learnings found" when nothing was applied.
- The `planning-patterns-agent` runs in background parallel with the other 6 `/compound` agents, adding no wall-clock time to the compound pipeline.
