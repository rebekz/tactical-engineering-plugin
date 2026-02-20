---
category: build-patterns
component: build-orchestration
tags: [parallel-execution, file-conflicts, multi-agent]
date_resolved: 2026-02-20
related_build: knowledge-aware-planning-and-team-handoff
---

# Track-Based Parallel Execution for Overlapping File Edits

## Problem Symptom
When multiple tasks modify the same file, parallel execution causes edit conflicts and lost changes.

## Root Cause
Agents running simultaneously on the same file overwrite each other's edits.

## Working Solution
Split tasks into tracks based on which files they modify:
- Track A: Tasks touching file X (run sequentially within track)
- Track B: Tasks touching file Y (run sequentially within track)
- Tracks A and B run in parallel since they touch different files

**Example from this build:**
- Track A (plan-w-team.md): Tasks 3→4→5→6→7 sequential
- Track B (compound.md): Tasks 8→9 sequential
- Tasks 1, 2 parallel (new files, no conflicts)
- Tracks A and B parallel with each other

## Prevention Strategies
1. During spec design, assign tasks to tracks based on file overlap
2. Use the "Parallel" field in task definitions to indicate track membership
3. Sequential within track, parallel across tracks
