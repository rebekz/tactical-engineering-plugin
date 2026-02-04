---
last_updated: 2026-02-03
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
