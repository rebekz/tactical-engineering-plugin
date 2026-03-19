---
title: "feat: TE Plugin Improvements — Prefix Shortening, Quality Gates, Review Agents, Compound Refresh, MCP"
type: feat
status: completed
date: 2026-03-20
---

# feat: TE Plugin Improvements

Five improvements to the tactical-engineering plugin, informed by comparison with compound-engineering v2.45.

## Overview

Rename the plugin from `tactical-engineering` to `te` for shorter command invocation, add LFG-style quality gates to `/get-it-done`, introduce 3 specialized review agents, add a `/compound-refresh` command for knowledge maintenance, and integrate Context7 MCP for framework documentation.

## Acceptance Criteria

- [ ] Plugin name changed from `tactical-engineering` to `te` in plugin.json and marketplace.json
- [ ] All commands invocable via `/te:command-name` (e.g., `/te:get-it-done`)
- [ ] `/get-it-done` has 3 quality gates: plan-exists, code-changes-produced, validation-result-gating
- [ ] `DONE` signal only emitted when validation PASSES (already partially implemented, needs tightening)
- [ ] 3 new review agents: security-sentinel, performance-oracle, code-simplicity-reviewer
- [ ] New agents registered in AGENTS.md
- [ ] `/compound-refresh` command exists and scans docs/solutions/ for stale entries
- [ ] `.mcp.json` file exists with Context7 HTTP MCP server configuration
- [ ] Plugin version bumped to 0.7.0

## Implementation Phases

### Phase 1: Prefix Shortening (Foundation)

Must happen first — all subsequent changes use the new namespace.

#### Task 1.1: Rename plugin in plugin.json
- **File:** `plugins/tactical-engineering/.claude-plugin/plugin.json`
- **Change:** `"name": "tactical-engineering"` → `"name": "te"`
- **Agent:** backend-agent
- **Dependencies:** None

#### Task 1.2: Update marketplace.json
- **File:** `.claude-plugin/marketplace.json`
- **Changes:**
  - Plugin name: `"tactical-engineering"` → `"te"`
  - Marketplace name: `"tactical-engineering-marketplace"` → `"te-marketplace"`
  - Source path remains `"./plugins/tactical-engineering"` (directory name unchanged)
- **Agent:** backend-agent
- **Dependencies:** None

#### Task 1.3: Update internal skill references
- **Files:** All command `.md` files that reference `tactical-engineering:` prefix in Skill() calls
- **Change:** Replace `tactical-engineering:` with `te:` in all Skill invocations
- **Key files to update:**
  - `plugins/tactical-engineering/commands/get-it-done.md` — references `tactical-engineering:brainstorming`, `tactical-engineering:plan-w-team`, `tactical-engineering:build`, `tactical-engineering:validate`
  - `plugins/tactical-engineering/commands/party.md` — references `tactical-engineering:*` skills
  - Any other command files with Skill() calls using the old prefix
- **Agent:** backend-agent
- **Dependencies:** None

#### Task 1.4: Version bump to 0.7.0
- **Files:** `plugins/tactical-engineering/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- **Change:** Version `0.6.1` → `0.7.0` (minor bump for breaking namespace change)
- **Agent:** backend-agent
- **Dependencies:** 1.1, 1.2

### Phase 2: Quality Gates in get-it-done

#### Task 2.1: Add GATE 1 — Plan file verification
- **File:** `plugins/tactical-engineering/commands/get-it-done.md`
- **Change:** After Step 3 (Plan), add explicit verification that a spec file was produced. If no spec file found in `specs/`, re-run plan-w-team once. If still no spec, abort pipeline with error.
- **Pattern:** LFG gate pattern — `plan MUST exist before work`
- **Agent:** backend-agent
- **Dependencies:** 1.3

#### Task 2.2: Add GATE 2 — Code changes verification
- **File:** `plugins/tactical-engineering/commands/get-it-done.md`
- **Change:** After Step 4 (Build), verify that actual code changes were produced by running `git diff --stat`. If no changes detected, report warning and ask user whether to proceed to validation or abort.
- **Pattern:** LFG gate pattern — `work MUST produce code changes`
- **Agent:** backend-agent
- **Dependencies:** 2.1

#### Task 2.3: Tighten GATE 3 — Validation result gating
- **File:** `plugins/tactical-engineering/commands/get-it-done.md`
- **Change:** The current implementation already gates DONE on validation result (PASSED/PARTIAL/FAILED). Tighten by:
  - Adding explicit `Overall Status:` parsing from validation output
  - Ensuring FAILED never emits `<promise>DONE</promise>` (already done)
  - Adding retry logic: if FAILED, re-run build on failed tasks then re-validate (up to 1 retry)
- **Agent:** backend-agent
- **Dependencies:** 2.2

### Phase 3: Specialized Review Agents

#### Task 3.1: Create security-sentinel agent
- **File:** `plugins/tactical-engineering/agents/security-sentinel.md` (new)
- **Content:** Adapted from CE's security-sentinel. Performs security audits covering:
  - Input validation analysis
  - SQL injection risk assessment
  - XSS vulnerability detection
  - Authentication & authorization audit
  - Sensitive data exposure checks
  - OWASP Top 10 compliance
- **Frontmatter:** name, description, tools (Bash, Glob, Grep, Read, Edit, Write), model: sonnet, permissionMode: default, color: red
- **Agent:** docs-agent
- **Dependencies:** None

#### Task 3.2: Create performance-oracle agent
- **File:** `plugins/tactical-engineering/agents/performance-oracle.md` (new)
- **Content:** Adapted from CE's performance-oracle. Analyzes:
  - Algorithmic complexity
  - Database performance (N+1, missing indexes)
  - Memory management
  - Caching opportunities
  - Network optimization
  - Frontend performance
- **Frontmatter:** name, description, tools, model: sonnet, permissionMode: default, color: yellow
- **Agent:** docs-agent
- **Dependencies:** None

#### Task 3.3: Create code-simplicity-reviewer agent
- **File:** `plugins/tactical-engineering/agents/code-simplicity-reviewer.md` (new)
- **Content:** Adapted from CE's code-simplicity-reviewer. Final review pass for:
  - YAGNI violations
  - Unnecessary abstractions
  - Redundant code
  - Over-engineering
  - Readability optimization
- **Frontmatter:** name, description, tools, model: sonnet, permissionMode: default, color: green
- **Agent:** docs-agent
- **Dependencies:** None

#### Task 3.4: Register new agents in AGENTS.md
- **File:** `plugins/tactical-engineering/AGENTS.md`
- **Change:** Add new section "### Review Specialists" with entries for security-sentinel, performance-oracle, code-simplicity-reviewer
- **Agent:** docs-agent
- **Dependencies:** 3.1, 3.2, 3.3

### Phase 4: Knowledge Refresh Command

#### Task 4.1: Create compound-refresh command
- **File:** `plugins/tactical-engineering/commands/compound-refresh.md` (new)
- **Content:** Adapted from CE's `/ce:compound-refresh`. Workflow:
  1. Scan `docs/solutions/` for all `.md` files
  2. For each file, check if referenced code patterns still exist in codebase
  3. Classify as: Keep (still accurate), Update (partially drifted), Replace (significantly changed), Archive (no longer relevant)
  4. Present classification to user for approval
  5. Execute approved changes (update content, move archived files)
  6. Optionally refresh derived docs (CLAUDE.md patterns, planning-patterns.md)
- **Frontmatter:** name: compound_refresh, description, argument-hint: [--auto], model: opus, allowed-tools: standard set
- **Agent:** backend-agent
- **Dependencies:** None

#### Task 4.2: Register in COMMANDS.md
- **File:** `plugins/tactical-engineering/COMMANDS.md`
- **Change:** Add `/compound-refresh` section under "## Workflow Example" or new "## Knowledge Maintenance" section
- **Agent:** docs-agent
- **Dependencies:** 4.1

### Phase 5: MCP Context7 Integration

#### Task 5.1: Create .mcp.json
- **File:** `plugins/tactical-engineering/.mcp.json` (new)
- **Content:**
  ```json
  {
    "mcpServers": {
      "context7": {
        "type": "http",
        "url": "https://mcp.context7.com/mcp",
        "headers": {
          "x-api-key": "${CONTEXT7_API_KEY:-}"
        }
      }
    }
  }
  ```
- **Agent:** backend-agent
- **Dependencies:** None

## Team Members

### backend-agent
- **Agent Type:** backend-agent
- **Tasks:** 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 4.1, 5.1

### docs-agent
- **Agent Type:** docs-agent
- **Tasks:** 3.1, 3.2, 3.3, 3.4, 4.2

## Validation Commands

```bash
# Verify plugin.json name change
node -e "const p = require('./plugins/tactical-engineering/.claude-plugin/plugin.json'); console.log(p.name === 'te' ? 'PASS' : 'FAIL: name is ' + p.name)"

# Verify marketplace.json name change
node -e "const p = require('./.claude-plugin/marketplace.json'); console.log(p.plugins[0].name === 'te' ? 'PASS' : 'FAIL: name is ' + p.plugins[0].name)"

# Verify version bump
node -e "const p = require('./plugins/tactical-engineering/.claude-plugin/plugin.json'); console.log(p.version === '0.7.0' ? 'PASS' : 'FAIL: version is ' + p.version)"

# Verify no old prefix references in commands
grep -r "tactical-engineering:" plugins/tactical-engineering/commands/ && echo "FAIL: old prefix still found" || echo "PASS: no old prefix references"

# Verify new agent files exist
test -f plugins/tactical-engineering/agents/security-sentinel.md && echo "PASS: security-sentinel exists" || echo "FAIL"
test -f plugins/tactical-engineering/agents/performance-oracle.md && echo "PASS: performance-oracle exists" || echo "FAIL"
test -f plugins/tactical-engineering/agents/code-simplicity-reviewer.md && echo "PASS: code-simplicity-reviewer exists" || echo "FAIL"

# Verify compound-refresh command exists
test -f plugins/tactical-engineering/commands/compound-refresh.md && echo "PASS: compound-refresh exists" || echo "FAIL"

# Verify MCP config exists
test -f plugins/tactical-engineering/.mcp.json && echo "PASS: .mcp.json exists" || echo "FAIL"

# Verify quality gates in get-it-done
grep -q "GATE 1" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Gate 1 present" || echo "FAIL"
grep -q "GATE 2" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Gate 2 present" || echo "FAIL"
grep -q "GATE 3" plugins/tactical-engineering/commands/get-it-done.md && echo "PASS: Gate 3 present" || echo "FAIL"
```

## Relevant Files

- `plugins/tactical-engineering/.claude-plugin/plugin.json` — Plugin manifest (name, version)
- `.claude-plugin/marketplace.json` — Marketplace registry
- `plugins/tactical-engineering/commands/get-it-done.md` — Autonomous workflow command
- `plugins/tactical-engineering/commands/*.md` — All commands (for prefix updates)
- `plugins/tactical-engineering/agents/*.md` — Existing agents
- `plugins/tactical-engineering/AGENTS.md` — Agent registry
- `plugins/tactical-engineering/COMMANDS.md` — Command documentation
- `plugins/tactical-engineering/CLAUDE.md` — Agent guidelines

## Sources

- Compound-engineering plugin v2.45 at `~/project/self/bmad-new/compound-engineering-plugin/`
- CE agents: `security-sentinel.md`, `performance-oracle.md`, `code-simplicity-reviewer.md`
- CE skills: `ce:compound-refresh`
- CE MCP config: `.mcp.json`
- CE LFG quality gates pattern from `skills/lfg/SKILL.md`
