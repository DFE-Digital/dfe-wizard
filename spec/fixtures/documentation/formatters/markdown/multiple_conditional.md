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
| Multiple Conditional Transitions | 1 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **1** |

## Root Entry Point (Fixed)

**Entry Point:** `user_type`

All users start at this step. No conditional logic applies.

## Wizard Flow

```
[:user_type]
  ↓
[:admin_panel]
[:moderator_panel]
[:user_dashboard]
[:guest_view]
```

## Steps Inventory

| Step ID | Label | Class |
|---------|-------|-------|
| `user_type` | User Type | `Steps::UserType` |
| `admin_panel` | Admin Panel | `Steps::AdminPanel` |
| `moderator_panel` | Moderator Panel | `Steps::ModeratorPanel` |
| `user_dashboard` | User Dashboard | `Steps::UserDashboard` |
| `guest_view` | Guest View | `Steps::GuestView` |

## Detailed Step Specifications

### Step: `user_type`

**Label:** User Type
**Class:** `Steps::UserType`
**Entry Point:** ✓ Yes
**Exit Points:** `admin_panel`, `moderator_panel`, `user_dashboard`, `guest_view`

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `admin_panel`

**Label:** Admin Panel
**Class:** `Steps::AdminPanel`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `moderator_panel`

**Label:** Moderator Panel
**Class:** `Steps::ModeratorPanel`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `user_dashboard`

**Label:** User Dashboard
**Class:** `Steps::UserDashboard`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

### Step: `guest_view`

**Label:** Guest View
**Class:** `Steps::GuestView`
**Entry Point:** ✗ No
**Exit Points:** [Wizard End]

#### Description

Placeholder for step description. Add contextual information about
this step's purpose, user interactions, and business logic.

## Transitions Reference

This wizard contains **1 transitions** across 4 types:

- **0 simple transitions** – Linear progression (unconditional)
- **0 conditional transitions** – If/else branching logic
- **1 multiple conditional transitions** – N-way branching
- **0 custom branching transitions** – Complex status-driven routing

### Multiple Conditional Transitions (N-way Branching)

N-way transitions route to different steps based on multiple independent conditions.

#### `user_type` → Multiple Destinations (3 branches)

| Property | Value |
|----------|-------|
| From | `user_type` |
| Label | User Role Classification |
| Type | Multiple Conditional (N-way) |
| Default | `guest_view` |

**Branches:**

| Branch | Destination |
|--------|-------------|
| Admin User | `admin_panel` |
| Moderator User | `moderator_panel` |
| Regular User | `user_dashboard` |
| (default, no match) | `guest_view` |

## Wizard Statistics

| Metric | Count |
|--------|-------|
| Total Steps | 5 |
| Simple Transitions | 0 |
| Conditional Transitions | 0 |
| Multiple Conditional Transitions | 1 |
| Custom Branching Transitions | 0 |
| **Total Transitions** | **1** |

## Raw Metadata

```json
{
  "structure_type": "graph",
  "root_step": "user_type",
  "counts": {"steps": 5}
}
```
