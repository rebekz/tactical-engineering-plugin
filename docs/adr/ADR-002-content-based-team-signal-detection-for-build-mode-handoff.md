---
id: ADR-002
title: "Content-Based Team Signal Detection for Build Mode Handoff"
date: 2026-02-20
status: accepted
deciders: [user, claude]
feature: knowledge-aware-planning-and-team-handoff
spec: specs/knowledge-aware-planning-and-team-handoff.md
---

# ADR-002: Content-Based Team Signal Detection for Build Mode Handoff

## Status

Accepted

## Context

Every spec produced by `/plan_w_team` includes a `### Team Members` section because it is part of the standard spec template. As a result, the presence of that heading alone cannot distinguish between a spec genuinely designed for team-mode execution (with named agents, roles, and agent-type assignments) and a spec where the section is present but unpopulated.

Prior to this change, the `/plan_w_team` handoff always suggested vanilla `/build specs/<file>.md` regardless of spec content. This created a systematic disconnect: the planning command explicitly designs for team coordination with named agents and role assignments, but the build suggestion at the end carried none of that intent forward. Users who designed team-mode specs were required to remember to append `--team` themselves.

Two alternatives to content-based detection were considered:

1. **Always show team-mode option** — Present `--team` as an option in the handoff for every spec. Rejected because it adds cognitive load and `--team` cost-implications to every planning session, including simple single-builder specs where team mode is irrelevant.

2. **Silently default to `--team`** — Automatically append `--team` when the `### Team Members` heading is present. Rejected because (a) it would false-positive on every unpopulated template, and (b) silently spawning multiple Claude sessions has cost implications the user should opt into explicitly.

The root cause of (2)'s false-positive problem is that the `### Team Members` heading exists in every spec template. A meaningful signal requires detecting actual member definitions, not just the heading.

Additionally, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set as an environment variable for team mode builds to work. At the time of the handoff decision, this env var may or may not be present. Discovering the missing env var only after the user selects "Build with --team" and the command errors is a poor experience.

## Decision

Scan the generated spec content for actual team member definitions under `### Team Members`, rather than checking for the heading alone. Define four positive signal patterns:

1. **Subheadings** — Lines starting with `####` (e.g., `#### Go Backend Builder`), indicating a named agent defined as a subsection.
2. **Name fields** — Lines containing `- **Name:**` followed by a non-empty value, indicating a structured agent definition block.
3. **Agent Type fields** — Lines containing `- **Agent Type:**` followed by a non-empty value, confirming an agent with an explicit type assignment.
4. **Table rows** — Lines containing `|` with agent type values (excluding separator rows matching `|---|`), indicating tabular agent definitions.

If ANY of these patterns match in the spec content, set `HAS_TEAM_SIGNALS = true`.

Additionally, check the environment at the same time: `AGENT_TEAMS_ENABLED = (process.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS === '1')`.

The handoff then branches on these two booleans:

- `HAS_TEAM_SIGNALS = true` — Present 5 options with "Build with --team" listed first:
  - If `AGENT_TEAMS_ENABLED = true`: "Build with --team" auto-runs `/build specs/<file>.md --team`
  - If `AGENT_TEAMS_ENABLED = false`: "Build with --team" shows setup instructions (the required `export` command, a reminder to restart Claude Code, and the manual command to run after)
  - Remaining options: "Build with subagents", "Refine orchestration", "Review plan", "Done for now"

- `HAS_TEAM_SIGNALS = false` — Present the existing 4-option handoff unchanged. No mention of `--team`.

This detection and branching logic applies uniformly to all four `/plan_w_team` entry modes: Create, Accept, Multi-Doc Merge, and BMad.

The static "When you're ready, execute the plan by running: /build specs/<filename>.md" line is removed from all four report templates. The handoff `AskUserQuestion` now owns the build suggestion exclusively, preventing the static line from contradicting the dynamic handoff options.

## Consequences

**Positive:**

- The correct build mode is surfaced automatically at the right time, eliminating user recall burden for the `--team` flag.
- False-positives on empty `### Team Members` sections are prevented. An unpopulated heading does not trigger the team-mode path.
- True-positives cover all real spec formats produced by `/plan_w_team`: subheading format, bold-field format, and table format.
- The env var check prevents a broken experience: users who lack `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` get setup instructions at the decision point rather than an error after committing to team mode.
- Non-team specs see no change to their handoff flow.

**Negative / Trade-offs:**

- Detection is heuristic-based and operates on text patterns in the rendered spec. If spec format conventions change (e.g., a new agent definition format is introduced), the detection patterns must be updated alongside.
- The 4-pattern detection is slightly over-broad: a spec that defines a single agent using any one of the four patterns will trigger `HAS_TEAM_SIGNALS = true`, even if team mode may not be the intended execution strategy. In practice this is acceptable because the handoff still requires explicit user confirmation before running `--team`.

**Neutral:**

- The handoff is now a two-part interaction: Part A captures planning patterns (fires after every plan creation), Part B is the conditional build handoff. The team signal detection runs between the report and Part A.
- Removing the static build suggestion from the 4 report templates (Create, Accept, Multi-Doc Merge, BMad) eliminates a minor redundancy that would have conflicted with the dynamic handoff options.
