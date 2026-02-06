---
title: "feat: Add Party Mode Multi-Agent Lifecycle Command"
type: feat
date: 2026-02-06
---

# feat: Add Party Mode Multi-Agent Lifecycle Command

## Overview

Create a `/party` command that uses Claude Agent Teams to run a full product team (PM, Architect, Backend Dev, Frontend Dev, QA, UX, Tech Writer, DevOps) through brainstorm → plan → build → validate phases. The lead orchestrates and synthesizes, presenting consolidated output to the user with checkpoints between phases. This complements `/build` (spec-first implementation) with an idea-first full-lifecycle workflow.

## Problem Statement / Motivation

Currently the tactical-engineering-plugin requires a manual multi-step workflow:
1. `/workflows:brainstorm` → separate command, single-agent
2. `/plan_w_team` → separate command, single-agent
3. `/build --team` → Agent Teams, but only for implementation

Users must manually bridge each step, losing context between phases. Party mode provides a single invocation from idea to implementation with a persistent multi-agent team that builds shared understanding throughout.

Inspired by BMAD Method's "party mode" (single-LLM persona simulation), but implemented with real separate Claude instances for true parallel research and execution.

## Proposed Solution

A new `/party` command that:
1. Spawns a team of 8 specialist agents via Agent Teams
2. Orchestrates them through 4 phases: BRAINSTORM → PLAN → BUILD → VALIDATE
3. Lead synthesizes multi-agent output and presents to user at checkpoints
4. Produces a `/build`-compatible spec during the plan phase
5. Reuses existing `state-file.js` helpers with party-specific extensions
6. Supports interruption and resume via `/continue-spec`

## Technical Approach

### Architecture

```
User → /party "topic" → Lead Agent (this session)
                              │
                              ├── Phase 1: BRAINSTORM
                              │   └── Spawns 8 teammates via TeamCreate
                              │       Each researches topic from their expertise
                              │       Lead collects via SendMessage, synthesizes
                              │       User checkpoint: approve findings
                              │
                              ├── Phase 2: PLAN
                              │   └── Architect proposes design (message to lead)
                              │       PM creates stories (message to lead)
                              │       Devs scope tasks (message to lead)
                              │       QA defines test strategy (message to lead)
                              │       Lead assembles spec, presents to user
                              │       User checkpoint: approve plan
                              │
                              ├── Phase 3: BUILD
                              │   └── Lead creates TaskList from spec
                              │       Agents self-claim tasks
                              │       Inter-agent messaging for coordination
                              │       Lead monitors, resolves blockers
                              │       (Reuses /build Phase 4-8 logic)
                              │
                              └── Phase 4: VALIDATE
                                  └── QA runs validation commands
                                      Docs writes documentation
                                      DevOps checks deployment readiness
                                      Lead presents completion report
                                      User checkpoint: approve results
```

### Files to Create

| File | Purpose |
|------|---------|
| `plugins/tactical-engineering/commands/party.md` | Main command definition |
| `plugins/tactical-engineering/agents/party-pm-agent.md` | Product Manager persona |
| `plugins/tactical-engineering/agents/party-architect-agent.md` | System Architect persona |
| `plugins/tactical-engineering/agents/party-backend-agent.md` | Backend Developer persona |
| `plugins/tactical-engineering/agents/party-frontend-agent.md` | Frontend Developer persona |
| `plugins/tactical-engineering/agents/party-qa-agent.md` | QA Engineer persona |
| `plugins/tactical-engineering/agents/party-ux-agent.md` | UX Designer persona |
| `plugins/tactical-engineering/agents/party-docs-agent.md` | Tech Writer persona |
| `plugins/tactical-engineering/agents/party-devops-agent.md` | DevOps Engineer persona |

### Files to Modify

| File | Changes |
|------|---------|
| `plugins/tactical-engineering/scripts/state-file.js` | Add `mode: "party"` support, party-specific state fields |
| `plugins/tactical-engineering/commands/continue-spec.md` | Add party-mode phase detection and resume logic |
| `plugins/tactical-engineering/commands/status.md` | Add party-mode phase display |
| `COMMANDS.md` | Document `/party` command |

### Implementation Phases

#### Phase 1: State File Extensions

Extend `state-file.js` to support party mode:

```javascript
// createInitialState gains party-specific fields when mode === "party"
{
  build: {
    specPath: "specs/party-<topic>.md",
    specChecksum: null, // Set when plan phase produces spec
    startedAt: "ISO",
    lastUpdated: "ISO",
    completedAt: null,
    totalTasks: 0, // Set when build phase creates tasks
    mode: "party",
    teamName: "party-<topic>"
  },
  party: {
    topic: "Build user authentication with OAuth",
    currentPhase: 1, // 1=brainstorm, 2=plan, 3=build, 4=validate
    phases: [
      {
        phase: 1,
        name: "brainstorm",
        startedAt: "ISO",
        completedAt: null,
        status: "in-progress", // pending | in-progress | completed | skipped
        artifacts: [],
        userApproval: null // { approved: true, feedback: "...", timestamp: "ISO" }
      }
    ],
    roster: [
      {
        role: "Product Manager",
        name: "pm",
        teammateName: "pm", // Matches SendMessage recipient
        agentType: "party-pm-agent",
        model: "sonnet"
      }
      // ... 7 more
    ],
    brainstormSummary: null, // Path to summary artifact
    planPath: null, // Path to generated spec
    context: {
      keyDecisions: [], // Carried across phases for resume
      architectureChoices: [],
      constraints: []
    }
  },
  tasks: [], // Populated in Phase 3 (BUILD)
  artifacts: [],
  validation: {
    commandsRun: [],
    acceptanceCriteria: []
  }
}
```

**Key additions to `state-file.js`:**
- `createInitialState(specPath, tasks, mode)` → handle `mode === "party"` with party-specific fields
- `updatePartyPhase(specPath, phase, updates)` → helper to transition phases
- `getPartyPhase(state)` → extract current phase number
- Backward compatibility: states without `party` field are treated as subagent/team mode

#### Phase 2: Party Agent Definitions (8 agents)

Each party agent wraps a general-purpose agent with persona context and phase-specific instructions. Example structure:

```yaml
---
name: party-pm-agent
description: Product Manager agent for Party Mode. Researches requirements, creates user stories, defines acceptance criteria.
tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, WebFetch, WebSearch, AskUserQuestion
model: sonnet
permissionMode: default
color: blue
---

# Party PM Agent

## Persona

You are the **Product Manager** on a multi-agent product team.
Your expertise: requirements gathering, user stories, acceptance criteria, stakeholder analysis.

## Phase Responsibilities

### Phase 1: BRAINSTORM
- Research user needs and market context for the topic
- Identify stakeholders and user personas
- Define success criteria and constraints
- Message the lead with your findings in this format:
  **PM Research Findings:**
  - User Needs: [bullet points]
  - Stakeholders: [who is affected]
  - Success Criteria: [measurable outcomes]
  - Constraints: [technical, business, time]

### Phase 2: PLAN
- Create user stories from the brainstorm findings
- Define acceptance criteria for each story
- Prioritize stories into epics
- Message the lead with stories in this format:
  **PM Plan Contribution:**
  - Epic 1: [name]
    - Story 1.1: As a [user], I want [feature] so that [benefit]
      - AC: [acceptance criteria]

### Phase 3: BUILD
- Available for clarifying requirements during implementation
- Review task outputs for requirement alignment
- Claim documentation-adjacent tasks if available

### Phase 4: VALIDATE
- Verify acceptance criteria are met
- Review user-facing documentation for accuracy
- Provide final sign-off on requirements coverage

## Communication
- Always message the lead (not other teammates directly) with structured findings
- Use the format specified for each phase
- Be concise but thorough
- Flag risks and trade-offs explicitly
```

**Agent roster with phase assignments:**

| Agent | Color | Primary Phases | Secondary Phases |
|-------|-------|---------------|------------------|
| `party-pm-agent` | blue | 1 (Brainstorm), 2 (Plan) | 4 (Validate) |
| `party-architect-agent` | purple | 1 (Brainstorm), 2 (Plan), 3 (Build) | 4 (Validate) |
| `party-backend-agent` | green | 2 (Plan), 3 (Build) | 1 (Brainstorm) |
| `party-frontend-agent` | yellow | 2 (Plan), 3 (Build) | 1 (Brainstorm) |
| `party-qa-agent` | red | 2 (Plan), 3 (Build), 4 (Validate) | 1 (Brainstorm) |
| `party-ux-agent` | cyan | 1 (Brainstorm), 2 (Plan) | 4 (Validate) |
| `party-docs-agent` | orange | 3 (Build), 4 (Validate) | 2 (Plan) |
| `party-devops-agent` | orange | 3 (Build), 4 (Validate) | 2 (Plan) |

#### Phase 3: Party Command Definition

`plugins/tactical-engineering/commands/party.md` - the main orchestration command.

**YAML frontmatter:**
```yaml
---
name: party
description: Run a full product team through brainstorm → plan → build → validate using Agent Teams. Start from an idea, end with implementation.
argument-hint: [topic-description]
model: opus
allowed-tools: Task, TaskOutput, Bash, Glob, Grep, Read, Edit, Write, NotebookEdit, WebFetch, WebSearch, AskUserQuestion, Skill, TodoWrite, TeamCreate, TeamDelete, SendMessage
---
```

**Command structure (phases):**

##### Phase 0: Prerequisites & Resume Detection
```
1. Check CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1, abort if not set
2. Parse topic from $1 argument
3. Sanitize topic to kebab-case for state/team naming
4. Check for existing state at .claude/specs/party-<topic>/state.json
   - If exists and mode === "party":
     - Show current phase and progress
     - AskUserQuestion: Resume from Phase N / Start fresh / Abort
   - If exists and mode !== "party":
     - Warn: existing non-party state for this topic
     - AskUserQuestion: Overwrite / Choose different name / Abort
5. If fresh start: createInitialState with mode: "party"
```

##### Phase 1: Team Setup
```
1. Cost confirmation: "Party Mode spawns 8 specialist agents. This uses
   significantly more tokens than single-agent workflows. Proceed?"
2. TeamCreate({ team_name: "party-<topic>", description: "Party: <topic>" })
3. Spawn 8 teammates:
   for each agent in roster:
     Task({
       team_name: "party-<topic>",
       name: agent.name, // e.g., "pm", "architect"
       subagent_type: agent.agentType, // e.g., "party-pm-agent"
       model: agent.model, // default: sonnet
       prompt: `You are the ${agent.role} on a party mode team.
Topic: "${topic}"

Phase: BRAINSTORM
Your task: Research this topic from your expertise domain.
${agent.phaseInstructions.brainstorm}

When done, message the lead with your findings using SendMessage.
Format your findings with a clear header: **${agent.role} Research Findings:**

After sending findings, wait for the lead to give you the next phase instructions.`
     })
4. Save state: update roster with teammateName values
```

##### Phase 2: BRAINSTORM
```
1. Update state: party.currentPhase = 1, phases[0].status = "in-progress"
2. Wait for all 8 agents to send their research findings
   - Messages arrive automatically via SendMessage
   - Track received: checklist of 8 agents
   - Timeout: if agent hasn't reported in 5 minutes, send check-in
3. Synthesize findings into round-table summary:
   - Key themes across all perspectives
   - Points of agreement
   - Points of disagreement / trade-offs
   - Recommended decisions
4. Write brainstorm artifact to .claude/specs/party-<topic>/brainstorm-summary.md
5. Save state: party.brainstormSummary = artifact path
6. Present synthesis to user via formatted output
7. User checkpoint:
   AskUserQuestion: "Brainstorm complete. What next?"
   - Proceed to Planning (recommended)
   - Refine: tell agents to dig deeper on [topic]
   - Adjust scope: provide new constraints
   - Abort: shut down team
8. If "Refine": message specific agents with user feedback, loop back to step 2
9. If "Proceed": update state: phases[0].status = "completed", phases[0].userApproval = true
10. Save key decisions to party.context.keyDecisions for cross-phase context
```

##### Phase 3: PLAN
```
1. Update state: party.currentPhase = 2, phases[1].status = "in-progress"
2. Message all 8 agents with Phase 2 instructions:
   SendMessage({
     type: "message",
     recipient: agent.name,
     content: `Phase: PLAN
Context from brainstorm:
${brainstormSummary}

Key decisions: ${keyDecisions}

Your planning task:
${agent.phaseInstructions.plan}

Message the lead when your contribution is ready.`,
     summary: "Phase 2 PLAN instructions"
   })
3. Collect planning contributions from agents:
   - Architect: high-level architecture, component design, tech stack
   - PM: user stories with acceptance criteria, organized into epics
   - Backend/Frontend: technical task breakdown with file assignments
   - QA: test strategy, edge cases, validation commands
   - UX: user flow descriptions, interaction patterns
   - Docs: documentation plan
   - DevOps: deployment strategy, infrastructure needs
4. Assemble into /build-compatible spec format:
   Write spec to specs/party-<topic>.md with sections:
   - ## Overview (from brainstorm synthesis)
   - ## Architecture (from Architect)
   - ## Team Members (from party roster, mapped to agent types)
   - ## Step by Step Tasks (from PM stories + dev task breakdown)
     - Each task has: Description, Assigned To, Dependencies, AC
   - ## Validation Commands (from QA)
   - ## Acceptance Criteria (from PM + QA)
5. Save state: party.planPath = "specs/party-<topic>.md"
6. Update state: build.specPath = party.planPath
7. Present plan to user via formatted output
8. User checkpoint:
   AskUserQuestion: "Plan assembled. What next?"
   - Proceed to Build (recommended)
   - Edit plan: open spec for manual edits
   - Revise: tell agents to adjust [specific section]
   - Abort: shut down team
9. If "Edit plan": open file, then ask user to confirm when done editing
10. If "Proceed": update state: phases[1] completed, userApproval = true
11. Calculate spec checksum, save to build.specChecksum
```

##### Phase 4: BUILD
```
1. Update state: party.currentPhase = 3, phases[2].status = "in-progress"
2. Parse tasks from the generated spec (same as /build Phase 1)
3. Create TaskList: TaskCreate for each task
4. Set dependencies: TaskUpdate with addBlockedBy
5. Save state: build.totalTasks = N, populate tasks array
6. Message agents with Phase 3 instructions:
   SendMessage to each: "Phase: BUILD. Check TaskList for available tasks.
   Claim tasks matching your expertise. Coordinate via messaging."
7. Assign initial unblocked tasks to matching agents:
   For each unblocked task, find best agent match, TaskUpdate with owner
8. Monitor via automatic message delivery:
   - Process task completion messages
   - Update state file on each completion
   - Run per-task validation hooks if defined in spec
   - Reassign/unblock dependent tasks
   - Detect stalled agents (5 min no message) → check-in
9. When all tasks complete: update phases[2] completed
```

##### Phase 5: VALIDATE
```
1. Update state: party.currentPhase = 4, phases[3].status = "in-progress"
2. Message QA agent: "Phase: VALIDATE. Run the validation commands from spec."
3. Message Docs agent: "Phase: VALIDATE. Write/update documentation."
4. Message DevOps agent: "Phase: VALIDATE. Check deployment readiness."
5. Collect validation results from agents
6. Compile completion report:
   - Phase summary (time per phase)
   - Tasks completed: N/N
   - Validation results
   - Documentation status
   - Deployment readiness
   - Files modified
   - Key decisions made
7. Present to user
8. User checkpoint:
   AskUserQuestion: "Party complete! What next?"
   - Accept and finish
   - Re-run validation
   - Fix issues: loop back to build for specific tasks
   - Run /compound to document learnings
9. Update state: phases[3] completed, build.completedAt
```

##### Phase 6: Cleanup
```
1. Send shutdown_request to all 8 teammates
2. Wait for shutdown_response (30s timeout per agent)
3. TeamDelete()
4. Final state save
5. Print completion report with state file location
```

#### Phase 4: Continue-Spec Integration

Extend `continue-spec.md` to handle party-mode state:

```
// In Phase 1.5 (Mode Detection):
if (state.build.mode === "party") {
  const currentPhase = state.party.currentPhase
  const phaseName = ["brainstorm", "plan", "build", "validate"][currentPhase - 1]

  console.log(`Party mode detected. Current phase: ${currentPhase} (${phaseName})`)

  // Agent Teams don't support session resumption
  // Must create fresh team
  console.log("Creating fresh team for party resume...")

  // Respawn team with context from state
  TeamCreate({ team_name: state.build.teamName, description: `Party resume: ${state.party.topic}` })

  // Spawn agents with phase-appropriate instructions
  for (const agent of state.party.roster) {
    Task({
      team_name: state.build.teamName,
      name: agent.name,
      subagent_type: agent.agentType,
      prompt: `You are resuming a party-mode session.
Topic: "${state.party.topic}"
Current Phase: ${phaseName}

Context from previous phases:
${JSON.stringify(state.party.context)}

${currentPhase === 3 ? "Check TaskList for remaining tasks." : "Wait for lead instructions."}
`
    })
  }

  // Jump to appropriate phase in party command logic
  // Phase 1 or 2 incomplete → restart that phase
  // Phase 3 incomplete → resume build (filter to pending tasks)
  // Phase 4 incomplete → restart validation
}
```

#### Phase 5: Status Command Extension

Extend `status.md` to display party-mode information:

```
// If state.build.mode === "party":
// Show:
// - Current phase with progress bar
// - Phase history table
// - Active agents and their current activity
// - Key decisions log
// - Artifacts produced

Party Mode: "Build user authentication with OAuth"
Phase: 3/4 (BUILD) ███████░░░░ 70%

Phase History:
| Phase | Status | Duration | Artifacts |
|-------|--------|----------|-----------|
| 1. Brainstorm | ✅ Complete | 3m 42s | brainstorm-summary.md |
| 2. Plan | ✅ Complete | 5m 18s | specs/party-user-auth.md |
| 3. Build | 🔄 In Progress | 8m 12s | 7/10 tasks done |
| 4. Validate | ⏳ Pending | - | - |

Active Agents:
| Name | Role | Current Task | Status |
|------|------|-------------|--------|
| pm | Product Manager | (idle) | Waiting |
| architect | System Architect | Task 8: API Gateway | Building |
| backend | Backend Developer | Task 9: Auth Service | Building |
| frontend | Frontend Developer | Task 7: Login UI | Building |
| qa | QA Engineer | (idle) | Waiting for build |
| ux | UX Designer | (idle) | Waiting |
| docs | Tech Writer | (idle) | Waiting for validate |
| devops | DevOps Engineer | (idle) | Waiting for validate |
```

## Acceptance Criteria

### Functional Requirements

- [ ] `/party "topic"` spawns 8 specialist agents via Agent Teams
- [ ] Lead orchestrates through 4 phases: brainstorm → plan → build → validate
- [ ] User checkpoints between each phase with approve/refine/abort options
- [ ] Brainstorm phase: all agents research in parallel, lead synthesizes
- [ ] Plan phase: agents contribute from their expertise, lead assembles spec
- [ ] Spec produced in Phase 2 is compatible with `/build` format
- [ ] Build phase: reuses TaskList/self-claim/monitor pattern from `/build --team`
- [ ] Validate phase: QA validates, Docs documents, DevOps checks deployment
- [ ] State persists to `.claude/specs/party-<topic>/state.json` with `mode: "party"`
- [ ] Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable
- [ ] `/continue-spec` can resume party-mode from any phase
- [ ] `/status` displays party-mode phase information
- [ ] Team cleanup (shutdown + TeamDelete) on completion or abort

### Non-Functional Requirements

- [ ] Cost confirmation prompt before spawning 8 agents
- [ ] Stalled agent detection with 5-minute timeout
- [ ] State file backward compatible (old states unaffected)
- [ ] Phase context (key decisions) persisted for cross-phase resume

## Dependencies & Risks

### Dependencies
- Claude Agent Teams experimental feature enabled
- Existing `state-file.js` helper functions
- Existing `/build` command's Phase 4-8 logic (referenced, not duplicated)

### Risks
- **Token cost**: 8 agents active simultaneously is expensive. Mitigation: cost confirmation, use Sonnet for most agents.
- **Agent Teams limitations**: No session resumption, no nested teams, one team per session. Mitigation: state-based resume with fresh team creation.
- **File conflicts**: Multiple agents editing same files during build. Mitigation: plan phase assigns different files to different agents.
- **Message volume**: 8 agents all messaging lead simultaneously. Mitigation: structured message formats, lead processes sequentially.

## Step by Step Tasks

### Team Members

| Name | Role | Agent Type |
|------|------|------------|
| state-builder | State File Extensions | general-purpose |
| agent-creator | Party Agent Definitions | general-purpose |
| command-builder | Party Command Implementation | general-purpose |
| integrator | Integration Updates | general-purpose |

### Tasks

#### Task 1: Extend state-file.js for party mode
- **Description**: Add `mode: "party"` support to `createInitialState()`. Add `party` object with `currentPhase`, `phases[]`, `roster[]`, `brainstormSummary`, `planPath`, and `context` fields. Add `updatePartyPhase()` and `getPartyPhase()` helper functions. Ensure backward compatibility: states without `party` field treated as subagent/team.
- **Assigned To**: state-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/scripts/state-file.js`
- **Dependencies**: None
- **AC**:
  - createInitialState with mode="party" produces party-specific fields
  - updatePartyPhase transitions phases correctly
  - Existing tests/behavior for subagent and team modes unaffected

#### Task 2: Create party-pm-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-pm-agent.md` with YAML frontmatter (name, description, tools, model: sonnet, color: blue) and phase-specific instructions for brainstorm (research requirements), plan (create user stories with AC), build (clarify requirements), validate (verify AC coverage). Use structured message format for lead communication.
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-pm-agent.md`
- **Dependencies**: None
- **AC**: Valid YAML frontmatter, phase instructions for all 4 phases, structured message format

#### Task 3: Create party-architect-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-architect-agent.md`. Expertise: architecture, patterns, tech decisions. Brainstorm: research existing patterns, propose approaches. Plan: design component architecture, define tech stack. Build: implement core infrastructure, review PRs. Validate: verify architecture compliance.
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-architect-agent.md`
- **Dependencies**: Task 2 (follow same format)
- **AC**: Valid agent definition with all 4 phase instructions

#### Task 4: Create party-backend-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-backend-agent.md`. Expertise: APIs, business logic, databases. Secondary in brainstorm (feasibility), primary in plan (task scoping) and build (implementation).
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-backend-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with phase instructions

#### Task 5: Create party-frontend-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-frontend-agent.md`. Expertise: UI, components, user experience implementation. Pattern mirrors backend agent.
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-frontend-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with phase instructions

#### Task 6: Create party-qa-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-qa-agent.md`. Expertise: testing strategy, edge cases, validation. Active in all phases: brainstorm (risk assessment), plan (test strategy), build (test implementation), validate (run validation).
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-qa-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with all 4 phase instructions

#### Task 7: Create party-ux-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-ux-agent.md`. Expertise: user flows, accessibility, interaction design. Primary in brainstorm and plan, secondary in validate.
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-ux-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with phase instructions

#### Task 8: Create party-docs-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-docs-agent.md`. Expertise: documentation, developer guides. Primary in build (write docs) and validate (review docs).
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-docs-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with phase instructions

#### Task 9: Create party-devops-agent
- **Description**: Create `plugins/tactical-engineering/agents/party-devops-agent.md`. Expertise: CI/CD, deployment, infrastructure. Primary in build (deployment config) and validate (deployment readiness).
- **Assigned To**: agent-creator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/agents/party-devops-agent.md`
- **Dependencies**: Task 2
- **AC**: Valid agent definition with phase instructions

#### Task 10: Create party.md command - Phase 0-1 (Prerequisites, Team Setup)
- **Description**: Create `plugins/tactical-engineering/commands/party.md` with YAML frontmatter and implement Phase 0 (prerequisites check, resume detection, topic parsing, state initialization) and Phase 1 (cost confirmation, TeamCreate, spawn 8 teammates with brainstorm instructions). Reference state-file.js helpers for state management.
- **Assigned To**: command-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/party.md`
- **Dependencies**: Task 1 (state file), Task 2-9 (agent definitions)
- **AC**: Command accepts topic argument, checks prerequisites, creates team, spawns 8 agents

#### Task 11: Create party.md command - Phase 2 (BRAINSTORM)
- **Description**: Add Phase 2 to party.md: collect research findings from 8 agents via automatic message delivery, synthesize into round-table summary, write brainstorm artifact, present to user with checkpoint (Proceed/Refine/Adjust/Abort). Track received findings with checklist, timeout at 5 minutes with check-in. Save key decisions to state.party.context.
- **Assigned To**: command-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/party.md`
- **Dependencies**: Task 10
- **AC**: Brainstorm phase collects from all agents, synthesizes, presents checkpoint

#### Task 12: Create party.md command - Phase 3 (PLAN)
- **Description**: Add Phase 3 to party.md: message agents with plan-phase instructions including brainstorm context, collect planning contributions (architecture from Architect, stories from PM, tasks from devs, test strategy from QA, UX flows, docs plan, deployment strategy), assemble into /build-compatible spec at specs/party-<topic>.md with standard sections (Overview, Architecture, Team Members, Step by Step Tasks, Validation Commands, Acceptance Criteria). Present to user with checkpoint.
- **Assigned To**: command-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/party.md`
- **Dependencies**: Task 11
- **AC**: Plan phase produces /build-compatible spec, user checkpoint works

#### Task 13: Create party.md command - Phase 4 (BUILD)
- **Description**: Add Phase 4 to party.md: parse tasks from generated spec, create TaskList, set dependencies, message agents with build instructions, assign initial tasks to matching agents, monitor via message delivery with state updates on each completion, per-task validation hooks, stalled agent detection at 5 min. Reuse /build Phase 4-8 patterns (not literal invocation, but same logic pattern).
- **Assigned To**: command-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/party.md`
- **Dependencies**: Task 12
- **AC**: Build phase creates tasks, agents self-claim, lead monitors to completion

#### Task 14: Create party.md command - Phase 5-6 (VALIDATE + Cleanup)
- **Description**: Add Phase 5 (VALIDATE): message QA/Docs/DevOps with validation instructions, collect results, compile completion report. Add Phase 6 (Cleanup): send shutdown_request to all agents, wait 30s, TeamDelete, final state save. Present completion report with phase timing, tasks completed, validation results, files modified.
- **Assigned To**: command-builder
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/party.md`
- **Dependencies**: Task 13
- **AC**: Validation runs, cleanup shuts down team, completion report shown

#### Task 15: Update continue-spec.md for party mode
- **Description**: Extend continue-spec.md Phase 1.5 (Mode Detection) to handle `mode === "party"`. Read party.currentPhase from state, create fresh team (Agent Teams don't support session resumption), spawn agents with phase-appropriate instructions and cross-phase context from state.party.context, jump to correct phase in party workflow. Handle edge cases: incomplete phase → restart that phase, build phase → filter to pending tasks only.
- **Assigned To**: integrator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/continue-spec.md`
- **Dependencies**: Task 1, Task 14 (full party command)
- **AC**: `/continue-spec` detects party mode, resumes at correct phase

#### Task 16: Update status.md for party mode
- **Description**: Extend status.md to display party-mode information: current phase with progress indicator, phase history table (phase/status/duration/artifacts), active agents table (name/role/current task/status), key decisions log. Detect party mode from state.build.mode === "party".
- **Assigned To**: integrator
- **Agent Type**: general-purpose
- **Files**: `plugins/tactical-engineering/commands/status.md`
- **Dependencies**: Task 1
- **AC**: `/status` shows party-mode phase info when in party mode

#### Task 17: Update COMMANDS.md documentation
- **Description**: Add `/party` to COMMANDS.md with description, usage examples, comparison with `/build --team`, phase workflow explanation, prerequisites, and example invocation.
- **Assigned To**: integrator
- **Agent Type**: general-purpose
- **Files**: `COMMANDS.md`
- **Dependencies**: Task 14 (full command defined)
- **AC**: COMMANDS.md documents /party command completely

## Validation Commands

```bash
# Verify all new files exist
ls plugins/tactical-engineering/commands/party.md
ls plugins/tactical-engineering/agents/party-*-agent.md

# Verify state-file.js has party support
grep -c "party" plugins/tactical-engineering/scripts/state-file.js

# Verify continue-spec has party detection
grep -c "party" plugins/tactical-engineering/commands/continue-spec.md

# Verify status has party display
grep -c "party" plugins/tactical-engineering/commands/status.md

# Verify COMMANDS.md updated
grep "party" COMMANDS.md

# Count party agent files (should be 8)
ls plugins/tactical-engineering/agents/party-*-agent.md | wc -l
```

## References & Research

### Internal References
- Brainstorm: `docs/brainstorms/2026-02-06-party-mode-brainstorm.md`
- Agent Teams brainstorm: `docs/brainstorms/2026-02-06-agent-teams-support-brainstorm.md`
- Build command: `plugins/tactical-engineering/commands/build.md`
- State file: `plugins/tactical-engineering/scripts/state-file.js`
- Agent examples: `plugins/tactical-engineering/agents/backend-agent.md`
- CLAUDE.md conventions: `plugins/tactical-engineering/CLAUDE.md`

### External References
- BMAD Method party mode: https://github.com/bmad-code-org/BMAD-METHOD
- Claude Agent Teams docs: https://code.claude.com/docs/en/agent-teams
