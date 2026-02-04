---
title: "Test Persistence"
type: test
date: 2026-02-04
---

# Test Persistence Spec

A simple test spec for validating task persistence.

## Tasks

### Task 1: Create helper file
- [ ] Task 1: Create helper file

**Validation:**
```yaml
stop:
  - type: artifact
    path: .claude/helpers/state-file.js
    exists: true
    content_includes: "module.exports"
  - type: agent_output
    validate: success
    on_failure: fail
```

### Task 2: Create state file
- [ ] Task 2: Create state file

**Validation:**
```yaml
stop:
  - type: artifact
    path: .claude/specs/test-persistence/state.json
    exists: true
  - type: command
    command: node -e "console.log(JSON.parse(require('fs').readFileSync('.claude/specs/test-persistence/state.json', 'utf8')))"
    expect: exit_code_0
```

### Task 3: Read state file
- [ ] Task 3: Read state file

**Validation:**
```yaml
stop:
  - type: command
    command: node -e "const s = JSON.parse(require('fs').readFileSync('.claude/specs/test-persistence/state.json', 'utf8')); console.log(s.build ? 'OK' : 'FAIL')"
    expect: exit_code_0
```

### Task 4: Validate checksum
- [ ] Task 4: Validate checksum

**Validation:**
```yaml
stop:
  - type: acceptance_criteria
    criteria:
      - "Checksum is calculated correctly"
      - "State file survives session restart"
    require: all
```

## Validation Commands

```bash
# Test that state file exists
test -f .claude/specs/test-persistence/state.json && echo "State file exists" || echo "State file missing"

# Test that state file is valid JSON
node -e "console.log(JSON.parse(require('fs').readFileSync('.claude/specs/test-persistence/state.json', 'utf8')))" && echo "Valid JSON" || echo "Invalid JSON"
```

## Acceptance Criteria

- [ ] State file created in correct location
- [ ] State file contains valid JSON
- [ ] Checksum is calculated correctly
- [ ] State file survives session restart
