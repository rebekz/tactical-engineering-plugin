# Party Mode Brainstorm

**Date**: 2026-02-06
**Status**: Ready for planning
**Related**: [Agent Teams Brainstorm](./2026-02-06-agent-teams-support-brainstorm.md)

---

## What We're Building

**Party Mode** - A unified, full-lifecycle multi-agent workflow powered by Claude Agent Teams. Inspired by BMAD Method's "party mode" concept but implemented with real separate Claude instances instead of single-LLM persona simulation.

A user invokes `/party` with a topic or feature description. The lead orchestrator spawns a full product team (6-8 specialists), then guides them through brainstorm → plan → build → validate phases in a single continuous session. The same team stays active throughout all phases, with each agent contributing based on their expertise domain.

### How It Differs from BMAD Party Mode

| Aspect | BMAD Party Mode | Our Party Mode |
|--------|----------------|----------------|
| Architecture | Single LLM simulating personas | Real separate Claude instances |
| Parallelism | None (sequential role-play) | True parallel execution |
| Research | Simulated expertise | Actual codebase/web research per agent |
| Scope | Discussion/brainstorming only | Full lifecycle: brainstorm → plan → build → validate |
| Communication | Scripted cross-talk | Real inter-agent messaging via SendMessage |
| Cost | Low (single context) | Higher (N separate contexts) |

### How It Differs from /build --team

| Aspect | /build --team | /party |
|--------|--------------|--------|
| Input | Requires finished spec document | Starts from a topic/idea |
| Scope | Implementation only (Phase 4-8) | Full lifecycle (brainstorm → build) |
| Team composition | Defined in spec file | Default product team roster, auto-assigned |
| Planning | Done beforehand via /plan | Agents collaboratively create the plan |
| User interaction | Minimal during build | Lead synthesizes and checks in between phases |

---

## Why This Approach

### True Multi-Agent over Single-LLM Simulation
- Real parallel research: architect investigates patterns while PM researches requirements simultaneously
- Independent context windows prevent information bleed between personas
- Each agent can use tools (file reads, web search, grep) independently
- Genuine diverse perspectives, not one model's simulation of diversity

### Unified Workflow over Separate Commands
- Eliminates the brainstorm → plan → build handoff friction
- Team builds shared context that carries through all phases
- No need to re-explain decisions made in earlier phases
- Single invocation for the full journey from idea to implementation

### Lead Orchestration over Direct Interaction
- User gets a single coherent interface (the lead)
- Lead synthesizes multi-agent perspectives into actionable summaries
- Reduces cognitive load - user doesn't need to manage 8 agents
- Lead handles phase transitions, blockers, and conflict resolution

---

## Key Decisions

### 1. Command Structure
**Decision**: New `/party` command, separate from `/build`
- `/party` = full lifecycle from idea to implementation
- `/build` = implementation only from existing spec
- `/party` internally produces a spec and can invoke build-phase logic

### 2. Default Team Roster (6-8 agents)

| Role | Persona | Expertise | Active Phases |
|------|---------|-----------|---------------|
| Product Manager | PM | Requirements, user stories, acceptance criteria | Brainstorm, Plan |
| System Architect | Architect | Architecture, patterns, tech decisions | Brainstorm, Plan, Build |
| Backend Developer | Backend Dev | APIs, business logic, databases | Plan, Build |
| Frontend Developer | Frontend Dev | UI, components, user experience impl | Plan, Build |
| QA Engineer | QA | Testing strategy, edge cases, validation | Plan, Build, Validate |
| UX Designer | UX | User flows, accessibility, interaction design | Brainstorm, Plan |
| Tech Writer | Docs | Documentation, developer guides | Build, Validate |
| DevOps Engineer | DevOps | CI/CD, deployment, infrastructure | Build, Validate |

All agents stay spawned throughout. In phases where they're "not primary," they still participate if the lead determines their input is relevant (e.g., QA raising testing concerns during brainstorm).

### 3. Phase Workflow

```
/party "Build a user authentication system with OAuth"

Phase 1: BRAINSTORM (parallel research + round-table discussion)
├── All agents research the topic from their perspective
├── Lead collects findings and synthesizes round-table summary
├── Lead presents key decisions to user for approval
└── Output: brainstorm-summary.md

Phase 2: PLAN (collaborative planning)
├── Architect proposes high-level design
├── PM breaks into epics/stories with acceptance criteria
├── Backend/Frontend scope technical tasks
├── QA defines test strategy
├── Lead assembles into spec document
├── Lead presents plan to user for approval
└── Output: specs/party-<topic>.md (compatible with /build format)

Phase 3: BUILD (parallel implementation)
├── Lead creates TaskList from spec
├── Agents self-claim tasks based on their expertise
├── Inter-agent messaging for coordination (API contracts, etc.)
├── Lead monitors progress, resolves blockers
└── Output: implemented code + state file

Phase 4: VALIDATE (verification + documentation)
├── QA runs validation commands
├── Tech Writer updates documentation
├── DevOps reviews deployment readiness
├── Lead presents completion report to user
└── Output: validation results + docs
```

### 4. State Management
- Reuse existing state-file.js with `mode: "party"`
- Add `party.phase` field to track current lifecycle phase
- Add `party.brainstormSummary` and `party.planPath` for phase artifacts
- State survives interruption - `/continue-spec` can resume from any phase

### 5. User Checkpoints
The lead pauses for user approval at each phase transition:
- After brainstorm: "Here's what the team found. Proceed to planning?"
- After plan: "Here's the proposed plan. Proceed to build?"
- After build: "Build complete. Run validation?"
- After validate: "All done. Here's the summary."

User can redirect, adjust team composition, or abort at any checkpoint.

### 6. Model Strategy
- Lead: Sonnet (fast coordination, lower cost)
- Specialist agents: Sonnet by default, user can override per-agent
- Heavy research agents (Architect, PM): Could use Opus for deeper analysis

---

## Open Questions

1. **Agent persona depth**: Should agents have BMAD-style personality traits (communication style, catchphrases) or stay purely functional? Initial lean: functional with light persona flavor to aid readability.

2. **Spec format compatibility**: The plan phase should produce a spec compatible with `/build` format. Should it also be usable standalone with `/build --team`? Initial lean: yes, for flexibility.

3. **Token budget awareness**: With 8 agents active, token costs could be significant. Should there be a cost estimation prompt before starting? Initial lean: yes, similar to current `/build --team` cost confirmation.

4. **Brainstorm depth**: How long should the brainstorm phase run? Fixed rounds? Until convergence? Until user says "proceed"? Initial lean: lead synthesizes after one parallel research round, user decides.

5. **Existing agent reuse**: Should party mode use the 13 existing agent definitions in `agents/` or create new party-specific agent definitions with persona traits? Initial lean: create new party-specific agents that wrap existing ones with persona context.

---

## What We're NOT Building

- **Single-LLM persona simulation** (BMAD's actual approach) - we're using real Agent Teams
- **Interactive chat mode** where user talks to the group and multiple agents respond in one message - that's BMAD's pattern
- **Replacement for /build** - party mode complements it, /build remains for spec-first workflows
- **Custom team composition UI** - use the default roster; customization comes later if needed
- **Nested teams** - Agent Teams limitation: no teams within teams

---

## Next Steps

Run `/workflows:plan` to create the implementation spec for:
1. New `/party` command definition
2. Party-specific agent definitions (8 agents with persona context)
3. Phase orchestration logic in the command
4. State file schema extensions for party mode
5. Integration with existing /build phase logic for the build phase
6. Documentation and examples
