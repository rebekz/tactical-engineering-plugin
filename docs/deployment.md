---
last_updated: 2026-02-20
environment: production
platform: linux-amd64
---

# Deployment Guide

Documentation for deploying the multi-agent development workflow system.

## Quick Start

This system runs locally using Claude Code with custom commands and agents. No traditional deployment needed.

## Environment

- **Platform:** macOS/Linux/Windows (Claude Code supported)
- **Runtime:** Claude Code CLI
- **Configuration:** `.claude/` directory

## Configuration

Located in `.claude/`:
- `commands/` - Slash command implementations
- `agents/` - Sub-agent definitions
- `skills/` - Reusable prompt templates
- `docs/` - Learnings and compounded knowledge

## Changelog

### 2026-02-20 - Native Ralph Loop Integration

**New Files:**
- `plugins/tactical-engineering/scripts/ralph-loop.js` -- Core ralph loop utilities (createRalphState, updateRalphIteration, generateFailureReport, etc.)
- `plugins/tactical-engineering/hooks/ralph-stop-hook.sh` -- Stop hook script for iteration control (must be executable)
- `plugins/tactical-engineering/commands/ralph-stop.md` -- Cancel command for active ralph loops

**Modified Files:**
- `plugins/tactical-engineering/scripts/state-file.js` -- Added ralphOptions (5th param) to createInitialState
- `plugins/tactical-engineering/hooks/hooks.json` -- Added Stop hook entry
- `plugins/tactical-engineering/commands/build.md` -- Added --ralph, --max-iterations, --self-heal, --completion-promise flags
- `plugins/tactical-engineering/commands/plan-w-team.md` -- Added --ralph, --max-iterations flags with auto-handoff
- `plugins/tactical-engineering/commands/continue-spec.md` -- Added ralph state detection and resume
- `plugins/tactical-engineering/commands/status.md` -- Added ralph loop status display
- `plugins/tactical-engineering/COMMANDS.md` -- Added ralph documentation and /ralph-stop entry

**Configuration:**
- Stop hook registered in hooks.json -- fires on every session exit attempt
- When no active ralph state: hook exits immediately (no overhead)
- Script must be executable: `chmod +x plugins/tactical-engineering/hooks/ralph-stop-hook.sh`

**Dependencies:**
- Node.js (for JSON operations in stop hook)
- No external dependencies (no jq requirement)

**Lessons Learned:**
- Stop hooks must exit 0 on error (safe default prevents trapping user)
- State file backward compatibility is critical -- always default new fields to null
- Shell scripts in hooks must handle $CLAUDE_PLUGIN_ROOT correctly

### 2026-02-03 - Initial Setup
- Created directory structure for knowledge compounding
- Set up docs/adr/ for Architecture Decision Records
- Set up docs/solutions/ for mistakes and solutions
- Created placeholder for deployment documentation

**Lessons Learned:**
- This is a local development tool, not a deployed service
- Documentation is kept with the project for version control
