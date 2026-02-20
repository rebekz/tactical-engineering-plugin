# Tactical Engineering

A Claude Code plugin for multi-agent orchestration. Take an idea from brainstorm to production-ready code with automated planning, parallel agent execution, and knowledge compounding.

## Installation

```bash
/plugin marketplace add https://github.com/rebekz/tactical-engineering-plugin
/plugin install tactical-engineering
```

## The Workflow

Every feature follows the same lifecycle. Commands map to phases. Each phase produces artifacts the next phase consumes.

```mermaid
graph LR
    A[Idea] --> B[Brainstorm]
    B --> C[Plan]
    C --> D[Build]
    D --> E[Validate]
    E -->|"--ralph"| D
    E --> F[Compound]
    F -.->|feeds back| C

    style A fill:#f9f,stroke:#333
    style B fill:#bbf,stroke:#333
    style C fill:#bfb,stroke:#333
    style D fill:#fbf,stroke:#333
    style E fill:#ffb,stroke:#333
    style F fill:#bff,stroke:#333
```

| Phase | What happens | Command | Output |
|-------|-------------|---------|--------|
| **Brainstorm** | Explore the idea, ask questions, pick an approach | `/party` or manual | `docs/brainstorms/*.md` |
| **Plan** | Research codebase, design solution, define tasks and team | `/plan_w_team` | `specs/*.md` |
| **Build** | Agents execute tasks in parallel, you orchestrate | `/build` | Working code |
| **Validate** | Run tests, check acceptance criteria, verify quality | `/validate` | Pass/fail report |
| **Compound** | Extract ADRs, solutions, patterns, update CLAUDE.md | `/compound` | `docs/adr/`, `docs/solutions/`, CLAUDE.md |

The compound phase is what makes this a loop — learnings from each build inform future plans.

## Quick Start

Pick the path that matches where you're starting from.

### Path 1: From an idea

Use `/party` for a full 8-agent product team, or go step by step.

```bash
# Option A: Full autopilot with Party Mode
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
/party "Build user authentication with OAuth"
# -> brainstorm -> plan -> build -> validate (with checkpoints)

# Option B: Step by step
/plan_w_team "Build user authentication with OAuth"
/build specs/user-authentication.md
/status                                    # monitor progress
/validate specs/user-authentication.md     # verify results
/compound specs/user-authentication.md     # capture learnings

# Option C: Hands-free with Ralph Loop
/plan_w_team "Build user authentication with OAuth" --ralph
# -> plan -> auto-build -> validate -> iterate until done
```

### Path 2: From existing plan documents

Import one or more existing plans directly.

```bash
# Single document
/plan_w_team --accept docs/plans/my-plan.md

# Multiple documents — merges into one unified spec
/plan_w_team --accept docs/plans/backend.md,docs/plans/frontend.md,docs/plans/api.md

# Then build
/build specs/backend-frontend-api-merged.md
```

### Path 3: From BMad output

Convert BMad planning artifacts (PRD, architecture, epics, stories) into an executable spec.

```bash
/plan_w_team --bmad ~/project/_bmad-output/planning-artifacts
/build specs/product-name.md
```

## Build Modes

Three levels of agent coordination. Pick based on task complexity. Any mode can be combined with `--ralph` for automated iteration.

```mermaid
graph TD
    A{How complex?} -->|Independent tasks| B[Subagent Mode]
    A -->|Cross-cutting work| C[Team Mode]
    A -->|From scratch| D[Party Mode]

    B --> B1["/build specs/plan.md"]
    C --> C1["/build specs/plan.md --team"]
    D --> D1["/party 'your idea'"]

    B1 -->|+ --ralph| R[Ralph Loop]
    C1 -->|+ --ralph| R
    R -->|iterate| R
```

| | Subagent (default) | Team (`--team`) | Party (`/party`) |
|---|---|---|---|
| **Agents** | Defined in spec | Defined in spec | 8 fixed specialists |
| **Communication** | One-way (agent to lead) | Multi-directional | Multi-directional |
| **Task claiming** | Lead assigns | Self-claiming | Self-claiming |
| **Token cost** | Lower | Higher | Highest |
| **Input** | A spec file | A spec file | An idea |
| **Phases** | Build only | Build only | Brainstorm, Plan, Build, Validate |
| **Best for** | Focused, independent tasks | Work needing coordination | New features from scratch |

**Prerequisites for Team and Party modes:**
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Party Mode Team

| Agent | Role | Active Phases |
|-------|------|--------------|
| pm | Product Manager | Brainstorm, Plan |
| architect | System Architect | Brainstorm, Plan, Build |
| backend | Backend Developer | Plan, Build |
| frontend | Frontend Developer | Plan, Build |
| qa | QA Engineer | Plan, Build, Validate |
| ux | UX Designer | Brainstorm, Plan |
| docs | Tech Writer | Build, Validate |
| devops | DevOps Engineer | Build, Validate |

User checkpoints between each phase let you approve, refine, adjust, or abort.

### Ralph Loop (Automated Iteration)

Add `--ralph` to any build command for automated iteration-until-success. The loop runs build, checks results, and re-enters Claude to fix issues — no manual intervention required.

```bash
# Basic: build → validate → fix → repeat until all validation passes
/build specs/feature.md --ralph

# Self-healing: auto-retry failed tasks up to 3 times each
/build specs/feature.md --ralph --self-heal

# Full lifecycle: plan → build → validate → iterate
/plan_w_team "Add search" --ralph

# Custom limits
/build specs/feature.md --ralph --max-iterations 10

# Combine with team mode
/build specs/feature.md --team --ralph
```

| Mode | Command | What loops | Completion |
|------|---------|-----------|------------|
| Build + Validate | `/build --ralph` | build → validate | All validation passes |
| Self-healing | `/build --ralph --self-heal` | Per-task retry within build | All tasks completed |
| Full lifecycle | `/plan_w_team --ralph` | plan → build → validate | All validation passes |

**How it works:** A Stop hook intercepts Claude's exit, checks build state, runs validation commands from the spec, and blocks exit with instructions to fix remaining issues. The loop continues until validation passes or max iterations (default: 5) are reached.

**Control:**
- `/ralph-stop` — Cancel an active loop gracefully
- `/status` — See current iteration count and history
- `/continue-spec` — Resume a stopped loop with options

## Command Reference

See [COMMANDS.md](plugins/tactical-engineering/COMMANDS.md) for full details.

### Planning

| Command | Description | Key flags |
|---------|------------|-----------|
| `/plan_w_team` | Create, import, or merge implementation plans | `--accept <path>[,path,...]`, `--bmad <path>`, `--ralph`, orchestration prompt |
| `/plan` | Quick planning via skill (simpler features) | — |

### Execution

| Command | Description | Key flags |
|---------|------------|-----------|
| `/build` | Execute a spec with multi-agent coordination | `--team`, `--ralph`, `--self-heal`, `--max-iterations N`, `--fresh`, `--phase N`, `--from-task NAME` |
| `/party` | Full 8-agent lifecycle from idea to implementation | Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| `/continue` | Resume an agent with preserved context | `<agent-id> "instructions"` |
| `/continue-spec` | Resume a build from saved state (cross-session) | `--dry-run`, `--from-task N`, `--restart`, `--max-iterations N` |
| `/retry` | Retry a failed task with corrections | `<task-id> "correction"` |
| `/ralph-stop` | Cancel an active ralph loop gracefully | — |

### Monitoring

| Command | Description |
|---------|------------|
| `/status` | Task progress, agent status, teammate activity, ralph loop iteration |
| `/agents` | List all available agent types and roles |

### Validation & Knowledge

| Command | Description | Key flags |
|---------|------------|-----------|
| `/validate` | Run validation commands and check acceptance criteria | `<path-to-spec>` |
| `/compound` | Extract learnings into ADRs, solutions, patterns, CLAUDE.md | `--dry-run`, `--force` |

## The Compound Pipeline

`/compound` is more than documentation — it launches 7 specialized agents in parallel:

```mermaid
graph TD
    A["/compound specs/feature.md"] --> B[task-analyzer]
    A --> C[architecture-writer]
    A --> D[deployment-writer]
    A --> E[mistake-extractor]
    A --> F[claude-updater]
    A --> P[planning-patterns]
    B --> G[doc-assembler]
    C --> G
    D --> G
    E --> G
    F --> G
    P --> G
    G --> H["docs/adr/ + docs/solutions/ + CLAUDE.md + planning-patterns.md"]
```

| Agent | Produces |
|-------|---------|
| task-analyzer | Extracts architecture decisions, errors, and patterns |
| architecture-writer | Creates Architecture Decision Records (ADRs) |
| deployment-writer | Updates deployment changelog |
| mistake-extractor | Documents mistakes and solutions for future reference |
| claude-updater | Updates CLAUDE.md with new patterns and conventions |
| planning-patterns | Extracts planning-level patterns for future `/plan_w_team` sessions |
| doc-assembler | Validates and assembles all outputs into final docs |

Every build makes the next one smarter — planning patterns feed back into `/plan_w_team` via the knowledge-aware planning loop.

## Agent Architecture

21 agents organized in three tiers:

| Tier | Count | Purpose | Used by |
|------|-------|---------|---------|
| **Core** | 7 | Implementation work — frontend, backend, testing, docs, planning, code review, context gathering | `/build`, `/plan_w_team` |
| **Compound** | 7 | Knowledge extraction — ADRs, solutions, deployment docs, patterns, planning patterns, CLAUDE.md updates | `/compound` |
| **Party** | 8 | Full product team — PM, Architect, Backend, Frontend, QA, UX, Docs, DevOps | `/party` |

Run `/agents` to see the full list with descriptions.

## Under the Hood

### Knowledge-Aware Planning

Plans don't start from zero. `/plan_w_team` includes a "Review Past Learnings" step that reads accumulated knowledge before designing solutions:

```
docs/planning-patterns.md   → Team composition, testing strategies, workflow preferences
docs/adr/                   → Architecture decision records from past builds
docs/solutions/             → Solved problems and debugging insights
```

Applied learnings appear in the plan report with source citations (e.g., "Based on ADR-003"). The `/compound` pipeline writes to these same files after each build, closing the feedback loop.

### State Persistence

Build progress is saved to `.claude/specs/<spec-name>/state.json`. Close Claude Code mid-build and resume later:

```bash
/continue-spec specs/user-auth.md          # picks up where you left off
/continue-spec specs/user-auth.md --dry-run # preview what would run
```

State includes: task status, agent IDs, build mode (subagent/team/party), ralph loop iteration state, spec checksum for modification detection.

### Hooks & Validation

**Plugin-level hooks** (`hooks.json`) — Run Python validators (ruff, ty) after every Write/Edit operation.

**Stop hooks** — The ralph loop uses a Stop hook (`ralph-stop-hook.sh`) to intercept Claude's exit, evaluate build state, run validation commands, and decide whether to continue iterating or allow exit.

**Command-level Stop hooks** — YAML frontmatter in commands defines validation that runs when a command finishes. For example, `/plan_w_team` validates that a new `.md` file exists in `specs/` with all 7 required sections.

### Multi-Doc Merge

When plans are split across multiple documents (backend + frontend + API), merge them:

```bash
/plan_w_team --accept backend.md,frontend.md,api.md "Prioritize backend tasks"
```

The merge engine: reads all inputs, combines and renumbers tasks, deduplicates team members, merges acceptance criteria, auto-generates a filename, and records source paths in frontmatter for traceability.

## Plugin Structure

```
plugins/tactical-engineering/
├── commands/           # 11 slash commands (plan, build, party, ralph-stop, validate, ...)
├── agents/             # 21 agent definitions (core + compound + party tiers)
├── skills/             # 5 auto-activating skills (plan, work, review, compound, zai-cli)
├── hooks/              # Event-driven validation + ralph loop Stop hook
├── scripts/            # Node.js utilities (state persistence, ralph loop engine)
├── templates/          # Build templates (ralph-loop)
├── COMMANDS.md         # Full command reference
├── AGENTS.md           # Agent philosophy and catalog
└── CLAUDE.md           # Agent guidelines and conventions
```

---

Built on ideas from [Every's Compound Engineering](https://lethain.com/everyinc-compound-engineering/) and [IndyDevDan's agent patterns](https://gist.github.com/disler/d9f1285892b9faf573a0699aad70658f).
