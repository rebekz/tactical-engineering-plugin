# README Workflow Spotlight Brainstorm

**Date:** 2026-02-20
**Status:** Brainstorm
**Author:** User + Claude

## What We're Building

Full rewrite of README.md to serve as a practical guide that spotlights the end-to-end workflow journey: brainstorm, plan, merge specs, build, validate, compound. The README should help users get productive fast with clear workflows, command reference, and decision guidance.

### Design Decisions

1. **Audience:** Practical guide for developers — clear workflows, command reference, decision trees. Less flash, more substance.
2. **Spotlight:** End-to-end from idea — show the full journey from brainstorm through compound knowledge. The complete lifecycle.
3. **Scope:** Full rewrite — restructure the entire README with new focus. Keep useful content but reorganize everything.
4. **Visuals:** Mermaid diagrams for workflow visualization. GitHub-rendered flowcharts.
5. **Cut:** Remove the Sources/references sections (top and bottom). Keep credit minimal (1-2 key links max in a small attribution line).

## Why This Approach

The current README is feature-list oriented — it enumerates commands and modes but doesn't show how they connect into a cohesive workflow. Users need to understand the *journey*, not just the tools. A practical guide that walks through the end-to-end lifecycle helps users:
- Pick the right starting point for their situation
- Understand how commands chain together
- Know what outputs each phase produces and what consumes them

## Proposed README Structure

### 1. Header + Tagline
- Name, one-line description, badges (optional)
- No lengthy references section

### 2. Installation
- Keep existing plugin marketplace install command
- Brief prerequisites note (Node.js, Claude Code)

### 3. The Workflow (Hero Section)
- Mermaid diagram showing the full lifecycle:
  ```
  Idea -> Brainstorm -> Plan -> Build -> Validate -> Compound -> (feeds back)
  ```
- Brief description of each phase (2-3 sentences each)
- Show which commands map to which phase

### 4. Quick Start Paths
Three paths based on where the user is starting from:
- **From an idea:** `/party` or manual brainstorm -> `/plan_w_team` -> `/build`
- **From existing docs:** `/plan_w_team --accept` (single or multi-doc merge) -> `/build`
- **From BMad output:** `/plan_w_team --bmad` -> `/build`

Each path is a numbered walkthrough (5-7 steps) showing the actual commands.

### 5. Build Modes
- Comparison table: Subagent vs Team vs Party
- When to use each
- Prerequisites for Team/Party mode

### 6. Command Reference
- Grouped by workflow phase (Plan, Execute, Monitor, Validate, Compound)
- Each command: one-line description + key flags
- Link to COMMANDS.md for full details

### 7. Agent Architecture
- Brief description of the 3 tiers: Core (7), Compound (6), Party (8)
- What each tier does
- Link to /agents command for full list

### 8. Under the Hood
- State persistence (cross-session resume)
- Hooks system (plugin-level + command-level)
- Validation pipeline

### 9. Plugin Structure
- Compact file tree (keep existing but update)

### 10. Attribution
- 1-2 key credit links, minimal

## Resolved Questions

1. **Keep Party Mode details?** Yes, but integrated into the workflow section rather than a standalone section. Party is one path through the lifecycle, not a separate feature.
2. **Include Z.AI CLI?** Mention briefly in a "Bonus" or "Integrations" subsection. Not a primary workflow.
3. **Ralph Loop template?** Skip from README. It's a template, not a workflow. Can be discovered via `/agents` or docs.
