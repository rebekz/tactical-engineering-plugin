# Multi-Spec Accept for plan_w_team Command

**Date:** 2026-02-20
**Status:** Brainstorm
**Author:** User + Claude

## What We're Building

Extend the `/plan_w_team --accept` flag to accept multiple spec/plan documents and merge them into a single unified spec. Currently `--accept` takes exactly one path. The enhancement enables accepting multiple related plan documents (e.g., backend-plan.md + frontend-plan.md + api-plan.md) and producing one cohesive spec file in `specs/`.

### User Story

As a developer with a feature split across multiple plan documents, I want to accept all of them at once and have them intelligently merged into one unified spec, so I can run `/build` against a single comprehensive plan.

### Syntax

```bash
# Single doc (existing behavior, unchanged)
/plan_w_team --accept docs/plans/my-plan.md

# Multiple docs (new behavior)
/plan_w_team --accept "docs/plans/backend.md docs/plans/frontend.md docs/plans/api.md"

# With orchestration prompt
/plan_w_team --accept "docs/plans/backend.md docs/plans/frontend.md" "Focus on API-first approach"
```

## Why This Approach

**Approach chosen: Extend Accept Mode with Multi-Doc Merge**

When `EXISTING_PLAN_PATH` contains spaces (and the value is quoted), split into an array of paths, read each document, then use Claude's synthesis capabilities to merge them into one unified spec — similar to how `--bmad` mode synthesizes PRD + architecture + stories.

**Why not a new `--merge` flag?** Adds flag proliferation. Accept already means "take external docs and import them" — accepting multiple is a natural extension, not a different operation.

**Why not always-array?** The common case is single-doc accept. Adding merge pipeline overhead for every single-accept call is wasteful. Detecting multiple paths and branching is simple and keeps single-accept fast.

## Key Decisions

1. **Syntax:** Space-separated paths within quotes, parsed from `$1` after stripping `--accept`/`-a` prefix
2. **Merge strategy:** AI-powered merge — Claude reads all documents and synthesizes a unified spec with deduplicated tasks, resolved conflicts, and unified team assignments
3. **Output:** Single merged spec file in `specs/`, same format as current accept output
4. **Validation:** Each input document is validated individually before merge; merged output is validated against the standard checklist
5. **Detection:** If `EXISTING_PLAN_PATH.trim()` contains spaces, treat as multi-doc mode; otherwise single-doc (existing behavior)
6. **Merge model:** Reuse the BMad merge pattern — read all docs, present them as context, instruct Claude to produce one unified plan with required sections

## Scope

### In Scope

- Parse multiple space-separated paths from `--accept` argument
- Read and validate each input document
- AI-powered merge into single unified spec
- Standard accept pipeline for the merged result (copy to specs/, update frontmatter)
- Updated help text and examples
- Updated COMMANDS.md documentation

### Out of Scope

- Glob/wildcard path expansion
- Changes to `/build` command
- Changes to state-file.js
- New flags or commands
- Interactive merge conflict resolution

## Resolved Questions

1. **File naming for merged spec:** Auto-generate from input filenames. E.g., `backend-plan.md` + `frontend-plan.md` + `api-plan.md` → `backend-frontend-api-merged.md` in `specs/`.
2. **Merge prompt template:** Use a dedicated merge prompt tailored to combining plan documents, not the BMad synthesis prompt. The merge prompt should understand plan structure (tasks, team members, acceptance criteria) and produce a coherent unified spec.
