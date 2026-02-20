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

### 2026-02-03 - Initial Setup
- Created directory structure for knowledge compounding
- Set up docs/adr/ for Architecture Decision Records
- Set up docs/solutions/ for mistakes and solutions
- Created placeholder for deployment documentation

**Lessons Learned:**
- This is a local development tool, not a deployed service
- Documentation is kept with the project for version control

### 2026-02-20 - Knowledge-Aware Planning + Smart Team-Mode Handoff

**Changes:**
- Added `docs/planning-patterns.md` as planning memory store
- Added `plugins/tactical-engineering/agents/planning-patterns-agent.md` (7th compound agent)
- Modified `/plan_w_team` to read past learnings before designing solutions
- Modified `/plan_w_team` handoff to detect team signals and surface --team flag
- Modified `/compound` to include planning-patterns-agent in pipeline
- Removed static build suggestions from all 4 report formats

**Environment Requirements:**
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` for team mode (auto-detected, graceful fallback)

**Lessons Learned:**
- Sequential execution prevents edit conflicts when multiple tasks modify overlapping file sections
- Track-based parallelism (separate files on separate tracks) maximizes throughput without conflicts
