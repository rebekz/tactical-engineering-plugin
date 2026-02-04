# BMad to Spec Conversion Explained

## Overview

The BMad conversion process transforms four separate document types (PRD, Architecture, Epics, Stories) into a single executable spec document that the multi-agent team can build with `/build`.

---

## Visual Transformation

### Before (BMad Output - Separate Documents)

```
_bmad_output/planning-artifacts/
├── prd/
│   └── talenta-hr-umkm-lite.md           # Product requirements
├── architecture/
│   ├── index.md                          # Architecture overview
│   ├── adr-001-tech-stack.md            # Tech stack decisions
│   ├── database-schema.md               # Database structure
│   └── deployment-guide.md              # Deployment procedures
├── epics/
│   ├── index.md                          # Epic catalog
│   ├── epic-001-foundation.md
│   ├── epic-002-employees.md
│   ├── epic-003-attendance.md
│   ├── epic-004-payroll.md
│   └── epic-005-reports.md
└── stories/
    ├── index.md                          # Story catalog
    ├── epic-001/
    │   ├── story-001-01-company-registration.md
    │   ├── story-001-02-authentication.md
    │   └── story-001-03-company-settings.md
    ├── epic-002/
    │   ├── story-002-01-create-employee.md
    │   ├── story-002-02-list-employees.md
    │   ├── story-002-03-import-csv.md
    │   └── story-002-04-export-employees.md
    └── ... (19 stories total)
```

### After (Single Executable Spec)

```
specs/talenta-hr-umkm-lite.md
├── Overview                  (from PRD)
├── Task Description          (from PRD)
├── Objective                 (from PRD)
├── Proposed Solution         (from Architecture)
├── Relevant Files            (from Architecture)
├── Implementation Phases     (from Epics)
│   ├── Phase 1: Foundation & Authentication
│   ├── Phase 2: Employee Management
│   ├── Phase 3: Attendance Tracking
│   ├── Phase 4: Payroll Engine
│   └── Phase 5: Compliance & Reports
├── Step by Step Tasks        (from Stories - flattened list)
├── Acceptance Criteria       (from all Story ACs)
└── Team Orchestration        (generated from tech stack)
```

---

## Section-by-Section Mapping

### 1. PRD → Overview, Task Description, Objective

**BMad PRD:**
```markdown
# Talenta HR UMKM Lite

## Product Overview
Ultra-lightweight HR management for Indonesian UMKM (50-200 employees).

## Target Users
- UMKM owners with 50-200 employees
- Need simple payroll + BPJS + PPh21
- Limited budget, need compliance

## Success Metrics
- User can calculate payroll in <5 minutes
- BPJS calculations accurate per 2024 rules
```

**Becomes Spec:**
```markdown
---
title: "Talenta HR UMKM Lite - Implementation Plan"
type: feat
status: ready
---

# Plan: Talenta HR UMKM Lite

## Overview

Ultra-lightweight HR management system for Indonesian UMKM (50-200 employees).

**Key Deliverables:**
- Multi-tenant company management
- Employee CRUD with CSV import/export
- Attendance tracking
- BPJS + PPh21 TER payroll engine
- Compliance reports

## Task Description

Build a complete HR management system including:
- User registration with company setup
- Employee management (CRUD + import/export)
- Daily attendance tracking
- Payroll calculation with BPJS and PPh21
- PDF payslip generation
- Compliance reports (BPJS SIPP, PPh21)

## Objective

Enable UMKM owners to:
1. Register company and manage employees
2. Track daily attendance
3. Generate accurate payroll (BPJS + PPh21)
4. Export compliance reports

**Success Metrics:**
- Payroll calculation <5 minutes for 200 employees
- BPJS calculations 100% accurate per 2024 rules
- PPh21 TER method compliant with tax regulations
```

---

### 2. Architecture → Relevant Files, Proposed Solution

**BMad Architecture:**
```markdown
# Tech Stack

Backend:  Go 1.21+ with Fiber framework
Database: SQLite with GORM ORM
Frontend: Go templates + HTMX + Tailwind CSS
PDF:      gofpdf or maroto
Excel:    excelize
Auth:     Custom JWT middleware

# Database Schema
CREATE TABLE companies (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    npwp TEXT,
    created_at DATETIME
);

CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    company_id INTEGER,
    email TEXT UNIQUE,
    password_hash TEXT,
    role TEXT,
    ...
);
```

**Becomes Spec:**
```markdown
## Proposed Solution

### Tech Stack

```
Backend:  Go 1.21+ with Fiber framework
Database: SQLite with GORM ORM
Frontend: Go templates + HTMX + Tailwind CSS
PDF:      gofpdf or maroto
Excel:    excelize
Auth:     Custom JWT middleware
Deploy:   Single binary, systemd service
```

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Nginx (Reverse Proxy)                │
│                    SSL (Let's Encrypt)                  │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              Talenta HR Binary (Go/Fiber)               │
│  ┌───────────────┬───────────────┬─────────────────┐   │
│  │   Middleware  │    Handlers   │    Services     │   │
│  │  - Auth/JWT   │  - Employee   │  - Payroll Calc │   │
│  │  - Tenant     │  - Attendance │  - BPJS Engine  │   │
│  │  - Logging    │  - Payroll    │  - Report Gen   │   │
│  └───────────────┴───────────────┴─────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Relevant Files

### New Files to Create

**Backend:**
- `cmd/server/main.go` - Application entry point
- `internal/models/company.go` - Company model
- `internal/models/user.go` - User model
- `internal/models/employee.go` - Employee model
- `internal/handlers/register.go` - Registration handler
- `internal/handlers/auth.go` - Authentication handler
- `internal/services/payroll.go` - Payroll calculation service
- `internal/services/bpjs.go` - BPJS calculation service
- `internal/middleware/auth.go` - JWT middleware
- `internal/middleware/tenant.go` - Multi-tenant middleware
- `templates/` - Go template files
- `migrations/` - Database migrations

**Frontend:**
- `templates/layouts/base.html` - Base layout
- `templates/auth/register.html` - Registration form
- `templates/auth/login.html` - Login form
- `templates/employees/list.html` - Employee list
- `templates/employees/create.html` - Create employee form
- `templates/payroll/preview.html` - Payroll preview
- `templates/reports/bpjs.html` - BPJS report

**Tests:**
- `tests/handlers/register_test.go`
- `tests/services/payroll_test.go`
- `tests/services/bpjs_test.go`
```

---

### 3. Epics → Implementation Phases

**BMad Epics Catalog:**
```markdown
| Epic | Title | Stories | Business Value | Sprint |
|------|-------|---------|----------------|--------|
| EPIC-001 | Foundation & Authentication | 3 | Platform entry point | 1 |
| EPIC-002 | Employee Management | 4 | Core data for all features | 1 |
| EPIC-003 | Attendance Tracking | 3 | Basis for payroll | 2 |
| EPIC-004 | Payroll Engine | 6 | ⭐ CORE VALUE | 2 |
| EPIC-005 | Compliance & Reports | 3 | Legal peace of mind | 2 |

## Dependency Graph
EPIC-001 (Foundation)
    ↓
EPIC-002 (Employees)
    ↓
EPIC-003 (Attendance)
    ↓
EPIC-004 (Payroll) ⭐ CORE VALUE
    ↓
EPIC-005 (Reports)
```

**Becomes Spec:**
```markdown
## Implementation Phases

### Phase 1: Foundation & Authentication

**Epic:** EPIC-001
**Business Value:** Platform entry point - can't manage employees without secure access
**Stories:** 3 stories (Company Registration, Authentication, Company Settings)

**Tasks:**

1.1. **Company Registration**
- **Story ID:** STORY-001-01
- **Points:** 3
- **Dependencies:** None
- **User Story:** As a new UMKM owner, I want to register my company information so that I can start managing my employees
- **Acceptance Criteria:**
  - [ ] AC-001-01-01: Registration form accepts all required fields
  - [ ] AC-001-01-02: System validates email format
  - [ ] AC-001-01-03: System validates password minimum length
  - [ ] AC-001-01-04: System validates passwords match
  - [ ] AC-001-01-05: System validates email uniqueness globally
  - [ ] AC-001-01-06: System creates company record
  - [ ] AC-001-01-07: System creates admin user record
  - [ ] AC-001-01-08: System hashes password using bcrypt
  - [ ] AC-001-01-09: System auto-login user after registration
  - [ ] AC-001-01-10: System redirects to dashboard
  - [ ] AC-001-01-11: System displays clear error messages
  - [ ] AC-001-01-12: NPWP field is optional
- **Implementation Requirements:**
  - POST /api/register endpoint
  - Request: {company: {...}, admin: {...}}
  - Response: {success, data: {company, user, token}}
  - bcrypt with cost factor 10+
- **Files:**
  - internal/handlers/register.go
  - internal/models/company.go
  - internal/models/user.go
  - templates/auth/register.html
- **Success Criteria:**
  - [ ] Unit tests for registration logic
  - [ ] Integration test for complete flow
  - [ ] Email uniqueness test
  - [ ] Password hashing verified
  - [ ] Auto-login tested

1.2. **User Authentication**
- **Story ID:** STORY-001-02
- **Dependencies:** STORY-001-01
- ... (similar format)

1.3. **Company Settings**
- **Story ID:** STORY-001-03
- **Dependencies:** STORY-001-01
- ...

**Success Criteria (Phase 1):**
- [ ] User can register company
- [ ] User can login securely
- [ ] Company settings persist
- [ ] Multi-tenant isolation verified

---

### Phase 2: Employee Management

**Epic:** EPIC-002
**Business Value:** Core data for all downstream features
**Stories:** 4 stories (Create Employee, List & Search, Import CSV, Export)

**Tasks:**

2.1. **Create Employee**
- **Story ID:** STORY-002-01
- **Dependencies:** STORY-001-02
- **User Story:** As an HR admin, I want to add employee details so that I can manage my workforce
- **Acceptance Criteria:**
  - [ ] AC-002-01-01: Form accepts all employee fields
  - [ ] AC-002-01-02: NIK uniqueness enforced per company
  - [ ] AC-002-01-03: Email uniqueness enforced per company
  - [ ] AC-002-01-04: Phone number validation
  - [ ] AC-002-01-05: Join date defaults to today
  - [ ] AC-002-01-06: Salary defaults to 0
  - ...

2.2. **List & Search Employees**
- **Story ID:** STORY-002-02
- **Dependencies:** STORY-002-01
- ...

2.3. **Import Employees CSV**
- **Story ID:** STORY-002-03
- **Dependencies:** STORY-002-01
- ...

2.4. **Export Employees**
- **Story ID:** STORY-002-04
- **Dependencies:** STORY-002-02
- ...

---

### Phase 3: Attendance Tracking
### Phase 4: Payroll Engine
### Phase 5: Compliance & Reports
... (same pattern for remaining phases)
```

---

### 4. Stories → Step by Step Tasks (Flattened)

**BMad Stories (distributed across epic folders):**
```
stories/epic-001/story-001-01-company-registration.md
stories/epic-001/story-001-02-authentication.md
stories/epic-002/story-002-01-create-employee.md
stories/epic-004/story-004-02-bpjs-engine.md
... (19 total stories)
```

**Becomes Spec (Sequential Task List):**
```markdown
## Step by Step Tasks

### 1. Company Registration
- **Task ID:** story-001-01
- **Depends On:** none
- **Assigned To:** backend-builder
- **Agent Type:** general-purpose
- **Parallel:** false
- **Implementation Requirements:**
  - POST /api/register endpoint
  - Request: {company: {name, address, npwp}, admin: {name, email, password, confirm_password}}
  - Response: {success, data: {company, user, token}}
  - Validate: email format, password min 8 chars, passwords match
  - Check email uniqueness globally (not just per company)
  - Create company record first
  - Hash password with bcrypt (cost 10+)
  - Create user with company_id
  - Issue JWT token
  - Auto-login after registration
- **Acceptance Criteria:**
  - [ ] AC-001-01-01: Registration form accepts all required fields
  - [ ] AC-001-01-02: System validates email format using standard email regex
  - [ ] AC-001-01-03: System validates password minimum length (8 characters)
  - [ ] AC-001-01-04: System validates passwords match
  - [ ] AC-001-01-05: System validates email uniqueness globally
  - [ ] AC-001-01-06: System creates company record
  - [ ] AC-001-01-07: System creates admin user with company_id
  - [ ] AC-001-01-08: System hashes password using bcrypt
  - [ ] AC-001-01-09: System issues JWT token after registration
  - [ ] AC-001-01-10: System redirects to dashboard
  - [ ] AC-001-01-11: System displays clear error messages
  - [ ] AC-001-01-12: NPWP field is optional

### 2. User Authentication
- **Task ID:** story-001-02
- **Depends On:** story-001-01
- **Assigned To:** backend-builder
- **Agent Type:** general-purpose
- **Parallel:** false
- **Implementation Requirements:**
  - POST /api/login endpoint
  - Request: {email, password}
  - Response: {success, data: {user, token}}
  - Verify credentials against database
  - Compare password hash
  - Issue JWT token on success
  - Return error on invalid credentials
- **Acceptance Criteria:**
  - [ ] AC-001-02-01: Login form accepts email and password
  - [ ] AC-001-02-02: System validates credentials
  - [ ] AC-001-02-03: System issues JWT token on success
  - [ ] AC-001-02-04: System returns error on invalid credentials
  - [ ] AC-001-02-05: JWT token expires in 24 hours
  - [ ] AC-001-02-06: System redirects to dashboard after login

### 3. Company Settings
- **Task ID:** story-001-03
- **Depends On:** story-001-01
- **Assigned To:** frontend-builder
- **Agent Type:** general-purpose
- **Parallel:** true
- **Implementation Requirements:**
  - GET /api/settings endpoint
  - PUT /api/settings endpoint
  - Update company name, address, NPWP
  - File upload for company logo
- **Acceptance Criteria:**
  - [ ] AC-001-03-01: Settings page displays current company info
  - [ ] AC-001-03-02: User can update company name
  - [ ] AC-001-03-03: User can update company address
  - [ ] AC-001-03-04: User can update NPWP
  - [ ] AC-001-03-05: User can upload company logo
  - [ ] AC-001-03-06: Changes persist to database

### 4. Create Employee
- **Task ID:** story-002-01
- **Depends On:** story-001-02
- **Assigned To:** backend-builder
- **Agent Type:** general-purpose
- **Parallel:** false
- **Implementation Requirements:**
  - POST /api/employees endpoint
  - All employee fields (NIK, name, email, phone, join_date, salary, etc.)
  - NIK uniqueness per company validation
  - Email uniqueness per company validation
  - Phone number format validation
- **Acceptance Criteria:**
  - [ ] AC-002-01-01: Form accepts all employee fields
  - [ ] AC-002-01-02: NIK uniqueness enforced per company
  - [ ] AC-002-01-03: Email uniqueness enforced per company
  - [ ] AC-002-01-04: Phone number validation
  - [ ] AC-002-01-05: Join date defaults to today
  - [ ] AC-002-01-06: Salary defaults to 0

... (continue for all 19 stories)

### 15. BPJS Calculation Engine
- **Task ID:** story-004-02
- **Depends On:** story-004-01
- **Assigned To:** backend-specialist
- **Agent Type:** general-purpose
- **Parallel:** false
- **Implementation Requirements:**
  - BPJS Ketenagakerjaan 2024 calculation formulas
  - JHT: 5.7% (2% employee, 3.7% employer)
  - JKM: 0.89% (0.89% employer)
  - JKK: 1.74% (1.74% employer)
  - JP: 2% (1% employee, 1% employer) with max salary Rp 12.660.000
  - JHT calculation: min(salary, Rp 12.660.000) * percentage
  - Handle part-time workers pro-rated calculation
- **Acceptance Criteria:**
  - [ ] AC-004-02-01: JHT calculated at 5.7% correctly
  - [ ] AC-004-02-02: JKM calculated at 0.89% correctly
  - [ ] AC-004-02-03: JKK calculated at 1.74% correctly
  - [ ] AC-004-02-04: JP calculated at 2% with salary cap
  - [ ] AC-004-02-05: Part-time workers pro-rated correctly
  - [ ] AC-004-02-06: Calculations match BPJS 2024 formulas
  - [ ] AC-004-02-07: Employee contribution shown separately
  - [ ] AC-004-02-08: Employer contribution shown separately
  - [ ] AC-004-02-09: Total BPJS shown in preview
```

---

### 5. Story ACs → Acceptance Criteria (Consolidated)

**BMad Story ACs (scattered across 19 stories):**
```
STORY-001-01: 12 acceptance criteria
STORY-001-02: 6 acceptance criteria
STORY-004-02: 9 acceptance criteria
...
Total: ~100+ acceptance criteria across all stories
```

**Becomes Spec (Consolidated by Category):**
```markdown
## Acceptance Criteria

### Functional Requirements

#### Registration & Authentication
- [ ] AC-001-01-01: Registration form accepts all required fields
- [ ] AC-001-01-02: System validates email format using standard email regex
- [ ] AC-001-01-03: System validates password minimum length (8 characters)
- [ ] AC-001-01-04: System validates passwords match
- [ ] AC-001-01-05: System validates email uniqueness globally
- [ ] AC-001-01-06: System creates company record
- [ ] AC-001-01-07: System creates admin user record
- [ ] AC-001-01-08: System hashes password using bcrypt
- [ ] AC-001-01-09: System auto-login user after registration
- [ ] AC-001-01-10: System redirects to dashboard
- [ ] AC-001-01-11: System displays clear error messages
- [ ] AC-001-01-12: NPWP field is optional
- [ ] AC-001-02-01: Login form accepts email and password
- [ ] AC-001-02-02: System validates credentials
- [ ] AC-001-02-03: System issues JWT token on success
- [ ] AC-001-02-04: System returns error on invalid credentials
- [ ] AC-001-02-05: JWT token expires in 24 hours
- [ ] AC-001-02-06: System redirects to dashboard after login

#### Employee Management
- [ ] AC-002-01-01: Form accepts all employee fields
- [ ] AC-002-01-02: NIK uniqueness enforced per company
- [ ] AC-002-01-03: Email uniqueness enforced per company
- [ ] AC-002-01-04: Phone number validation
- [ ] AC-002-01-05: Join date defaults to today
- [ ] AC-002-01-06: Salary defaults to 0
- [ ] AC-002-02-01: Employee list displays all employees
- [ ] AC-002-02-02: Search by name works
- [ ] AC-002-02-03: Filter by department works
- [ ] AC-002-02-04: Pagination for >50 employees
- [ ] AC-002-03-01: CSV upload accepts standard format
- [ ] AC-002-03-02: Validates required columns
- [ ] AC-002-03-03: Bulk inserts efficiently
- [ ] AC-002-03-04: Shows import summary
- [ ] AC-002-04-01: Export generates Excel file
- [ ] AC-002-04-02: Includes all employee fields
- [ ] AC-002-04-02: File downloads correctly

#### Payroll Calculation
- [ ] AC-004-02-01: JHT calculated at 5.7% correctly
- [ ] AC-004-02-02: JKM calculated at 0.89% correctly
- [ ] AC-004-02-03: JKK calculated at 1.74% correctly
- [ ] AC-004-02-04: JP calculated at 2% with salary cap
- [ ] AC-004-02-05: Part-time workers pro-rated correctly
- [ ] AC-004-02-06: Calculations match BPJS 2024 formulas
- [ ] AC-004-03-01: PPh21 TER method calculated correctly
- [ ] AC-004-03-02: Tax tiers (5%, 15%, 25%, 30%, 35%) applied
- [ ] AC-004-03-03: PTKP deduction applied
- [ ] AC-004-03-04: Biaya Jabatan applied (max 500k)
- [ ] AC-004-04-01: Preview shows all calculations
- [ ] AC-004-04-02: Preview shows per-employee breakdown
- [ ] AC-004-04-03: Preview shows company totals
- [ ] AC-004-05-01: Finalize creates locked payroll period
- [ ] AC-004-05-02: Finalized payroll cannot be modified
- [ ] AC-004-06-01: PDF payslip generated per employee
- [ ] AC-004-06-02: Payslip includes all earnings and deductions

### Non-Functional Requirements

#### Performance
- [ ] NF1: Page load <500ms TTFB
- [ ] NF2: Memory usage <100MB per 50 companies
- [ ] NF3: Database size <500MB for 1000 employees
- [ ] NF4: Payroll calculation <5 minutes for 200 employees
- [ ] NF5: Binary size <20MB

#### Security
- [ ] SEC1: All passwords hashed with bcrypt
- [ ] SEC2: JWT tokens expire in 24 hours
- [ ] SEC3: Multi-tenant data isolation enforced
- [ ] SEC4: SQL injection prevented with parameterized queries
- [ ] SEC5: XSS prevented with proper escaping

#### Quality
- [ ] Q1: Unit test coverage >80%
- [ ] Q2: Integration tests for all critical paths
- [ ] Q3: Code reviewed before merge
- [ ] Q4: Documentation updated

### Quality Gates

#### Epic Completion
- [ ] All stories implemented
- [ ] All acceptance criteria met
- [ ] Unit tests passing (>80% coverage)
- [ ] Integration tests passing
- [ ] Documentation updated
- [ ] Code reviewed

#### Project Completion
- [ ] All 5 epics complete
- [ ] All 19 stories complete
- [ ] End-to-end testing complete
- [ ] Performance targets met
- [ ] Deployment successful
```

---

## Dependencies Preserved

**BMad Epic Dependencies:**
```
EPIC-001 (Foundation)
    ↓
EPIC-002 (Employees) - depends on Foundation (users, companies)
    ↓
EPIC-003 (Attendance) - depends on Employees
    ↓
EPIC-004 (Payroll) - depends on Attendance data
    ↓
EPIC-005 (Reports) - depends on Payroll data
```

**Becomes Spec Task Dependencies:**
```markdown
## Step by Step Tasks

### 1. Company Registration
- **Depends On:** none

### 2. User Authentication
- **Depends On:** story-001-01

### 3. Company Settings
- **Depends On:** story-001-01

### 4. Create Employee
- **Depends On:** story-001-02 (requires authenticated user)

### 5. List & Search Employees
- **Depends On:** story-002-01

### 6. Import Employees CSV
- **Depends On:** story-002-01

### 7. Export Employees
- **Depends On:** story-002-02

### 8. Daily Attendance Input
- **Depends On:** story-002-01 (requires employees)

### 9. Monthly Attendance View
- **Depends On:** story-003-01

### 10. Salary Component Setup
- **Depends On:** story-002-01 (requires employee salary data)

### 11. BPJS Calculation Engine
- **Depends On:** story-004-01

### 12. PPh21 TER Calculation
- **Depends On:** story-004-01 (salary components)

### 13. Generate Payroll Preview
- **Depends On:** story-004-02, story-004-03 (BPJS + PPh21)

### 14. Finalize Payroll
- **Depends On:** story-004-04, story-003-01 (attendance + preview)

### 15. Generate Payslip PDF
- **Depends On:** story-004-05

### 16. BPJS SIPP Report
- **Depends On:** story-004-05 (payroll finalized)

### 17. PPh21 Report
- **Depends On:** story-004-05

### 18. Payroll Summary
- **Depends On:** story-004-05

### 19. Attendance Export
- **Depends On:** story-003-02
```

---

## Team Orchestration Generated from Tech Stack

**BMad Architecture Tech Stack:**
```
Backend:  Go 1.21+ with Fiber framework
Frontend: Go templates + HTMX + Tailwind CSS
Database: SQLite with GORM
```

**Becomes Spec Team Orchestration:**
```markdown
## Team Orchestration

You operate as the team lead and orchestrate the team to execute the plan.

### Team Members

#### Go Backend Builder
- **Name:** go-backend-builder
- **Role:** Backend Implementation
- **Agent Type:** general-purpose
- **Resume:** true
- **Assigned To:** All Go handler, service, and middleware tasks

#### Frontend Builder
- **Name:** frontend-builder
- **Role:** Frontend Implementation
- **Agent Type:** general-purpose
- **Resume:** true
- **Assigned To:** All HTML template, HTMX, and Tailwind tasks

#### Test Engineer
- **Name:** test-engineer
- **Role:** Testing
- **Agent Type:** general-purpose
- **Resume:** true
- **Assigned To:** All unit and integration test tasks

#### Documentation Writer
- **Name:** doc-writer
- **Role:** Documentation
- **Agent Type:** general-purpose
- **Resume:** true
- **Assigned To:** All documentation tasks
```

---

## Example: Single Story Conversion

**BMad Story (story-001-01-company-registration.md):**
```markdown
---
story_id: STORY-001-01
epic: EPIC-001
title: Company Registration
status: Pending
points: 3
dependencies: None
---

# STORY-001-01: Company Registration

## Description
Enable new users to register their company and create an admin account in a single flow.

## User Story
**As:** A new UMKM owner
**I want:** Register my company information
**So that:** I can start managing my employees

## Acceptance Criteria
- [ ] AC-001-01-01: Registration form accepts all required fields
- [ ] AC-001-01-02: System validates email format
- [ ] AC-001-01-03: System validates password minimum length
- [ ] AC-001-01-04: System validates passwords match
- [ ] AC-001-01-05: System validates email uniqueness globally
- [ ] AC-001-01-06: System creates company record
- [ ] AC-001-01-07: System creates admin user record
- [ ] AC-001-01-08: System hashes password using bcrypt
- [ ] AC-001-01-09: System auto-login user after registration
- [ ] AC-001-01-10: System redirects to dashboard
- [ ] AC-001-01-11: System displays clear error messages
- [ ] AC-001-01-12: NPWP field is optional

## Technical Notes

### API Endpoint
POST /api/register

### Request Body
{
  "company": {
    "name": "PT UMKM Maju Jaya",
    "address": "Jl. Sudirman No. 123, Jakarta",
    "npwp": "01.234.567.8-901.000"
  },
  "admin": {
    "name": "Budi Santoso",
    "email": "budi@umkm-maju.com",
    "password": "SecurePass123",
    "confirm_password": "SecurePass123"
  }
}

### Response (Success)
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "company": {"id": 1, "name": "PT UMKM Maju Jaya"},
    "user": {"id": 1, "name": "Budi Santoso", "email": "budi@umkm-maju.com"},
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}

### Implementation Requirements
func HandleRegister(c *fiber.Ctx) error {
    // 1. Parse request body
    // 2. Validate all fields
    // 3. Check email uniqueness globally
    // 4. Start database transaction
    // 5. Create company record
    // 6. Hash password with bcrypt
    // 7. Create user record with company_id
    // 8. Commit transaction
    // 9. Generate JWT token
    // 10. Return success response
}

### Database Operations
var existingUser models.User
result := db.Where("email = ?", email).First(&existingUser)
if result.Error == nil {
    return errors.New("email already registered")
}

company := models.Company{
    Name: input.Company.Name,
    Address: input.Company.Address,
    NPWP: input.Company.NPWP,
}
db.Create(&company)

hash, _ := bcrypt.GenerateFromPassword([]byte(password), 10)

user := models.User{
    CompanyID: company.ID,
    Email: input.Admin.Email,
    PasswordHash: string(hash),
    Name: input.Admin.Name,
    Role: "admin",
}
db.Create(&user)

### Frontend (HTMX)
<form hx-post="/api/register" hx-swap="none">
    <input type="text" name="company[name]" placeholder="Company Name" required>
    <textarea name="company[address]" placeholder="Address"></textarea>
    <input type="text" name="company[npwp]" placeholder="NPWP">
    <input type="text" name="admin[name]" placeholder="Your Name" required>
    <input type="email" name="admin[email]" placeholder="Email" required>
    <input type="password" name="admin[password]" placeholder="Password" required>
    <input type="password" name="admin[confirm_password]" placeholder="Confirm Password" required>
    <button type="submit">Register</button>
</form>

## Definition of Done
- [ ] All acceptance criteria met
- [ ] Unit tests for registration logic
- [ ] Integration test for complete flow
- [ ] Email uniqueness test
- [ ] Password hashing verified
- [ ] Auto-login tested
- [ ] Error cases tested
- [ ] Code reviewed
```

**Becomes Spec Task:**
```markdown
### 1. Company Registration
- **Task ID:** story-001-01
- **Depends On:** none
- **Assigned To:** go-backend-builder
- **Agent Type:** general-purpose
- **Parallel:** false

**User Story:** As a new UMKM owner, I want to register my company information so that I can start managing my employees

**Implementation Requirements:**

Create POST /api/register endpoint with:

Request format:
```json
{
  "company": {
    "name": "PT UMKM Maju Jaya",
    "address": "Jl. Sudirman No. 123, Jakarta",
    "npwp": "01.234.567.8-901.000"
  },
  "admin": {
    "name": "Budi Santoso",
    "email": "budi@umkm-maju.com",
    "password": "SecurePass123",
    "confirm_password": "SecurePass123"
  }
}
```

Response format (success):
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "company": {"id": 1, "name": "PT UMKM Maju Jaya"},
    "user": {"id": 1, "name": "Budi Santoso", "email": "budi@umkm-maju.com"},
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

Handler implementation steps:
1. Parse request body
2. Validate all fields (email format, password length, passwords match)
3. Check email uniqueness globally (not just per company)
4. Start database transaction
5. Create company record
6. Hash password with bcrypt (cost factor 10+)
7. Create user record with company_id
8. Commit transaction
9. Generate JWT token
10. Return success response

Database operations:
```go
// Check email uniqueness
var existingUser models.User
result := db.Where("email = ?", email).First(&existingUser)
if result.Error == nil {
    return errors.New("email already registered")
}

// Create company
company := models.Company{
    Name: input.Company.Name,
    Address: input.Company.Address,
    NPWP: input.Company.NPWP,
}
db.Create(&company)

// Hash password
hash, _ := bcrypt.GenerateFromPassword([]byte(password), 10)

// Create user
user := models.User{
    CompanyID: company.ID,
    Email: input.Admin.Email,
    PasswordHash: string(hash),
    Name: input.Admin.Name,
    Role: "admin",
}
db.Create(&user)
```

Frontend form (HTMX):
```html
<form hx-post="/api/register" hx-swap="none">
    <input type="text" name="company[name]" placeholder="Company Name" required>
    <textarea name="company[address]" placeholder="Address"></textarea>
    <input type="text" name="company[npwp]" placeholder="NPWP (XX.XXX.XXX.X-XXX.XXX)">
    <input type="text" name="admin[name]" placeholder="Your Name" required>
    <input type="email" name="admin[email]" placeholder="Email" required>
    <input type="password" name="admin[password]" placeholder="Password (min 8 chars)" required>
    <input type="password" name="admin[confirm_password]" placeholder="Confirm Password" required>
    <button type="submit">Register</button>
</form>
```

**Files to Create:**
- `internal/handlers/register.go` - Registration handler
- `internal/models/company.go` - Company model
- `internal/models/user.go` - User model
- `templates/auth/register.html` - Registration form

**Acceptance Criteria:**
- [ ] AC-001-01-01: Registration form accepts all required fields (company name, address, NPWP, admin name, email, password, confirm password)
- [ ] AC-001-01-02: System validates email format using standard email regex
- [ ] AC-001-01-03: System validates password minimum length (8 characters)
- [ ] AC-001-01-04: System validates passwords match (password = confirm password)
- [ ] AC-001-01-05: System validates email uniqueness across ALL companies (global uniqueness)
- [ ] AC-001-01-06: System creates company record with provided information
- [ ] AC-001-01-07: System creates admin user record associated with new company
- [ ] AC-001-01-08: System hashes password using bcrypt (cost factor 10+)
- [ ] AC-001-01-09: System auto-login user after successful registration (JWT token issued)
- [ ] AC-001-01-10: System redirects user to dashboard after registration
- [ ] AC-001-01-11: System displays clear error messages for validation failures
- [ ] AC-001-01-12: NPWP field is optional (can be empty)

**Success Criteria:**
- [ ] Unit tests for registration logic
- [ ] Integration test for complete flow
- [ ] Email uniqueness test
- [ ] Password hashing verified
- [ ] Auto-login tested
- [ ] Error cases tested (duplicate email, invalid format)
- [ ] Code reviewed
```

---

## Summary

The conversion process transforms BMad's separate planning documents into a single executable spec by:

1. **Merging content** from PRD, Architecture, Epics, and Stories into unified sections
2. **Flattening hierarchy** - Epic → Phase, Story → Task
3. **Preserving all details** - Every AC, code snippet, API spec, and database schema
4. **Maintaining dependencies** - Epic dependency graph becomes task dependency chain
5. **Generating orchestration** - Tech stack determines team composition

The resulting spec is executable by `/build` with multi-agent coordination while preserving 100% of the technical details from BMad output.
