---
date: 2026-02-28
topic: plan-w-team-brainstorm-enhancement
---

# Enhance plan-w-team with Brainstorm Capability and Research-Driven Planning

## What We're Building

Adding a `--brainstorm` flag to `plan-w-team` that triggers a collaborative brainstorm phase before planning, and enhancing the planning workflow with parallel research agents, detail level selection, and brainstorm auto-detection with cross-checking. Inspired by compound-engineering's brainstorming skill and plan workflow.

The brainstorm capability will be implemented as a reusable `skills/brainstorming/SKILL.md` that plan-w-team loads when `--brainstorm` is passed. The planning enhancements will be added inline to plan-w-team.md as a new research phase and detail level gate.

## Why This Approach

**Phased Extension** was chosen over skill-heavy delegation or hybrid approaches because:

- **Single-command flow**: Users get brainstorm-to-plan in one session without context switching. The `--brainstorm` flag makes it opt-in, preserving the current fast-path for users with clear requirements.
- **Reusable brainstorming skill**: Creating `skills/brainstorming/SKILL.md` means `/party` and future commands can also use the same brainstorm logic.
- **Plan enhancements are spec-specific**: Research agents, detail levels, and cross-checking are tightly coupled to plan-w-team's 7-section spec format, so they belong inline rather than in a generic planning skill.

We considered:
- **Separate brainstorm command**: More decoupled but adds command bloat and context switching. Rejected because tactical-engineering already has many commands.
- **Skill-heavy delegation**: Maximum reusability but adds indirection. The planning logic is too spec-format-specific to generalize well.

## Key Decisions

- **Integration**: `--brainstorm` flag on plan-w-team (not a separate command)
- **Brainstorm skill**: New `skills/brainstorming/SKILL.md` following compound-engineering's pattern (4-phase: assess clarity, understand idea, explore approaches, capture design)
- **Brainstorm output**: Saved to `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md` with YAML frontmatter
- **Research agents**: Enable `Agent` tool in plan-w-team (keep `Task` disallowed). Spawn `repo-research-analyst` (or context-gatherer) and learnings-researcher in parallel before planning
- **Detail levels**: Three levels (MINIMAL/MORE/A LOT) controlling depth within existing 7 required sections, not additional sections. All 7 sections always present per Stop hook validation
- **Auto-detect**: plan-w-team scans `docs/brainstorms/` for recent files matching the topic (14-day window, semantic match on frontmatter `topic:` field)
- **Cross-check**: Final review step ensures every brainstorm decision is reflected in the spec. Origin field added to spec frontmatter pointing back to brainstorm file
- **YAGNI enforcement**: Brainstorming skill includes explicit YAGNI principles and anti-patterns table (from compound-engineering's approach)
- **Question style**: One question at a time via AskUserQuestion, prefer multiple choice, start broad then narrow

## Resolved Questions

- **Spec-flow-analyzer in brainstorm?** Yes - run spec-flow-analyzer after brainstorm capture to validate user flow completeness before handoff to planning. This catches gaps early.
- **Detail level input method?** Interactive via AskUserQuestion during planning phase. More discoverable for users, and brainstorming is already an interactive flow so consistency matters.
- **--brainstorm + --ralph combo?** No - keep them separate. Brainstorming requires human judgment and interactive dialogue that doesn't fit the automated ralph loop. Users should brainstorm, then plan, then separately decide to --ralph the build.

## Scope Summary

### New Files
- `skills/brainstorming/SKILL.md` - Reusable brainstorming skill (4-phase dialogue, YAGNI, anti-patterns, document template)

### Modified Files
- `commands/plan-w-team.md` - Add --brainstorm flag, research agents phase, detail level selection, brainstorm auto-detect + cross-check, spec-flow analysis
- `commands/plan-w-team.md` frontmatter - Add Agent to allowed-tools

### Output Artifacts
- `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md` - Brainstorm capture documents
- `specs/<name>.md` - Enhanced specs with origin field pointing to brainstorm, depth controlled by detail level

## Next Steps

-> `/workflows:plan` for implementation details
