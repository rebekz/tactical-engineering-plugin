# Planning Patterns

This file stores reusable planning patterns learned from past sessions. It is read by `/plan_w_team` during the "Review Past Learnings" step and written by `/compound` via the planning-patterns-agent.

## Team Composition

### Single Builder for Overlapping File Edits
When tasks modify overlapping sections of the same file, assign a single general-purpose builder agent and run tasks sequentially. Parallel agents on the same file create merge conflicts and ordering bugs.
- **When to apply:** Two or more tasks touch the same file at adjacent or interdependent line ranges (e.g., inserting a step, renumbering subsequent steps, then modifying a downstream section that references those steps).
- **Source:** specs/knowledge-aware-planning-and-team-handoff.md, 2026-02-20

## Testing Strategy

<!-- Patterns will be added here by /compound -->

## Architecture Patterns

### Merge Related Features That Touch the Same File Sections
When two distinct features both require edits to overlapping sections of the same file, merge them into a single spec rather than building them in separate PRs. Separate specs on the same overlapping regions force sequential spec execution anyway and risk double-editing the same lines.
- **When to apply:** Two planned features share a target file AND their change regions are adjacent or interdependent (e.g., both modify the same command's workflow steps and handoff section).
- **Source:** specs/knowledge-aware-planning-and-team-handoff.md, 2026-02-20

## Workflow Preferences

### Parallel Tasks Only for Independent New Files
Tasks that create brand-new files with no shared line ranges can run in parallel. Tasks that insert into, renumber, or reference sections of an existing shared file must run sequentially, with each task explicitly depending on the one before it.
- **When to apply:** Whenever the task list contains a mix of "create new file" tasks and "modify existing file" tasks targeting the same command or agent file. Parallelize the new-file creations; serialize the edits.
- **Source:** specs/knowledge-aware-planning-and-team-handoff.md, 2026-02-20
