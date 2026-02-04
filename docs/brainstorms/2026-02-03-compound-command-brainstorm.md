---
title: "/compound Command - Knowledge Compounding from Builds"
date: 2026-02-03
status: brainstorm
type: workflow
tags: [workflow, compound, learning, multi-agent]
---

# /compound Command - Knowledge Compounding from Builds

## What We're Building

A `/compound` command that runs after `/build` (or multiple builds) to learn from and document:
- **Architecture choices** - decisions made during implementation
- **Deployment choices** - environment setup and configuration
- **Mistakes & solutions** - errors encountered and their fixes
- **CLAUDE.md updates** - project patterns and guidelines

The command creates a knowledge compounding system where each build makes future builds easier by capturing what was learned.

## Why This Approach

### Problem Solved

After completing builds with `/build`, valuable knowledge is lost:
- Why certain architecture decisions were made
- What deployment approach worked
- What mistakes were encountered and how they were fixed
- What patterns should be documented for future reference

### Design Philosophy

Following Every's compounding philosophy: **"Each unit of engineering work should make subsequent units of work easier—not harder."**

First time solving a problem → Research (30 min)
Document the solution → Quick lookup (2 min next time)
Knowledge compounds → Team gets smarter

### Why Manual Trigger

- User decides when a build is worth documenting
- Avoids noise from experimental/failed builds
- Allows user to provide additional context
- More intentional knowledge capture

### Why Parallel Subagents

- Faster documentation (6 agents working in parallel)
- Specialized analysis per knowledge type
- Follows Every's proven pattern
- Can scale to complex builds

---

## Key Decisions

### Decision 1: Trigger = Manual Only

**Rationale:** User runs `/compound` explicitly after builds complete. Auto-triggering could create noise from experimental builds.

**Trade-off:** Requires user to remember to run it, but ensures quality documentation.

---

### Decision 2: Knowledge Types (4 Categories)

| Category | Output Format | Example |
|----------|--------------|---------|
| Architecture choices | `docs/adr/adr-XXX-title.md` | "Why we chose Fiber vs Gin" |
| Deployment choices | `docs/deployment.md` with changelog | "VPS setup with systemd" |
| Mistakes & solutions | `docs/solutions/[category]/[problem].md` | "N+1 query in employee list" |
| CLAUDE.md updates | Update `CLAUDE.md` directly | "Add pattern for multi-tenant queries" |

**Rationale:** Different knowledge types need different formats:
- ADRs for architecture decisions (permanent record)
- Solutions with categories for quick lookup
- Deployment docs for operational knowledge
- CLAUDE.md for agent guidance

---

### Decision 3: Information Sources

**Primary:**
1. **Spec documents** - `specs/<plan-name>.md` (original plan, what was intended)
2. **Task outputs** - Completed tasks from Task tools (what actually happened, what failed)

**Not using:**
- Git diff (too granular, misses context)
- Full conversation history (too verbose, task outputs are clearer)

**Rationale:** Task outputs contain structured info about what was done, what failed, and how it was fixed. Combined with the spec, this provides complete picture.

---

### Decision 4: Execution Strategy - 6 Parallel Subagents

| Subagent | Role | Output |
|----------|------|--------|
| **Task Analyzer** | Reads spec + completed tasks, extracts all decisions, changes, errors | Structured analysis JSON |
| **Architecture Writer** | Creates ADRs for architecture decisions | `docs/adr/adr-XXX-title.md` |
| **Deployment Writer** | Updates deployment.md with changelog | `docs/deployment.md` |
| **Mistake Extractor** | Finds errors, root causes, solutions | `docs/solutions/[category]/[problem].md` |
| **CLAUDE Updater** | Updates CLAUDE.md with new patterns | `CLAUDE.md` |
| **Doc Assembler** | Combines everything, validates, reports | Summary report |

**Workflow:**
```
User runs /compound [spec-path]
       ↓
Launch 6 parallel subagents
       ↓
Each analyzes spec + tasks independently
       ↓
Doc Assembler coordinates final output
       ↓
Present summary with links to created docs
```

**Rationale:** Parallel execution is faster (6 agents vs 1 sequential). Specialized agents produce better quality documentation.

---

### Decision 5: ADR Format for Architecture Decisions

Architecture Decision Records (ADRs) provide:
- Permanent record of why decisions were made
- Context for future developers (and agents)
- Traceability of architecture evolution

**Template:**
```markdown
---
adr_id: ADR-001
date: 2026-02-03
status: accepted
title: Chose Fiber framework over Gin
---

# ADR-001: Chose Fiber framework over Gin

## Context
Need web framework for Talenta HR API. Options: Fiber, Gin, Echo.

## Decision
Use Fiber framework.

**Rationale:**
- Built for performance (fastest Go framework)
- Express-like API (familiar to team)
- Built-in middleware for auth, logging, cors
- Good HTMX support

**Consequences:**
- ✅ Fast performance (<500ms TTFB target)
- ✅ Lower memory footprint
- ⚠️ Less popular than Gin (smaller community)
- ✅ Good DX with Express-like syntax

## Alternatives Considered
- Gin: More popular, but slower
- Echo: Good performance, but more verbose API

## Related
- Spec: specs/talenta-hr-umkm-lite.md
- Tasks: story-001-01, story-001-02
```

---

### Decision 6: docs/solutions/ Format for Mistakes

Following Every's pattern:
```markdown
---
category: performance-issues
component: employee-service
tags: [n-plus-one, query, optimization]
date_resolved: 2026-02-03
related_build: talenta-hr-umkm-lite
related_tasks: [story-002-02]
---

# N+1 Query in Employee List

## Problem Symptom
Loading employee list with department names took 15 seconds for 200 employees.

**Error:** Query timeout, page load >15s

## Investigation Steps
1. Checked query logs - saw 200+ queries for single request
2. Analyzed EmployeeService.List() method
3. Found department query inside loop (classic N+1)

## Root Cause
`models.Employee` has `DepartmentID` but doesn't preload `Department` association. Render loop queries each employee's department separately.

## Working Solution
Added `.Preload("Department")` to GORM query:

```go
// Before (N+1)
employees := []models.Employee{}
db.Find(&employees)  // 1 query
for _, e := range employees {
    db.First(&e.Department)  // N queries!
}

// After (2 queries total)
employees := []models.Employee{}
db.Preload("Department").Find(&employees)  // Preload in single query
```

**Result:** Page load 15s → 400ms

## Prevention Strategies
1. **Always Preload** - Use `.Preload()` for associations
2. **Query logging** - Enable in dev to spot N+1
3. **Code review checklist** - Check for queries in loops
4. **Test with data** - Use realistic dataset (100+ records)

## Test Cases Added
```go
func TestEmployeeListPreloadsDepartments(t *testing.T) {
    // Create 100 employees with departments
    // Assert query count < 5
}
```

## Cross-References
- Related: docs/adr/adr-002-gorm-usage.md
- Similar issue: docs/solutions/performance-issues/n-plus-one-briefs.md
```

---

### Decision 7: docs/deployment.md with Changelog

Deployment knowledge accumulates. Use changelog format:

```markdown
---
last_updated: 2026-02-03
environment: production
platform: linux-amd64
---

# Deployment Guide

## Quick Start
```bash
# Build binary
go build -o talenta-hr ./cmd/server

# Copy to server
scp talenta-hr user@server:/opt/talenta-hr/

# Restart service
ssh user@server 'sudo systemctl restart talenta-hr'
```

## Environment
- **OS:** Ubuntu 22.04 LTS
- **Go:** 1.21.5
- **Database:** SQLite (embedded)
- **Service:** systemd

## Service Configuration
```ini
[Unit]
Description=Talenta HR API
After=network.target

[Service]
Type=simple
User=talenta-hr
WorkingDirectory=/opt/talenta-hr
ExecStart=/opt/talenta-hr/talenta-hr
Restart=always

[Install]
WantedBy=multi-user.target
```

## Changelog

### 2026-02-03 - Initial Deployment
- Deployed to DigitalOcean $6/month VPS
- Used systemd for service management
- Configured SQLite with WAL mode for performance
- Set up nginx reverse proxy with Let's Encrypt SSL
- **Decision:** Single binary deployment (no Docker) for simplicity

**Lessons Learned:**
- Binary size 18MB (under 20MB target ✅)
- Memory usage 45MB idle (under 100MB target ✅)
- TTFB < 200ms (under 500ms target ✅)

### [Future entries...]
```

---

### Decision 8: CLAUDE.md Updates

Pattern-based updates for agent guidance:

```markdown
# Talenta HR - Agent Guidelines

## Architecture Patterns

### Multi-Tenancy
All database queries MUST include `company_id` filter:

```go
// CORRECT
db.Where("company_id = ?", companyID).Find(&employees)

// WRONG - leaks data across companies
db.Find(&employees)
```

### GORM Preloading
Always use `.Preload()` for associations to avoid N+1 queries:

```go
// CORRECT
db.Preload("Department").Preload("Salary").Find(&employees)

// WRONG - causes N+1
db.Find(&employees)
```

### Error Handling
Use consistent error response format:

```go
return c.JSON(fiber.Map{
    "success": false,
    "message": "Validation failed",
    "errors": []fiber.Map{...},
})
```

## Deployment Patterns

### Service Management
- Use systemd for service management
- Restart with `systemctl restart talenta-hr`
- Logs: `journalctl -u talenta-hr -f`

### Database Migrations
Run migrations before starting service:
```bash
./talenta-hr migrate up
./talenta-hr serve
```
```

---

## Open Questions

### Q1: How to handle multiple builds before compounding?

**Scenario:** User runs 3 builds, then runs `/compound` once.

**Options:**
1. Compound only the most recent build (simplest)
2. Analyze all specs in `specs/` folder (comprehensive)
3. Ask user which build to compound (flexible)

**Recommendation:** Option 1 (most recent) or Option 3 (ask user). Option 2 could be overwhelming.

---

### Q2: Should /compound auto-detect what changed?

**Approach:** Compare spec (what was planned) vs completed tasks (what actually happened) to identify:
- Architecture deviations
- Unplanned fixes
- Deployment changes

**Benefit:** Captures emergent decisions, not just planned ones.

**Risk:** Could be noisy if tasks don't clearly indicate deviations.

**Recommendation:** Yes, auto-detect changes but allow user to confirm/adjust.

---

### Q3: How to handle conflicting ADRs?

**Scenario:** Build 1 says "use Fiber", Build 2 says "switch to Gin".

**Options:**
1. Create new ADR that supersedes old one
2. Update old ADR with "superseded by" status
3. Keep both, add "evolution" section

**Recommendation:** Option 2 (update with supersedes link) + Option 3 (keep history).

---

### Q4: Integration with /workflows:plan?

Should `/workflows:plan` automatically reference `docs/solutions/` and `docs/adr/` when creating new plans?

**Benefit:** Plans would learn from past decisions.

**Approach:** Add step to plan workflow: "Search docs/solutions/ for similar problems, docs/adr/ for relevant architecture decisions."

**Status:** YES - this is key to the compounding effect.

---

## Next Steps

1. **Run `/workflows:plan`** - Create implementation plan for `/compound` command
2. **Define file structure** - Set up `docs/adr/`, `docs/solutions/`, `docs/deployment.md`
3. **Implement 6 subagents** - Each with specialized role
4. **Test with sample build** - Use Talenta HR spec as test case
5. **Integrate with /workflows:plan** - Ensure plans reference compounded knowledge

---

## Related Brainstorms

None yet - this is the first brainstorm.

---

## References

- Every's `/workflows:compound` command: https://raw.githubusercontent.com/EveryInc/compound-engineering-plugin/refs/heads/main/plugins/compound-engineering/commands/workflows/compound.md
- ADR format: https://adr.github.io/
- Current `/build` command: `.claude/commands/build.md`
- Compound Engineering philosophy: `.claude/docs/compound-engineering.md`
