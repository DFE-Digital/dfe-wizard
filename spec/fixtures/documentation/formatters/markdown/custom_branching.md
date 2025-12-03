# Wizard Documentation

**Structure Type:** `graph`
**Generated:** 2025-12-02T15:45:00Z
**Processor:** DfE::Wizard::StepsProcessor

## Overview

| Metric | Value |
|--------|-------|
| Total Steps | 5 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 1 |
| **Total Transitions** | **1** |

## Root Entry Point (Fixed)

**Entry Point:** `application_status`

All users start at this step. No conditional logic applies.

## Wizard Flow

```
[:application_status]
  ↓
[:pending]
[:approved]
[:rejected]
[:revision]
```

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `application_status` | Application Status | `Steps::ApplicationStatus` |
| `pending` | Pending Review | `Steps::Pending` |
| `approved` | Approved | `Steps::Approved` |
| `rejected` | Rejected | `Steps::Rejected` |
| `revision` | Request Revision | `Steps::Revision` |

## Detailed Step Specifications

### Step: `application_status`

**Label:** Application Status
**Class:** `Steps::ApplicationStatus`
**Entry Point:** ✓ Yes
**Exit Points:** `pending`, `approved`, `rejected`, `revision`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `pending`

**Label:** Pending Review
**Class:** `Steps::Pending`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `approved`

**Label:** Approved
**Class:** `Steps::Approved`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `rejected`

**Label:** Rejected
**Class:** `Steps::Rejected`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `revision`

**Label:** Request Revision
**Class:** `Steps::Revision`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

## Transitions Reference

This wizard contains **1 transitions** across 4 types:

- **0 simple transitions** – Linear progression (unconditional)
- **0 conditional transitions** – If/else branching logic
- **0 multiple conditional transitions** – N-way branching
- **1 custom branching transitions** – Complex status-driven routing

### Custom Branching Transitions (Status-Driven)

Custom branching uses a method to evaluate complex logic and route to multiple possible destinations.

#### `application_status` → Multiple Destinations (Custom Logic)

| Property | Value |
|----------|-------|
| From | `application_status` |
| Type | Custom Branching |

**Potential Transitions:**

| Condition | Destination(s) |
|-----------|-----------------|
| Under Review | `pending` |
| Approved | `approved` |
| Rejected | `rejected` |
| Needs Revision | `revision` |

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 5 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 0 |
| Custom Branching Transitions | 1 |
| **Total Transitions** | **1** |

## Raw Metadata

```json
{
  "structure_type": "graph",
  "root_step": "application_status",
  "counts": {"steps": 5}
}
```
