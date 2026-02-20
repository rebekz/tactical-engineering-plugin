---
title: "feat: Smart team-mode handoff in plan-w-team"
type: feat
status: active
date: 2026-02-20
---

# feat: Smart team-mode handoff in plan-w-team

## Overview

After `/plan-w-team` creates a spec, detect whether it contains actual team member definitions and surface a team-mode build option in the handoff. Currently, the handoff always suggests vanilla `/build` — even when the spec was explicitly designed for team-mode execution with named agents and role assignments.

## Problem Statement

The `/plan-w-team` command produces specs with `## Team Orchestration` sections containing named team members, agent types, and role assignments — all designed for `--team` mode. But the handoff (lines 810-849 of `plan-w-team.md`) ignores this context and always suggests plain `/build specs/<file>.md`. Users must remember to add `--team` themselves, creating a disconnect between planning and execution.

## Proposed Solution

Add team-signal detection after the plan report, then conditionally expand the handoff from 4 options to 5 options when team signals are found. The extra option is "Build with --team" as the first choice. When the required env var is missing, show the build command as copyable text instead of auto-running.

### Detection Logic

Since `## Team Orchestration` and `### Team Members` headings are **required** by the stop hook (`validate_file_contains.py`) in every spec, heading-only detection would always trigger. Instead, detection scans for **actual team member content** inside the `### Team Members` section:

**Positive signals** (any one triggers):
- `#### <Name>` subheadings under Team Members (e.g., `#### Go Backend Builder`)
- `- **Name:**` lines with a value
- `- **Agent Type:**` lines with a value
- Table rows with `|` containing agent type assignments (e.g., `| builder-backend | general-purpose |`)

**Not a signal** (heading-only, no content):
```markdown
### Team Members

<Define team based on tech stack from architecture>
```

### Handoff Flow

**When team signals detected** — expand to 5 options:

```
AskUserQuestion({
  questions: [{
    question: "Plan with team captured. What would you like to do next?",
    header: "Next Steps",
    options: [
      {
        label: "Build with --team",
        description: <dynamic - see env var handling below>
      },
      {
        label: "Build with subagents",
        description: "Run /build in default subagent mode (no Agent Teams)"
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

**When NO team signals detected** — existing 4-option handoff unchanged (Proceed to build / Refine / Review / Done).

### Env Var Handling

Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` before presenting the handoff:

- **Env var IS set (`=1`)**: "Build with --team" description = `"Run /build --team to execute with Agent Teams (team members communicate directly and self-claim tasks)"`
  - On selection: auto-run `/build specs/<filename>.md --team`

- **Env var NOT set**: "Build with --team" description = `"Agent Teams detected but env var not set. Select to see setup instructions."`
  - On selection: show copyable instructions instead of auto-running:
    ```
    Team mode requires the experimental flag. Set it up:
    1. Run: export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
    2. Restart Claude Code
    3. Then run: /build specs/<filename>.md --team
    ```

### Report Text Update

Remove the static `"When you're ready, execute the plan by running: /build specs/<filename>.md"` line from all four report formats (Create, Accept, Multi-Doc Merge, BMad). The handoff `AskUserQuestion` now handles the build suggestion, making this line redundant and potentially contradictory.

## Acceptance Criteria

- [ ] Team signals detected + env var set → handoff shows 5 options with "Build with --team" first, auto-runs on selection
- [ ] Team signals detected + env var missing → handoff shows 5 options, "Build with --team" shows setup instructions on selection (no auto-run)
- [ ] No team signals → existing 4-option handoff unchanged
- [ ] User picks "Build with subagents" → runs `/build specs/<file>.md` without `--team`
- [ ] User picks "Refine/Review/Done" → existing behavior preserved
- [ ] Detection does NOT false-positive on empty `### Team Members` sections (heading-only with placeholder text)
- [ ] Detection DOES trigger on all real team member formats: subheading (`####`), bold fields (`- **Name:**`), and table rows
- [ ] Static "When you're ready..." build suggestion removed from all 4 report formats
- [ ] All 4 entry modes (Create, Accept, Multi-Doc Merge, BMad) use the same detection + handoff logic

## File Changes

### `plugins/tactical-engineering/commands/plan-w-team.md`

This is the **only file** that needs modification. Three areas:

#### 1. Report sections (lines ~691-808)

Remove the trailing build suggestion from each report format:

```markdown
# REMOVE from Create (line ~710), Accept (~732), Multi-Doc (~758), BMad (~785):
When you're ready, execute the plan by running:
/build specs/<filename>.md
```

#### 2. New detection logic (insert before Handoff, ~line 810)

Add a section between the report and the handoff:

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

#### 3. Handoff section (lines ~810-849)

Replace the existing static handoff with conditional logic:

```markdown
## Handoff

### If HAS_TEAM_SIGNALS is true:

<5-option AskUserQuestion as specified above>

Behavior:
- "Build with --team":
  - If AGENT_TEAMS_ENABLED: run `/build specs/<filename>.md --team`
  - If NOT AGENT_TEAMS_ENABLED: show setup instructions (export + restart + manual command)
- "Build with subagents": run `/build specs/<filename>.md`
- "Refine orchestration": continue planning mode
- "Review plan": open the plan file
- "Done for now": provide summary and exit

### If HAS_TEAM_SIGNALS is false:

<existing 4-option AskUserQuestion unchanged>

Behavior:
- "Proceed to build": run `/build specs/<filename>.md`
- "Refine orchestration": continue planning mode
- "Review plan": open the plan file
- "Done for now": provide summary and exit
```

## References

- Brainstorm: `docs/brainstorms/2026-02-20-plan-w-team-build-mode-handoff-brainstorm.md`
- Target file: `plugins/tactical-engineering/commands/plan-w-team.md:810-849`
- Build --team detection: `plugins/tactical-engineering/commands/build.md:29-49`
- Env var pattern: `plugins/tactical-engineering/commands/party.md:26-32`
- Stop hook (required sections): `plugins/tactical-engineering/commands/plan-w-team.md:16-27`
